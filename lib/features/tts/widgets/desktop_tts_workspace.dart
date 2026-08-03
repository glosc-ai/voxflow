import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/inline_error_banner.dart';
import '../../settings/widgets/speech_model_selector.dart';
import '../models/tts_state.dart';
import '../providers/tts_provider.dart';

class DesktopTtsWorkspace extends ConsumerWidget {
  const DesktopTtsWorkspace({
    required this.state,
    required this.controller,
    required this.voiceOptions,
    required this.usesSeedTtsSpeakerIds,
    required this.errorMessage,
    required this.showPlayer,
    required this.onSynthesize,
    required this.onClear,
    required this.onSave,
    required this.onDismissPlayer,
    super.key,
  });

  final TtsState state;
  final TextEditingController controller;
  final List<String> voiceOptions;
  final bool usesSeedTtsSpeakerIds;
  final String? errorMessage;
  final bool showPlayer;
  final VoidCallback onSynthesize;
  final VoidCallback onClear;
  final Future<void> Function() onSave;
  final Future<void> Function() onDismissPlayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            150,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorMessage != null) ...[
                    InlineErrorBanner(message: errorMessage!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _DesktopTtsHeader(state: state),
                  const SizedBox(height: AppSpacing.xl),
                  _DesktopTextCard(
                    controller: controller,
                    isGenerating: state.isGenerating,
                    onClear: onClear,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _VoiceHeading(
                    count: voiceOptions.length,
                    usesSeedTtsSpeakerIds: usesSeedTtsSpeakerIds,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _VoiceCards(
                    state: state,
                    voices: voiceOptions,
                    usesSeedTtsSpeakerIds: usesSeedTtsSpeakerIds,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SynthesisControls(
                    state: state,
                    controller: controller,
                    onSynthesize: onSynthesize,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showPlayer)
          Positioned(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: AppSpacing.md,
            child: Center(
              child: _DesktopPlayerDock(
                state: state,
                onSave: onSave,
                onDismiss: onDismissPlayer,
              ),
            ),
          ),
      ],
    );
  }
}

class _DesktopTtsHeader extends StatelessWidget {
  const _DesktopTtsHeader({required this.state});

  final TtsState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.text(
            zh: 'TEXT TO SPEECH · 语音合成',
            en: 'TEXT TO SPEECH · SYNTHESIS',
          ),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.primary,
            letterSpacing: 1.2,
            fontFamily: 'Cascadia Code',
            fontFamilyFallback: const ['JetBrains Mono', 'Consolas'],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.text(zh: '文字转语音', en: 'Text to speech'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
        ),
      ],
    );
    final selector = SpeechModelSelector(
      key: const Key('desktopTtsModelSelector'),
      kind: SpeechModelKind.tts,
      enabled: !state.isGenerating,
    );
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.6) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: AppSpacing.md),
          selector,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: title),
        const SizedBox(width: AppSpacing.md),
        Flexible(child: selector),
      ],
    );
  }
}

