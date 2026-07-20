import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../models/tts_state.dart';
import '../providers/tts_provider.dart';

class TtsScreen extends ConsumerStatefulWidget {
  const TtsScreen({super.key});

  @override
  ConsumerState<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends ConsumerState<TtsScreen> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ttsProvider);
    ref.listen<String?>(
      ttsProvider.select((value) => value.errorMessage),
      (previous, next) {
        if (next != null && next != previous) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next)),
          );
        }
      },
    );
    return Scaffold(
      appBar: AppBar(title: const Text('文字转语音')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '输入文字',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('ttsTextField'),
                          controller: _textController,
                          minLines: 7,
                          maxLines: 14,
                          maxLength: AppConstants.maxTtsCharacters,
                          enabled: !state.isGenerating,
                          decoration: const InputDecoration(
                            hintText: '输入最多 4096 个字符，生成自然语音…',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '语音参数',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: state.voice,
                          decoration: const InputDecoration(labelText: '音色'),
                          items: AppConstants.voices
                              .map(
                                (voice) => DropdownMenuItem(
                                  value: voice,
                                  child: Text(voice),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: state.isGenerating
                              ? null
                              : (voice) {
                                  if (voice != null) {
                                    ref
                                        .read(ttsProvider.notifier)
                                        .setVoice(voice);
                                  }
                                },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Text('语速'),
                            Expanded(
                              child: Slider(
                                value: state.speed,
                                min: 0.25,
                                max: 4.0,
                                divisions: 15,
                                label: '${state.speed.toStringAsFixed(2)}×',
                                onChanged: state.isGenerating
                                    ? null
                                    : ref.read(ttsProvider.notifier).setSpeed,
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: Text('${state.speed.toStringAsFixed(2)}×'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('synthesizeButton'),
                          onPressed: state.isGenerating
                              ? null
                              : () => ref
                                  .read(ttsProvider.notifier)
                                  .synthesize(_textController.text),
                          icon: state.isGenerating
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(state.isGenerating ? '正在合成…' : '合成语音'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.hasAudio) ...[
                  const SizedBox(height: 16),
                  _PlayerCard(state: state),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerCard extends ConsumerWidget {
  const _PlayerCard({required this.state});

  final TtsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ttsProvider.notifier);
    final durationMilliseconds = state.duration.inMilliseconds;
    final maxPosition = durationMilliseconds > 0 ? durationMilliseconds : 1;
    final position = state.position.inMilliseconds.clamp(0, maxPosition);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '合成音频',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  tooltip: '另存为 MP3',
                  onPressed: () => _save(context, notifier),
                  icon: const Icon(Icons.download),
                ),
              ],
            ),
            Row(
              children: [
                IconButton.filled(
                  tooltip: state.isPlaying ? '暂停' : '播放',
                  onPressed: notifier.playOrPause,
                  icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
                Expanded(
                  child: Slider(
                    value: position.toDouble(),
                    min: 0,
                    max: maxPosition.toDouble(),
                    onChanged: (value) => notifier.seek(
                      Duration(milliseconds: value.round()),
                    ),
                  ),
                ),
                Text(
                  '${_duration(state.position)} / ${_duration(state.duration)}',
                ),
              ],
            ),
            Row(
              children: [
                Icon(state.volume == 0 ? Icons.volume_off : Icons.volume_up),
                Expanded(
                  child: Slider(
                    value: state.volume,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    onChanged: notifier.setVolume,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, TtsNotifier notifier) async {
    try {
      final saved = await notifier.saveCopy();
      if (saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MP3 已保存。')),
        );
      }
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }
}

String _duration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
