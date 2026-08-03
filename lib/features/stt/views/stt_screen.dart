import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_section.dart';
import '../../../widgets/app_status_banner.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/stt_state.dart';
import '../providers/stt_provider.dart';
import '../services/seed_asr_api_service.dart';
import '../widgets/desktop_stt_workspace.dart';

class SttScreen extends ConsumerStatefulWidget {
  const SttScreen({super.key, this.pageFocusNode});

  final FocusNode? pageFocusNode;

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
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final errorMessage = state.errorMessageFor(locale);
    ref.listen<String?>(
      sttProvider.select((value) => value.errorMessageFor(locale)),
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

    final compactAppBar = MediaQuery.sizeOf(context).width < 560 ||
        MediaQuery.textScalerOf(context).scale(1) >= 1.3;

    return LayoutBuilder(
      builder: (context, pageConstraints) {
        final useDesktop =
            Theme.of(context).platform == TargetPlatform.windows &&
                pageConstraints.maxWidth >= 760;
        return Scaffold(
          backgroundColor: useDesktop ? Colors.transparent : null,
          appBar: useDesktop
              ? null
              : AppBar(
                  toolbarHeight: AppTheme.responsiveAppBarHeight(
                    context,
                    largeTextMaxLines: 2,
                  ),
                  title: Text(
                    l10n.text(zh: '语音转文字', en: 'Speech to text'),
                    maxLines: 2,
                  ),
                  actions: [
                    if (state.phase == SttPhase.success ||
                        state.phase == SttPhase.failure)
                      if (compactAppBar)
                        IconButton(
                          tooltip: l10n.text(zh: '新建转录', en: 'New transcript'),
                          onPressed: _startNewTranscript,
                          icon: const Icon(Icons.add_circle_outline),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: Tooltip(
                            message:
                                l10n.text(zh: '新建转录', en: 'New transcript'),
                            child: TextButton.icon(
                              onPressed: _startNewTranscript,
                              icon: const Icon(Icons.add_circle_outline),
                              label: Text(
                                l10n.text(zh: '新建转录', en: 'New transcript'),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
          body: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyO, control: true):
                  () {
                if (state.canStart && state.result == null) {
                  unawaited(
                    ref.read(sttProvider.notifier).pickAndTranscribe(
                          dialogTitle: l10n.text(
                            zh: '选择音频或视频文件',
                            en: 'Choose an audio or video file',
                          ),
                        ),
                  );
                }
              },
              if (useDesktop)
                _SafeSpaceActivator(_desktopSpaceIsSafe): () {
                  if (state.canStart) {
                    unawaited(ref.read(sttProvider.notifier).startRecording());
                  } else if (state.isRecording) {
                    unawaited(ref.read(sttProvider.notifier).stopRecording());
                  } else if (state.phase == SttPhase.countdown) {
                    unawaited(ref.read(sttProvider.notifier).cancelRecording());
                  }
                },
            },
            child: Focus(
              key: const Key('sttPageFocus'),
              focusNode: widget.pageFocusNode,
              autofocus: widget.pageFocusNode == null,
              skipTraversal: true,
              child: useDesktop
                  ? DesktopSttWorkspace(
                      state: state,
                      controller: _resultController,
                      onExport: _export,
                      onNewTranscript: _startNewTranscript,
                    )
                  : SingleChildScrollView(
                      padding: AppLayout.pagePadding(context),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (errorMessage != null) ...[
                                AppStatusBanner(
                                  kind: AppStatusKind.error,
                                  title: l10n.text(
                                    zh: '转录未完成',
                                    en: 'Transcription not completed',
                                  ),
                                  message: errorMessage,
                                  action: state.canRetrySelectedSource
                                      ? TextButton.icon(
                                          key: const Key(
                                            'retrySelectedSttSourceButton',
                                          ),
                                          onPressed: ref
                                              .read(sttProvider.notifier)
                                              .retrySelectedSource,
                                          icon: const Icon(Icons.refresh),
                                          label: Text(
                                            state.selectedSourceIsTemporaryRecording
                                                ? l10n.text(
                                                    zh: '重试此录音',
                                                    en: 'Retry this recording',
                                                  )
                                                : l10n.text(
                                                    zh: '重试此文件',
                                                    en: 'Retry this file',
                                                  ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              if (state.result == null)
                                _InputWorkspace(state: state)
                              else
                                _ResultSection(
                                  state: state,
                                  controller: _resultController,
                                  onExport: _export,
                                ),
                              const SizedBox(height: AppSpacing.xl),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  bool _desktopSpaceIsSafe() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null ||
        FocusManager.instance.primaryFocus == widget.pageFocusNode) {
      return true;
    }
    var interactive = focusContext.widget is EditableText ||
        focusContext.widget is ButtonStyleButton ||
        focusContext.widget is IconButton ||
        focusContext.widget is InkWell ||
        focusContext.widget is PopupMenuButton;
    focusContext.visitAncestorElements((element) {
      final ancestor = element.widget;
      interactive = interactive ||
          ancestor is EditableText ||
          ancestor is ButtonStyleButton ||
          ancestor is IconButton ||
          ancestor is InkWell ||
          ancestor is PopupMenuButton;
      return !interactive;
    });
    return !interactive;
  }

  Future<void> _export({required bool isSrt}) async {
    try {
      final notifier = ref.read(sttProvider.notifier);
      final dialogTitle = context.l10n.text(
        zh: '导出转录结果',
        en: 'Export transcript',
      );
      final saved = isSrt
          ? await notifier.exportSrt(dialogTitle: dialogTitle)
          : await notifier.exportText(dialogTitle: dialogTitle);
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSrt
                  ? context.l10n.text(
                      zh: 'SRT 已导出。',
                      en: 'SRT exported.',
                    )
                  : context.l10n.text(
                      zh: 'TXT 已导出。',
                      en: 'TXT exported.',
                    ),
            ),
          ),
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.appError(error))),
        );
      }
    }
  }

  Future<void> _startNewTranscript() async {
    final state = ref.read(sttProvider);
    final result = state.result;
    final hasUnsavedEdits = result != null && state.editedText != result.text;
    final discardsTemporaryRecording = state.hasRetainedTemporaryRecording;
    if (hasUnsavedEdits || discardsTemporaryRecording) {
      final l10n = context.l10n;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            discardsTemporaryRecording
                ? l10n.text(
                    zh: '放弃尚未转录的录音？',
                    en: 'Discard the untranscribed recording?',
                  )
                : l10n.text(
                    zh: '放弃未导出的修改？',
                    en: 'Discard unexported changes?',
                  ),
          ),
          content: Text(
            discardsTemporaryRecording
                ? l10n.text(
                    zh: '新建转录会永久删除这段临时录音，且无法撤销。你也可以取消并重试此录音。',
                    en: 'Starting a new transcript permanently deletes this temporary recording and cannot be undone. You can cancel and retry it instead.',
                  )
                : l10n.text(
                    zh: '新建转录会清除当前编辑内容。原始转录仍保留在历史记录中。',
                    en: 'Starting a new transcript clears the current edits. The original transcript remains in history.',
                  ),
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.text(zh: '取消', en: 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                discardsTemporaryRecording
                    ? l10n.text(
                        zh: '放弃并新建',
                        en: 'Discard and start new',
                      )
                    : l10n.text(
                        zh: '新建转录',
                        en: 'New transcript',
                      ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    await ref.read(sttProvider.notifier).reset();
    if (!mounted) {
      return;
    }
    _resultController.clear();
  }
}

class _SafeSpaceActivator extends ShortcutActivator {
  const _SafeSpaceActivator(this.isSafe);

  static const _space = SingleActivator(LogicalKeyboardKey.space);
  final bool Function() isSafe;

  @override
  Iterable<LogicalKeyboardKey>? get triggers => _space.triggers;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    return _space.accepts(event, state) && isSafe();
  }

  @override
  String debugDescribeKeys() => _space.debugDescribeKeys();
}

class _InputWorkspace extends StatelessWidget {
  const _InputWorkspace({required this.state});

  final SttState state;

  @override
  Widget build(BuildContext context) {
    return AppSection(
      title: context.l10n.text(zh: '录制或导入', en: 'Record or import'),
      description: context.l10n.text(
        zh: '录制新音频，或从设备中选择现有音频和视频进行转录。',
        en: 'Record new audio, or choose existing audio or video from this device.',
      ),
      leading: const Icon(Icons.graphic_eq),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final useColumns = constraints.maxWidth >= 720 && textScale < 1.6;
          final sourcePanels = useColumns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SubtlePanel(
                        child: _RecordingPanel(state: state),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _SubtlePanel(
                        child: _ImportPanel(state: state),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SubtlePanel(
                      child: _RecordingPanel(state: state),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SubtlePanel(
                      child: _ImportPanel(state: state),
                    ),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sourcePanels,
              if (state.isProcessing) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Divider(),
                ),
                _ProcessingStatus(state: state),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SubtlePanel extends StatelessWidget {
  const _SubtlePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.semanticColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

class _RecordingPanel extends ConsumerWidget {
  const _RecordingPanel({required this.state});

  final SttState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sttProvider.notifier);
    final status = _recordingStatus(context, state);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: context.l10n.text(zh: '录音控制', en: 'Recording controls'),
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RecordingStateIcon(state: state),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: true,
                      label: status,
                      child: ExcludeSemantics(
                        child: Text(status, style: textTheme.titleSmall),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Semantics(
                      label: context.l10n.text(
                        zh: '录音时长 ${_spokenDuration(context, state.elapsed)}',
                        en: 'Recording duration ${_spokenDuration(context, state.elapsed)}',
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          _duration(state.elapsed),
                          style: textTheme.headlineSmall?.copyWith(
                            color: state.phase == SttPhase.recording
                                ? context.semanticColors.recording
                                : colors.onSurface,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.canStart || state.isRecording) ...[
            const SizedBox(height: AppSpacing.lg),
            _AdaptiveActions(
              alignment: WrapAlignment.start,
              children: [
                if (state.canStart)
                  FilledButton.icon(
                    key: const Key('startRecordingButton'),
                    onPressed: notifier.startRecording,
                    icon: const Icon(Icons.mic),
                    label: Text(
                      context.l10n.text(
                        zh: '开始录音',
                        en: 'Start recording',
                      ),
                    ),
                  ),
                if (state.phase == SttPhase.recording)
                  OutlinedButton.icon(
                    onPressed: notifier.pauseRecording,
                    icon: const Icon(Icons.pause),
                    label: Text(context.l10n.text(zh: '暂停', en: 'Pause')),
                  ),
                if (state.phase == SttPhase.paused)
                  OutlinedButton.icon(
                    onPressed: notifier.resumeRecording,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(context.l10n.text(zh: '继续', en: 'Resume')),
                  ),
                if (state.isRecording)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.semanticColors.recording,
                      foregroundColor: colors.onError,
                    ),
                    onPressed: notifier.stopRecording,
                    icon: const Icon(Icons.stop),
                    label: Text(context.l10n.text(
                      zh: '停止并转录',
                      en: 'Stop and transcribe',
                    )),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordingStateIcon extends StatelessWidget {
  const _RecordingStateIcon({required this.state});

  final SttState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantics = context.semanticColors;
    final isRecording = state.phase == SttPhase.recording;
    final foreground = isRecording ? semantics.recording : colors.primary;
    final background =
        isRecording ? semantics.recordingContainer : colors.primaryContainer;

    final Widget content = switch (state.phase) {
      SttPhase.countdown => Text(
          '${state.countdown}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.onPrimaryContainer,
              ),
        ),
      SttPhase.paused => Icon(Icons.pause, color: foreground, size: 24),
      SttPhase.recording => Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.mic, color: foreground, size: 24),
            Positioned(
              right: 0,
              top: 0,
              child: Icon(Icons.circle, color: foreground, size: 8),
            ),
          ],
        ),
      _ => Icon(Icons.mic_none, color: foreground, size: 24),
    };

    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        child: SizedBox.square(
          dimension: AppSpacing.huge,
          child: Center(child: content),
        ),
      ),
    );
  }
}

class _ImportPanel extends ConsumerWidget {
  const _ImportPanel({required this.state});

  final SttState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = state.selectedFilePath;
    final fileName = path == null ? null : File(path).uri.pathSegments.last;
    final seedAsrSelected = SeedAsrApiService.supportsModel(
      ref.watch(settingsProvider).sttModel,
    );
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final description = fileName ??
        (seedAsrSelected
            ? context.l10n.text(
                zh: 'SeedASR 仅支持 16 kHz、16-bit、单声道 PCM WAV，最大 25 MB',
                en: 'SeedASR accepts only 16 kHz, 16-bit, mono PCM WAV files up to 25 MB',
              )
            : context.l10n.text(
                zh: '支持 MP3、MP4、MPEG、MPGA、M4A、WAV、WEBM，最大 25 MB',
                en: 'Supports MP3, MP4, MPEG, MPGA, M4A, WAV, and WEBM up to 25 MB',
              ));

    return Semantics(
      container: true,
      label: context.l10n.text(zh: '导入文件', en: 'Import a file'),
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: SizedBox.square(
                  dimension: AppSpacing.huge,
                  child: Icon(
                    fileName == null
                        ? Icons.audio_file_outlined
                        : Icons.insert_drive_file_outlined,
                    color: colors.primary,
                    size: AppSpacing.xl,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.text(
                        zh: '导入本地音频或视频',
                        en: 'Import local audio or video',
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Tooltip(
                      message: description,
                      child: Text(
                        description,
                        maxLines: textScale >= 1.3 ? null : 3,
                        overflow: textScale >= 1.3
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Tooltip(
            message: state.canStart
                ? context.l10n.text(
                    zh: '选择文件（Ctrl+O）',
                    en: 'Choose file (Ctrl+O)',
                  )
                : context.l10n.text(
                    zh: '录音或转录处理中，暂时无法选择文件',
                    en: 'A file cannot be selected while recording or transcribing.',
                  ),
            child: OutlinedButton.icon(
              onPressed: state.canStart
                  ? () => ref.read(sttProvider.notifier).pickAndTranscribe(
                        dialogTitle: context.l10n.text(
                          zh: '选择音频或视频文件',
                          en: 'Choose an audio or video file',
                        ),
                      )
                  : null,
              icon: const Icon(Icons.folder_open),
              label: Text(context.l10n.text(
                zh: '选择文件',
                en: 'Choose file',
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingStatus extends StatelessWidget {
  const _ProcessingStatus({required this.state});

  final SttState state;

  @override
  Widget build(BuildContext context) {
    final uploading = state.phase == SttPhase.uploading;
    final progress = state.uploadProgress.clamp(0.0, 1.0).toDouble();
    final hasUploadProgress = uploading && progress > 0;
    final percent = (progress * 100).round();
    final progressLabel = hasUploadProgress
        ? context.l10n.text(
            zh: '已上传 $percent%',
            en: '$percent% uploaded',
          )
        : uploading
            ? context.l10n.text(
                zh: '正在准备并上传所选文件。',
                en: 'Preparing and uploading the selected file.',
              )
            : context.l10n.text(
                zh: '正在识别语音并整理转录结果。',
                en: 'Recognizing speech and preparing the transcript.',
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStatusBanner(
          kind: AppStatusKind.info,
          title: uploading
              ? context.l10n.text(
                  zh: '正在上传音频…',
                  en: 'Uploading audio…',
                )
              : context.l10n.text(
                  zh: 'AI 正在转录…',
                  en: 'Transcribing…',
                ),
          message: progressLabel,
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: uploading
              ? context.l10n.text(
                  zh: '音频上传进度',
                  en: 'Audio upload progress',
                )
              : context.l10n.text(
                  zh: '语音转录进度',
                  en: 'Transcription progress',
                ),
          value: hasUploadProgress
              ? '$percent%'
              : context.l10n.text(zh: '处理中', en: 'Processing'),
          child: LinearProgressIndicator(
            value: hasUploadProgress ? progress : null,
          ),
        ),
      ],
    );
  }
}

class _ResultSection extends ConsumerWidget {
  const _ResultSection({
    required this.state,
    required this.controller,
    required this.onExport,
  });

  final SttState state;
  final TextEditingController controller;
  final Future<void> Function({required bool isSrt}) onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = state.result!;
    final colors = Theme.of(context).colorScheme;
    final segmentCount = result.segments.length;
    final segmentLabel = context.l10n.text(
      zh: '$segmentCount 个片段',
      en: '$segmentCount ${segmentCount == 1 ? 'segment' : 'segments'}',
    );

    return AppSection(
      title: context.l10n.text(zh: '转录结果', en: 'Transcript'),
      description: context.l10n.text(
        zh: '校对全文后，可导出纯文本或带时间戳的字幕文件。',
        en: 'Review the text, then export plain text or timestamped subtitles.',
      ),
      leading: const Icon(Icons.subject),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: context.l10n.text(
              zh: '转录结果包含 $segmentLabel',
              en: 'Transcript contains $segmentLabel',
            ),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.segment,
                    size: AppSpacing.lg,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      segmentLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('transcriptionEditor'),
            controller: controller,
            minLines: 10,
            maxLines: 18,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            onChanged: ref.read(sttProvider.notifier).updateEditedText,
            decoration: InputDecoration(
              labelText: context.l10n.text(
                zh: '可编辑全文',
                en: 'Editable transcript',
              ),
              alignLabelWithHint: true,
              helperText: context.l10n.text(
                zh: '可直接修改识别文本；编辑不会更改原始音频。',
                en: 'Edit the recognized text directly. Edits do not change the original audio.',
              ),
            ),
          ),
          if (!state.canExportSrt) ...[
            const SizedBox(height: AppSpacing.sm),
            AppStatusBanner(
              kind: AppStatusKind.info,
              message: context.l10n.text(
                zh: '当前服务未返回时间戳片段，无法导出 SRT。',
                en: 'The service did not return timestamped segments, so SRT export is unavailable.',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _AdaptiveActions(
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed:
                    state.canExport ? () => onExport(isSrt: false) : null,
                icon: const Icon(Icons.description_outlined),
                label: Text(context.l10n.text(
                  zh: '导出 TXT',
                  en: 'Export TXT',
                )),
              ),
              Tooltip(
                message: state.canExportSrt
                    ? context.l10n.text(
                        zh: '导出带时间戳字幕',
                        en: 'Export timestamped subtitles',
                      )
                    : context.l10n.text(
                        zh: '当前服务未返回时间戳片段',
                        en: 'No timestamped segments were returned',
                      ),
                child: FilledButton.tonalIcon(
                  onPressed:
                      state.canExportSrt ? () => onExport(isSrt: true) : null,
                  icon: const Icon(Icons.subtitles),
                  label: Text(context.l10n.text(
                    zh: '导出 SRT',
                    en: 'Export SRT',
                  )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdaptiveActions extends StatelessWidget {
  const _AdaptiveActions({
    required this.children,
    required this.alignment,
  });

  final List<Widget> children;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackActions = constraints.maxWidth < 420 || textScale >= 1.6;
        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                SizedBox(width: double.infinity, child: children[index]),
                if (index != children.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        }

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: alignment,
          children: children,
        );
      },
    );
  }
}

String _recordingStatus(BuildContext context, SttState state) {
  return switch (state.phase) {
    SttPhase.countdown =>
      context.l10n.text(zh: '准备录音', en: 'Preparing to record'),
    SttPhase.recording => context.l10n.text(zh: '正在录音', en: 'Recording'),
    SttPhase.paused => context.l10n.text(zh: '录音已暂停', en: 'Recording paused'),
    _ => context.l10n.text(zh: '录制新音频', en: 'Record new audio'),
  };
}

String _duration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _spokenDuration(BuildContext context, Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return context.l10n.text(
    zh: '$minutes 分 $seconds 秒',
    en: '$minutes ${minutes == 1 ? 'minute' : 'minutes'} '
        '$seconds ${seconds == 1 ? 'second' : 'seconds'}',
  );
}