class _DesktopTextCard extends StatelessWidget {
  const _DesktopTextCard({
    required this.controller,
    required this.isGenerating,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final colors = Theme.of(context).colorScheme;
        final currentLength = value.text.length;
        final nearLimit =
            currentLength >= (AppConstants.maxTtsCharacters * 0.9).ceil();
        return _DesktopSurface(
          radius: 19,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('ttsTextField'),
                controller: controller,
                minLines: 7,
                maxLines: 14,
                maxLength: AppConstants.maxTtsCharacters,
                readOnly: isGenerating,
                enableInteractiveSelection: true,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: context.l10n.text(
                    zh: '输入或粘贴要转换为语音的文字…',
                    en: 'Enter or paste text to convert to speech…',
                  ),
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.7,
                    ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Tooltip(
                      message: context.l10n.text(zh: '清空文字', en: 'Clear text'),
                      child: TextButton.icon(
                        onPressed:
                            value.text.isEmpty || isGenerating ? null : onClear,
                        icon: const Icon(Icons.clear_all, size: 17),
                        label: Text(
                          context.l10n.text(zh: '清空', en: 'Clear'),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Semantics(
                      label: context.l10n.text(
                        zh: '已输入 $currentLength 个字符，共可输入 ${AppConstants.maxTtsCharacters} 个字符',
                        en: '$currentLength of ${AppConstants.maxTtsCharacters} characters entered',
                      ),
                      child: Text(
                        '$currentLength / ${AppConstants.maxTtsCharacters}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: nearLimit
                              ? colors.error
                              : colors.onSurfaceVariant,
                          fontWeight:
                              nearLimit ? FontWeight.w600 : FontWeight.w500,
                          fontFamily: 'Cascadia Code',
                          fontFamilyFallback: const [
                            'JetBrains Mono',
                            'Consolas',
                          ],
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VoiceHeading extends StatelessWidget {
  const _VoiceHeading({
    required this.count,
    required this.usesSeedTtsSpeakerIds,
  });

  final int count;
  final bool usesSeedTtsSpeakerIds;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.text(zh: '选择音色', en: 'Choose a voice'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (usesSeedTtsSpeakerIds) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            context.l10n.text(
              zh: 'Seed TTS 使用火山模型专属 Speaker ID。',
              en: 'Seed TTS uses a model-specific Volcengine Speaker ID.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
    final meta = Text(
      context.l10n.text(
        zh: '$count 款可用音色 · 横向滚动',
        en: '$count ${count == 1 ? 'voice' : 'voices'} · horizontal scroll',
      ),
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colors.onSurfaceVariant,
        fontFamily: 'Cascadia Code',
        fontFamilyFallback: const ['JetBrains Mono', 'Consolas'],
      ),
    );
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.6) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: AppSpacing.xs),
          meta,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: title),
        const SizedBox(width: AppSpacing.md),
        meta,
      ],
    );
  }
}

class _VoiceCards extends ConsumerWidget {
  const _VoiceCards({
    required this.state,
    required this.voices,
    required this.usesSeedTtsSpeakerIds,
  });

  final TtsState state;
  final List<String> voices;
  final bool usesSeedTtsSpeakerIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      key: ValueKey('ttsVoice:${state.voice}'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(2, 2, 2, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < voices.length; index++) ...[
            _VoiceCard(
              voice: voices[index],
              selected: state.voice == voices[index],
              enabled: !state.isGenerating,
              usesSeedTtsSpeakerIds: usesSeedTtsSpeakerIds,
              onSelected: () =>
                  ref.read(ttsProvider.notifier).setVoice(voices[index]),
            ),
            if (index != voices.length - 1)
              const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _VoiceCard extends StatefulWidget {
  const _VoiceCard({
    required this.voice,
    required this.selected,
    required this.enabled,
    required this.usesSeedTtsSpeakerIds,
    required this.onSelected,
  });

  final String voice;
  final bool selected;
  final bool enabled;
  final bool usesSeedTtsSpeakerIds;
  final VoidCallback onSelected;

  @override
  State<_VoiceCard> createState() => _VoiceCardState();
}

class _VoiceCardState extends State<_VoiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final metadata = _voiceMetadata(context, widget.voice);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: widget.enabled,
      label: context.l10n.text(
        zh: '音色 ${metadata.name}${widget.selected ? '，已选择' : ''}',
        en: '${metadata.name} voice${widget.selected ? ', selected' : ''}',
      ),
      child: ExcludeSemantics(
        child: AnimatedScale(
          scale: _hovered && widget.enabled ? 1.015 : 1,
          duration:
              reducedMotion ? Duration.zero : const Duration(milliseconds: 120),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
                side: BorderSide(
                  color:
                      widget.selected ? colors.primary : colors.outlineVariant,
                ),
              ),
              elevation: _hovered ? 3 : 1,
              shadowColor: colors.shadow.withValues(alpha: 0.10),
              child: InkWell(
                onTap: widget.enabled ? widget.onSelected : null,
                borderRadius: BorderRadius.circular(19),
                child: Container(
                  width: widget.usesSeedTtsSpeakerIds
                      ? (largeText ? 340 : 280)
                      : (largeText ? 220 : 160),
                  constraints: const BoxConstraints(minHeight: 126),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: widget.selected
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(19),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.10),
                              spreadRadius: 3,
                            ),
                          ],
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              metadata.name,
                              maxLines: largeText
                                  ? 3
                                  : (widget.usesSeedTtsSpeakerIds ? 2 : 1),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: widget.selected ? 1 : 0,
                            duration: reducedMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.check_circle,
                              size: 18,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        widget.voice,
                        maxLines: largeText ? 4 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFamily: 'Cascadia Code',
                          fontFamilyFallback: const [
                            'JetBrains Mono',
                            'Consolas',
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        metadata.description,
                        maxLines: largeText ? 4 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SynthesisControls extends ConsumerWidget {
  const _SynthesisControls({
    required this.state,
    required this.controller,
    required this.onSynthesize,
  });

  final TtsState state;
  final TextEditingController controller;
  final VoidCallback onSynthesize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final colors = Theme.of(context).colorScheme;
        final speedText = '${_compactNumber(state.speed)}×';
        final estimate = _estimatedSeconds(value.text.length, state.speed);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DesktopSurface(
              radius: 13,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    context.l10n.text(zh: '合成语速', en: 'Synthesis speed'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Slider(
                      value: state.speed,
                      min: 0.25,
                      max: 4,
                      divisions: 15,
                      label: speedText,
                      semanticFormatterCallback: (speed) => context.l10n.text(
                        zh: '合成语速 ${speed.toStringAsFixed(2)} 倍',
                        en: 'Synthesis speed ${speed.toStringAsFixed(2)} times',
                      ),
                      onChanged: state.isGenerating
                          ? null
                          : ref.read(ttsProvider.notifier).setSpeed,
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      speedText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cascadia Code',
                        fontFamilyFallback: const [
                          'JetBrains Mono',
                          'Consolas',
                        ],
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
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
                      Text(
                        context.l10n.text(
                          zh: '合成语音',
                          en: 'Generate speech',
                        ),
                      ),
                      Text(
                        context.l10n.text(
                          zh: '正在合成…',
                          en: 'Generating…',
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  value.text.trim().isEmpty
                      ? context.l10n.text(
                          zh: '输入文字后可估算音频时长',
                          en: 'Enter text to estimate audio duration',
                        )
                      : context.l10n.text(
                          zh: '预计生成 ≈ ${_duration(Duration(seconds: estimate))} 音频',
                          en: 'Estimated audio ≈ ${_duration(Duration(seconds: estimate))}',
                        ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'Cascadia Code',
                    fontFamilyFallback: const [
                      'JetBrains Mono',
                      'Consolas',
                    ],
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.text(
                zh: '快捷键：Ctrl+Enter',
                en: 'Shortcut: Ctrl+Enter',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        );
      },
    );
  }
}

class _DesktopPlayerDock extends ConsumerWidget {
  const _DesktopPlayerDock({
    required this.state,
    required this.onSave,
    required this.onDismiss,
  });

  final TtsState state;
  final Future<void> Function() onSave;
  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ttsProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final durationMilliseconds = math.max(state.duration.inMilliseconds, 1);
    final position = state.position.inMilliseconds.clamp(
      0,
      durationMilliseconds,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration:
          reducedMotion ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * 24),
          child: child,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680 ||
                MediaQuery.textScalerOf(context).scale(1) >= 1.5;
            final playButton = Semantics(
              button: true,
              label: state.isPlaying
                  ? context.l10n.text(zh: '暂停', en: 'Pause')
                  : context.l10n.text(zh: '播放', en: 'Play'),
              child: IconButton.filled(
                tooltip: state.isPlaying
                    ? context.l10n.text(zh: '暂停', en: 'Pause')
                    : context.l10n.text(zh: '播放', en: 'Play'),
                onPressed: notifier.playOrPause,
                icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
            );
            final wave = _WaveProgress(
              value: position.toDouble(),
              max: durationMilliseconds.toDouble(),
              isPlaying: state.isPlaying,
              onChanged: (value) => notifier.seek(
                Duration(milliseconds: value.round()),
              ),
            );
            final time = Semantics(
              label: context.l10n.text(
                zh: '当前 ${_duration(state.position)}，总时长 ${_duration(state.duration)}',
                en: 'Current ${_duration(state.position)}, total ${_duration(state.duration)}',
              ),
              child: Text(
                '${_duration(state.position)} / ${_duration(state.duration)}',
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFamily: 'Cascadia Code',
                  fontFamilyFallback: const ['JetBrains Mono', 'Consolas'],
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            );
            final speed = Tooltip(
              message: context.l10n.text(
                zh: '当前合成语速设置（只读，不是播放速度）',
                en: 'Current synthesis speed setting (read only, not playback speed)',
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: ShapeDecoration(
                  color: colors.surface,
                  shape: StadiumBorder(
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                ),
                child: Text(
                  '${_compactNumber(state.speed)}×',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFamily: 'Cascadia Code',
                    fontFamilyFallback: const ['JetBrains Mono', 'Consolas'],
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            );
            Widget volume(double width) => SizedBox(
                  width: width,
                  child: Row(
                    children: [
                      Icon(
                        state.volume == 0
                            ? Icons.volume_off_outlined
                            : Icons.volume_up_outlined,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      Expanded(
                        child: Slider(
                          value: state.volume,
                          min: 0,
                          max: 1,
                          divisions: 20,
                          semanticFormatterCallback: (volume) =>
                              context.l10n.text(
                            zh: '音量 ${(volume * 100).round()}%',
                            en: 'Volume ${(volume * 100).round()}%',
                          ),
                          onChanged: notifier.setVolume,
                        ),
                      ),
                    ],
                  ),
                );
            final saveButton = IconButton(
              tooltip: context.l10n.text(zh: '保存 MP3', en: 'Save MP3'),
              onPressed: onSave,
              icon: const Icon(Icons.download_outlined, size: 20),
            );
            final closeButton = IconButton(
              tooltip: context.l10n.text(zh: '关闭播放器', en: 'Close player'),
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 20),
            );

            return _DesktopSurface(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: compact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            playButton,
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: wave),
                            const SizedBox(width: AppSpacing.sm),
                            time,
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          children: [
                            speed,
                            const SizedBox(width: AppSpacing.xs),
                            volume(150),
                            const Spacer(),
                            saveButton,
                            closeButton,
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        playButton,
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: wave),
                        const SizedBox(width: AppSpacing.sm),
                        time,
                        const SizedBox(width: AppSpacing.sm),
                        speed,
                        const SizedBox(width: AppSpacing.xs),
                        volume(94),
                        saveButton,
                        closeButton,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _WaveProgress extends StatelessWidget {
  const _WaveProgress({
    required this.value,
    required this.max,
    required this.isPlaying,
    required this.onChanged,
  });

  final double value;
  final double max;
  final bool isPlaying;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Semantics(
      label: context.l10n.text(zh: '播放进度', en: 'Playback position'),
      child: SizedBox(
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var index = 0; index < 34; index++)
                    Container(
                      width: 3,
                      height: 8 + ((index * 11) % 21).toDouble(),
                      decoration: BoxDecoration(
                        color: index / 34 <= ratio
                            ? colors.primary
                            : colors.primary.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: colors.primary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(0, max),
                min: 0,
                max: max,
                semanticFormatterCallback: (position) => context.l10n.text(
                  zh: '播放进度 ${_duration(Duration(milliseconds: position.round()))}',
                  en: 'Playback position ${_duration(Duration(milliseconds: position.round()))}',
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSurface extends StatelessWidget {
  const _DesktopSurface({
    required this.child,
    required this.radius,
    required this.padding,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.24 : 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

_VoiceMetadata _voiceMetadata(BuildContext context, String voice) {
  final isZh = Localizations.localeOf(context).languageCode == 'zh';
  return switch (voice) {
    'alloy' => _VoiceMetadata(
        name: 'Alloy',
        description: isZh ? '中性 · 通用助手' : 'Neutral · general assistant',
      ),
    'echo' => _VoiceMetadata(
        name: 'Echo',
        description: isZh ? '男声 · 旁白' : 'Masculine · narration',
      ),
    'fable' => _VoiceMetadata(
        name: 'Fable',
        description: isZh ? '叙事 · 故事' : 'Expressive · storytelling',
      ),
    'onyx' => _VoiceMetadata(
        name: 'Onyx',
        description: isZh ? '男声 · 沉稳' : 'Deep · composed',
      ),
    'nova' => _VoiceMetadata(
        name: 'Nova',
        description: isZh ? '女声 · 清亮' : 'Bright · clear',
      ),
    'shimmer' => _VoiceMetadata(
        name: 'Shimmer',
        description: isZh ? '女声 · 轻柔' : 'Soft · calm',
      ),
    _ => _VoiceMetadata(
        name: voice,
        description: isZh ? '模型专属音色' : 'Model-specific voice',
      ),
  };
}

class _VoiceMetadata {
  const _VoiceMetadata({required this.name, required this.description});

  final String name;
  final String description;
}

int _estimatedSeconds(int characterCount, double speed) {
  if (characterCount <= 0) {
    return 0;
  }
  return math.max(1, (characterCount / (5 * speed)).ceil());
}

String _compactNumber(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed
      .replaceFirst(RegExp(r'\.0+$'), '')
      .replaceFirst(RegExp(r'0$'), '');
}

String _duration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
