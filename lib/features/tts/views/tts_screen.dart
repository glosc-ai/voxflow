import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_section.dart';
import '../../../widgets/inline_error_banner.dart';
import '../models/tts_state.dart';
import '../providers/tts_provider.dart';
import '../widgets/desktop_tts_workspace.dart';

class TtsScreen extends ConsumerStatefulWidget {
  const TtsScreen({super.key, this.pageFocusNode});

  final FocusNode? pageFocusNode;

  @override
  ConsumerState<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends ConsumerState<TtsScreen> {
  late final TextEditingController _textController;
  String? _dismissedAudioPath;

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
    final notifier = ref.read(ttsProvider.notifier);
    final voiceOptions = notifier.availableVoices;
    final locale = Localizations.localeOf(context);
    final errorMessage = state.errorMessageFor(locale);
    final pageTitle = context.l10n.text(
      zh: '文字转语音',
      en: 'Text to speech',
    );
    ref.listen<String?>(
      ttsProvider.select((value) => value.errorMessageFor(locale)),
      (previous, next) {
        if (next != null && next != previous) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next)),
          );
        }
      },
    );

    void synthesize() {
      if (!state.isGenerating) {
        notifier.synthesize(_textController.text);
      }
    }

    return LayoutBuilder(
      builder: (context, pageConstraints) {
        final useDesktop =
            Theme.of(context).platform == TargetPlatform.windows &&
                pageConstraints.maxWidth >= 760;
        final showDesktopPlayer = useDesktop &&
            state.hasAudio &&
            _dismissedAudioPath != state.audioPath;
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
                    pageTitle,
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
          body: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter, control: true):
                  synthesize,
              const SingleActivator(LogicalKeyboardKey.numpadEnter,
                  control: true): synthesize,
              if (showDesktopPlayer)
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  unawaited(_dismissDesktopPlayer());
                },
            },
            child: Focus(
              key: const Key('ttsPageFocus'),
              focusNode: widget.pageFocusNode,
              autofocus: widget.pageFocusNode == null,
              skipTraversal: true,
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: useDesktop
                    ? DesktopTtsWorkspace(
                        state: state,
                        controller: _textController,
                        voiceOptions: voiceOptions,
                        usesSeedTtsSpeakerIds: notifier.usesSeedTtsSpeakerIds,
                        errorMessage: errorMessage,
                        showPlayer: showDesktopPlayer,
                        onSynthesize: synthesize,
                        onClear: _confirmClearText,
                        onSave: _saveDesktopAudio,
                        onDismissPlayer: _dismissDesktopPlayer,
                      )
                    : SafeArea(
                        top: false,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final platform = Theme.of(context).platform;
                            final stacked =
                                platform != TargetPlatform.windows ||
                                    AppLayout.useStackedLayout(context);
                            final editor = _TextEditorSection(
                              controller: _textController,
                              isGenerating: state.isGenerating,
                              expanded: !stacked,
                              onClear: _confirmClearText,
                            );
                            final parameters = _VoiceParametersSection(
                              state: state,
                              voiceOptions: voiceOptions,
                              usesSeedTtsSpeakerIds:
                                  notifier.usesSeedTtsSpeakerIds,
                              showKeyboardHint:
                                  platform == TargetPlatform.windows,
                              onSynthesize: synthesize,
                            );

                            return SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: AppLayout.pagePadding(context),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 960),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (errorMessage != null) ...[
                                        InlineErrorBanner(
                                          message: errorMessage,
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                      ],
                                      if (stacked) ...[
                                        editor,
                                        const SizedBox(height: AppSpacing.md),
                                        parameters,
                                      ] else
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(flex: 3, child: editor),
                                            const SizedBox(
                                                width: AppSpacing.md),
                                            Expanded(
                                                flex: 2, child: parameters),
                                          ],
                                        ),
                                      if (state.hasAudio) ...[
                                        const SizedBox(height: AppSpacing.md),
                                        _PlayerCard(state: state),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveDesktopAudio() async {
    try {
      final saved = await ref.read(ttsProvider.notifier).saveCopy(
            dialogTitle: context.l10n.text(
              zh: '保存合成语音',
              en: 'Save generated speech',
            ),
          );
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.text(zh: 'MP3 已保存。', en: 'MP3 saved.'),
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

  Future<void> _dismissDesktopPlayer() async {
    final state = ref.read(ttsProvider);
    if (state.isPlaying) {
      await ref.read(ttsProvider.notifier).playOrPause();
    }
    if (mounted) {
      setState(() => _dismissedAudioPath = state.audioPath);
    }
  }

  Future<void> _confirmClearText() async {
    if (_textController.text.isEmpty) {
      return;
    }
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: Icon(Icons.clear_all, color: colors.error),
        title: Text(l10n.text(
          zh: '清空输入文字？',
          en: 'Clear input text?',
        )),
        content: Text(l10n.text(
          zh: '未保存的输入将被永久删除且无法撤销。已生成或已保存的音频不会受影响。',
          en: 'Unsaved input will be permanently deleted and cannot be recovered. Generated or saved audio will not be affected.',
        )),
        actions: [
          TextButton(
            key: const Key('cancelClearTtsTextButton'),
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.text(zh: '取消', en: 'Cancel')),
          ),
          Semantics(
            button: true,
            label: l10n.text(
              zh: '确认永久清空未保存的输入文字',
              en: 'Confirm permanently clearing the unsaved input text',
            ),
            excludeSemantics: true,
            onTap: () => Navigator.pop(context, true),
            child: FilledButton(
              key: const Key('confirmClearTtsTextButton'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.text(zh: '清空', en: 'Clear')),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _textController.clear();
    }
  }
}

class _TextEditorSection extends StatelessWidget {
  const _TextEditorSection({
    required this.controller,
    required this.isGenerating,
    required this.expanded,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool isGenerating;
  final bool expanded;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isShortViewport = MediaQuery.sizeOf(context).height < 700;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return AppSection(
          title: context.l10n.text(zh: '输入文字', en: 'Enter text'),
          description: context.l10n.text(
            zh: '输入或粘贴需要转换为语音的内容。',
            en: 'Enter or paste the content to convert into speech.',
          ),
          leading: const Icon(Icons.text_fields_outlined),
          trailing: IconButton(
            tooltip: context.l10n.text(zh: '清空文字', en: 'Clear text'),
            onPressed: value.text.isEmpty || isGenerating ? null : onClear,
            icon: const Icon(Icons.clear_all),
          ),
          child: TextField(
            key: const Key('ttsTextField'),
            controller: controller,
            minLines: expanded ? 12 : (isShortViewport ? 4 : 7),
            maxLines: expanded ? 18 : 14,
            maxLength: AppConstants.maxTtsCharacters,
            readOnly: isGenerating,
            enableInteractiveSelection: true,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: context.l10n.text(
                zh: '待合成文字',
                en: 'Text to synthesize',
              ),
              hintText: context.l10n.text(
                zh: '输入最多 4096 个字符，生成自然语音…',
                en: 'Enter up to 4,096 characters to generate natural speech…',
              ),
              helperText: isGenerating
                  ? context.l10n.text(
                      zh: '正在合成，文字暂时只读；仍可选择并复制。',
                      en: 'Text is read-only while speech is generated, but it can still be selected and copied.',
                    )
                  : context.l10n.text(
                      zh: '支持中英文；在 Windows 上可按 Ctrl+Enter 合成。',
                      en: 'Supports Chinese and English. On Windows, press Ctrl+Enter to generate speech.',
                    ),
              alignLabelWithHint: true,
            ),
            buildCounter: (
              context, {
              required currentLength,
              required isFocused,
              maxLength,
            }) {
              final limit = maxLength ?? AppConstants.maxTtsCharacters;
              final isNearLimit = currentLength >= (limit * 0.9).ceil();
              final theme = Theme.of(context);
              final semanticColors = theme.extension<AppSemanticColors>();
              final counterColor = isNearLimit
                  ? semanticColors?.warning ?? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant;
              return Semantics(
                label: context.l10n.text(
                  zh: '已输入 $currentLength 个字符，共可输入 $limit 个字符',
                  en: '$currentLength of $limit ${limit == 1 ? 'character' : 'characters'} entered',
                ),
                child: Text(
                  '$currentLength / $limit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: counterColor,
                    fontWeight: isNearLimit ? FontWeight.w600 : FontWeight.w400,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _VoiceParametersSection extends ConsumerWidget {
  const _VoiceParametersSection({
    required this.state,
    required this.voiceOptions,
    required this.usesSeedTtsSpeakerIds,
    required this.showKeyboardHint,
    required this.onSynthesize,
  });

  final TtsState state;
  final List<String> voiceOptions;
  final bool usesSeedTtsSpeakerIds;
  final bool showKeyboardHint;
  final VoidCallback onSynthesize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semanticColors = theme.extension<AppSemanticColors>();
    final surfaceSubtle =
        semanticColors?.surfaceSubtle ?? colors.surfaceContainerHigh;
    final speedText = '${state.speed.toStringAsFixed(2)}×';

    return AppSection(
      title: context.l10n.text(zh: '语音参数', en: 'Voice settings'),
      description: context.l10n.text(
        zh: '选择音色，并调整合成语音的播放速度。',
        en: 'Choose a voice and adjust the generated speech speed.',
      ),
      leading: const Icon(Icons.tune),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('ttsVoice:${state.voice}'),
            initialValue: state.voice,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.l10n.text(zh: '音色', en: 'Voice'),
            ),
            items: voiceOptions
                .map(
                  (voice) => DropdownMenuItem(
                    value: voice,
                    child: Text(
                      voice,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: state.isGenerating
                ? null
                : (voice) {
                    if (voice != null) {
                      ref.read(ttsProvider.notifier).setVoice(voice);
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            usesSeedTtsSpeakerIds
                ? context.l10n.text(
                    zh: 'Seed TTS 使用火山模型专属 Speaker ID。',
                    en: 'Seed TTS uses a model-specific Volcengine Speaker ID.',
                  )
                : context.l10n.text(
                    zh: '当前 Speaker ID：${state.voice}',
                    en: 'Current Speaker ID: ${state.voice}',
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final label = Text(
                context.l10n.text(zh: '语速', en: 'Speed'),
                style: theme.textTheme.titleSmall,
              );
              final value = DecoratedBox(
                decoration: BoxDecoration(
                  color: surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Text(
                    speedText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              );
              if (MediaQuery.textScalerOf(context).scale(1) >= 1.6 ||
                  constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: AppSpacing.xs),
                    value,
                  ],
                );
              }
              return Row(
                children: [label, const Spacer(), value],
              );
            },
          ),
          Slider(
            value: state.speed,
            min: 0.25,
            max: 4.0,
            divisions: 15,
            label: speedText,
            semanticFormatterCallback: (value) => context.l10n.text(
              zh: '语速 ${value.toStringAsFixed(2)} 倍',
              en: 'Speed ${value.toStringAsFixed(2)} times',
            ),
            onChanged: state.isGenerating
                ? null
                : ref.read(ttsProvider.notifier).setSpeed,
          ),
          Text(
            context.l10n.text(
              zh: '范围 0.25×–4.00×；可使用方向键微调。',
              en: 'Range 0.25×–4.00×. Use the arrow keys for fine adjustments.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('synthesizeButton'),
            onPressed: state.isGenerating ? null : onSynthesize,
            icon: SizedBox.square(
              key: const Key('ttsGenerateIconSlot'),
              dimension: 24,
              child: Center(
                child: state.isGenerating
                    ? CircularProgressIndicator(
                        key: const Key('ttsGeneratingIndicator'),
                        strokeWidth: 2,
                        color: colors.onSurface,
                      )
                    : const Icon(Icons.volume_up_outlined),
              ),
            ),
            label: IndexedStack(
              key: const Key('ttsGenerateLabelStack'),
              index: state.isGenerating ? 1 : 0,
              alignment: Alignment.center,
              children: [
                Text(context.l10n.text(
                  zh: '合成语音',
                  en: 'Generate speech',
                )),
                Text(context.l10n.text(
                  zh: '正在合成…',
                  en: 'Generating…',
                )),
              ],
            ),
          ),
          if (showKeyboardHint) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.text(
                zh: '快捷键：Ctrl+Enter',
                en: 'Shortcut: Ctrl+Enter',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactHeader =
        MediaQuery.sizeOf(context).width < 600 || textScale >= 1.3;

    return AppSection(
      title: context.l10n.text(zh: '合成音频', en: 'Generated audio'),
      description: _playerStatus(context, state),
      leading: Icon(_playerStatusIcon(state)),
      trailing: compactHeader
          ? IconButton(
              tooltip: context.l10n.text(
                zh: '另存为 MP3',
                en: 'Save as MP3',
              ),
              onPressed: () => _save(context, notifier),
              icon: const Icon(Icons.download_outlined),
            )
          : OutlinedButton.icon(
              onPressed: () => _save(context, notifier),
              icon: const Icon(Icons.download_outlined),
              label: Text(context.l10n.text(
                zh: '保存 MP3',
                en: 'Save MP3',
              )),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlayerTransport(state: state, notifier: notifier),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          _VolumeControl(state: state, notifier: notifier),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, TtsNotifier notifier) async {
    try {
      final saved = await notifier.saveCopy(
        dialogTitle: context.l10n.text(
          zh: '保存合成语音',
          en: 'Save generated speech',
        ),
      );
      if (saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.text(
              zh: 'MP3 已保存。',
              en: 'MP3 saved.',
            )),
          ),
        );
      }
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.appError(error))),
        );
      }
    }
  }
}

class _PlayerTransport extends StatelessWidget {
  const _PlayerTransport({required this.state, required this.notifier});

  final TtsState state;
  final TtsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final durationMilliseconds = state.duration.inMilliseconds;
    final maxPosition = durationMilliseconds > 0 ? durationMilliseconds : 1;
    final position = state.position.inMilliseconds.clamp(0, maxPosition);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final timeLabel =
        '${_duration(state.position)} / ${_duration(state.duration)}';
    final playButton = IconButton.filledTonal(
      tooltip: state.isPlaying
          ? context.l10n.text(zh: '暂停', en: 'Pause')
          : context.l10n.text(zh: '播放', en: 'Play'),
      onPressed: notifier.playOrPause,
      icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
    );
    final progress = Slider(
      value: position.toDouble(),
      min: 0,
      max: maxPosition.toDouble(),
      semanticFormatterCallback: (value) => context.l10n.text(
        zh: '播放进度 ${_duration(Duration(milliseconds: value.round()))}',
        en: 'Playback position ${_duration(Duration(milliseconds: value.round()))}',
      ),
      onChanged: (value) => notifier.seek(
        Duration(milliseconds: value.round()),
      ),
    );
    final time = Semantics(
      label: context.l10n.text(
        zh: '当前 ${_duration(state.position)}，总时长 ${_duration(state.duration)}',
        en: 'Current position ${_duration(state.position)}, total duration ${_duration(state.duration)}',
      ),
      child: Text(
        timeLabel,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 600 || textScale >= 1.6;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  playButton,
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      state.isPlaying
                          ? context.l10n.text(
                              zh: '正在播放',
                              en: 'Playing',
                            )
                          : context.l10n.text(
                              zh: '播放控制',
                              en: 'Playback controls',
                            ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  time,
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              progress,
            ],
          );
        }
        return Row(
          children: [
            playButton,
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: progress),
            const SizedBox(width: AppSpacing.sm),
            time,
          ],
        );
      },
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({required this.state, required this.notifier});

  final TtsState state;
  final TtsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final volumePercent = '${(state.volume * 100).round()}%';
    final icon = Semantics(
      label: state.volume == 0
          ? context.l10n.text(zh: '已静音', en: 'Muted')
          : context.l10n.text(zh: '音量', en: 'Volume'),
      child: Icon(
        state.volume == 0 ? Icons.volume_off : Icons.volume_up,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    final slider = Slider(
      value: state.volume,
      min: 0,
      max: 1,
      divisions: 20,
      label: volumePercent,
      semanticFormatterCallback: (value) => context.l10n.text(
        zh: '音量 ${(value * 100).round()}%',
        en: 'Volume ${(value * 100).round()}%',
      ),
      onChanged: notifier.setVolume,
    );
    final value = Text(
      volumePercent,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 480 || textScale >= 1.6;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  icon,
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      context.l10n.text(zh: '音量', en: 'Volume'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  value,
                ],
              ),
              slider,
            ],
          );
        }
        return Row(
          children: [
            icon,
            const SizedBox(width: AppSpacing.sm),
            Text(
              context.l10n.text(zh: '音量', en: 'Volume'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: slider),
            const SizedBox(width: AppSpacing.sm),
            value,
          ],
        );
      },
    );
  }
}

String _playerStatus(BuildContext context, TtsState state) {
  return switch (state.phase) {
    TtsPhase.playing => context.l10n.text(
        zh: '正在播放。',
        en: 'Playing.',
      ),
    TtsPhase.paused => context.l10n.text(
        zh: '播放已暂停，可继续播放或保存。',
        en: 'Playback is paused. Resume or save the audio.',
      ),
    TtsPhase.completed => context.l10n.text(
        zh: '播放完成，可重新播放或保存。',
        en: 'Playback finished. Replay or save the audio.',
      ),
    TtsPhase.failure => context.l10n.text(
        zh: '音频仍可使用，请查看上方错误信息。',
        en: 'The audio is still available. Review the error above.',
      ),
    _ => context.l10n.text(
        zh: '音频已生成，可播放或保存为 MP3。',
        en: 'Audio generated. Play it or save it as MP3.',
      ),
  };
}

IconData _playerStatusIcon(TtsState state) {
  return switch (state.phase) {
    TtsPhase.playing => Icons.graphic_eq,
    TtsPhase.paused => Icons.pause_circle_outline,
    TtsPhase.completed => Icons.check_circle_outline,
    TtsPhase.failure => Icons.error_outline,
    _ => Icons.audio_file_outlined,
  };
}

String _duration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
