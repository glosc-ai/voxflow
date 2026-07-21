import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../widgets/inline_error_banner.dart';
import '../models/stt_state.dart';
import '../providers/stt_provider.dart';

class SttScreen extends ConsumerStatefulWidget {
  const SttScreen({super.key});

  @override
  ConsumerState<SttScreen> createState() => _SttScreenState();
}

class _SttScreenState extends ConsumerState<SttScreen> {
  late final TextEditingController _resultController;

  @override
  void initState() {
    super.initState();
    _resultController = TextEditingController();
  }

  @override
  void dispose() {
    _resultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sttProvider);
    ref.listen<String?>(
      sttProvider.select((value) => value.errorMessage),
      (previous, next) {
        if (next != null && next != previous) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next)),
          );
        }
      },
    );
    ref.listen<String>(
      sttProvider.select((value) => value.result?.text ?? ''),
      (previous, next) {
        if (next.isNotEmpty && next != previous) {
          _resultController.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音转文字'),
        actions: [
          if (state.phase == SttPhase.success ||
              state.phase == SttPhase.failure)
            IconButton(
              tooltip: '清空当前任务',
              onPressed: ref.read(sttProvider.notifier).reset,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.errorMessage != null) ...[
                  InlineErrorBanner(message: state.errorMessage!),
                  const SizedBox(height: 16),
                ],
                _RecordingCard(state: state),
                const SizedBox(height: 16),
                _ImportCard(state: state),
                if (state.isProcessing) ...[
                  const SizedBox(height: 16),
                  _ProgressCard(state: state),
                ],
                if (state.result != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                '转录结果',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              Text('${state.result!.segments.length} 个片段'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('transcriptionEditor'),
                            controller: _resultController,
                            minLines: 8,
                            maxLines: 18,
                            onChanged:
                                ref.read(sttProvider.notifier).updateEditedText,
                            decoration: const InputDecoration(
                              labelText: '可编辑全文',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: state.canExport
                                    ? () => _export(isSrt: false)
                                    : null,
                                icon: const Icon(Icons.description_outlined),
                                label: const Text('导出 TXT'),
                              ),
                              Tooltip(
                                message: state.canExportSrt
                                    ? '导出带时间戳字幕'
                                    : '当前服务未返回时间戳片段',
                                child: FilledButton.tonalIcon(
                                  onPressed: state.canExportSrt
                                      ? () => _export(isSrt: true)
                                      : null,
                                  icon: const Icon(Icons.subtitles),
                                  label: const Text('导出 SRT'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _export({required bool isSrt}) async {
    try {
      final notifier = ref.read(sttProvider.notifier);
      final saved =
          isSrt ? await notifier.exportSrt() : await notifier.exportText();
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isSrt ? 'SRT 已导出。' : 'TXT 已导出。')),
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }
}

class _RecordingCard extends ConsumerWidget {
  const _RecordingCard({required this.state});

  final SttState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sttProvider.notifier);
    final isCountdown = state.phase == SttPhase.countdown;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: isCountdown
                  ? Text(
                      '${state.countdown}',
                      style: Theme.of(context).textTheme.headlineLarge,
                    )
                  : Icon(
                      state.phase == SttPhase.paused ? Icons.pause : Icons.mic,
                      size: 44,
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              _recordingStatus(state),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              _duration(state.elapsed),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (state.canStart)
                  FilledButton.icon(
                    key: const Key('startRecordingButton'),
                    onPressed: notifier.startRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text('开始录音'),
                  ),
                if (state.phase == SttPhase.recording)
                  OutlinedButton.icon(
                    onPressed: notifier.pauseRecording,
                    icon: const Icon(Icons.pause),
                    label: const Text('暂停'),
                  ),
                if (state.phase == SttPhase.paused)
                  OutlinedButton.icon(
                    onPressed: notifier.resumeRecording,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('继续'),
                  ),
                if (state.isRecording)
                  FilledButton.icon(
                    onPressed: notifier.stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止并转录'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportCard extends ConsumerWidget {
  const _ImportCard({required this.state});

  final SttState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = state.selectedFilePath;
    final fileName = path == null ? null : File(path).uri.pathSegments.last;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.audio_file, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '导入本地音频或视频',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName ?? '支持 MP3、MP4、MPEG、MPGA、M4A、WAV、WEBM，最大 25 MB',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: state.canStart
                  ? ref.read(sttProvider.notifier).pickAndTranscribe
                  : null,
              icon: const Icon(Icons.folder_open),
              label: const Text('选择文件'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state});

  final SttState state;

  @override
  Widget build(BuildContext context) {
    final uploading = state.phase == SttPhase.uploading;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(uploading ? '正在上传音频…' : 'AI 正在转录…'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: uploading && state.uploadProgress > 0
                  ? state.uploadProgress
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

String _recordingStatus(SttState state) {
  return switch (state.phase) {
    SttPhase.countdown => '准备录音',
    SttPhase.recording => '正在录音',
    SttPhase.paused => '录音已暂停',
    _ => '录制新音频',
  };
}

String _duration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
