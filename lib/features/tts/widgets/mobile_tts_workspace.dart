import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/volcengine_tts_voice_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/inline_error_banner.dart';
import '../../../widgets/mobile_design.dart';
import '../../settings/widgets/speech_model_selector.dart';
import '../models/tts_state.dart';
import '../providers/tts_provider.dart';

class MobileTtsWorkspace extends ConsumerWidget {
  const MobileTtsWorkspace({
    super.key,
    required this.state,
    required this.controller,
    required this.voiceOptions,
    required this.usesBytedanceSpeakerIds,
    required this.errorMessage,
    required this.showPlayer,
    required this.onSynthesize,
    required this.onClear,
    required this.onSave,
    required this.onDismissPlayer,
  });

  final TtsState state;
  final TextEditingController controller;
  final List<String> voiceOptions;
  final bool usesBytedanceSpeakerIds;
  final String? errorMessage;
  final bool showPlayer;
  final VoidCallback onSynthesize;
  final VoidCallback onClear;
  final Future<void> Function() onSave;
  final Future<void> Function() onDismissPlayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerVisible = showPlayer && !state.isGenerating;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final scaffoldBottom = MediaQuery.paddingOf(context).bottom;
    final basePagePadding = MobileLayout.pagePadding(context);
    final pagePadding = basePagePadding.copyWith(
      bottom: basePagePadding.bottom + (playerVisible ? 190 : 0),
    );
    final effectivePlayerBottom = math
        .max(MobileLayout.playerBottom + safeBottom, scaffoldBottom + 14)
        .toDouble();
    return Stack(
      key: const Key('mobileTtsWorkspace'),
      children: [
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MobileViewHeader(
                    eyebrow: context.l10n.text(
                      zh: 'Text to Speech · 语音合成',
                      en: 'Text to Speech · Synthesis',
                    ),
                    title: context.l10n.text(zh: '文字转语音', en: 'Text to speech'),
                    accessories: [
                      SpeechModelSelector(
                        kind: SpeechModelKind.tts,
                        enabled: !state.isGenerating,
                      ),
                    ],
                  ),
                  if (errorMessage != null) ...[
                    InlineErrorBanner(message: errorMessage!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _MobileTextEditor(
                    controller: controller,
                    isGenerating: state.isGenerating,
                    onClear: onClear,
                  ),
                  MobileSectionLabel(
                    title: context.l10n.text(zh: '选择音色', en: 'Choose a voice'),
                    meta: context.l10n.text(
                      zh: '横向滑动',
                      en: 'Swipe horizontally',
                    ),
                  ),
                  _MobileVoiceList(
                    state: state,
                    voices: voiceOptions,
                    usesBytedanceSpeakerIds: usesBytedanceSpeakerIds,
                  ),
                  if (usesBytedanceSpeakerIds)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 2,
                        right: 2,
                        bottom: AppSpacing.xs,
                      ),
                      child: Text(
                        context.l10n.text(
                          zh: 'ByteDance Seed-TTS 2.0 使用火山引擎 Speaker ID。',
                          en: 'ByteDance Seed-TTS 2.0 uses Volcengine Speaker IDs.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  _MobileSynthesisControls(
                    state: state,
                    controller: controller,
                    onSynthesize: onSynthesize,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (playerVisible)
          Positioned(
            left: MobileLayout.horizontalPadding,
            right: MobileLayout.horizontalPadding,
            bottom: effectivePlayerBottom,
            child: _MobilePlayerEntrance(
              child: _MobilePlayerDock(
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

class _MobileTextEditor extends StatelessWidget {
  const _MobileTextEditor({
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
        final count = value.text.characters.length;
        const limit = AppConstants.maxTtsCharacters;
        final nearLimit = count >= (limit * 0.9).ceil();
        return MobileSurfaceCard(
          key: const Key('mobileTtsInputCard'),
          padding: const EdgeInsets.fromLTRB(18, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('ttsTextField'),
                controller: controller,
                minLines: MediaQuery.sizeOf(context).height < 700 ? 5 : 7,
                maxLines: 14,
                maxLength: limit,
                readOnly: isGenerating,
                enableInteractiveSelection: true,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(0, 8, 6, 4),
                  hintText: context.l10n.text(
                    zh: '输入或粘贴要转换为语音的文字……',
                    en: 'Enter or paste the text to convert to speech…',
                  ),
                  counterText: '',
                ),
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xxs,
                children: [
                  Tooltip(
                    message: context.l10n.text(zh: '清空文字', en: 'Clear text'),
                    child: TextButton(
                      key: const Key('clearTtsTextButton'),
                      onPressed: value.text.isEmpty || isGenerating
                          ? null
                          : onClear,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(context.l10n.text(zh: '清空', en: 'Clear')),
                    ),
                  ),
                  Semantics(
                    label: context.l10n.text(
                      zh: '已输入 $count 个字符，共可输入 $limit 个字符',
                      en: '$count of $limit characters entered',
                    ),
                    child: ExcludeSemantics(
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => LinearGradient(
                          colors: nearLimit
                              ? [colors.error, colors.error]
                              : [
                                  colors.primary,
                                  context.semanticColors.success,
                                ],
                        ).createShader(bounds),
                        child: Text(
                          '$count / $limit',
                          key: const Key('ttsCharacterCount'),
                          style: AppTypography.numeric(
                            Theme.of(context).textTheme.bodySmall,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (isGenerating)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                  child: Text(
                    context.l10n.text(
                      zh: '正在合成，文字暂时只读；仍可选择并复制。',
                      en: 'Text is read-only while speech is generated; selection and copy remain available.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MobileVoiceList extends ConsumerStatefulWidget {
  const _MobileVoiceList({
    required this.state,
    required this.voices,
    required this.usesBytedanceSpeakerIds,
  });

  final TtsState state;
  final List<String> voices;
  final bool usesBytedanceSpeakerIds;

  @override
  ConsumerState<_MobileVoiceList> createState() => _MobileVoiceListState();
}

class _MobileVoiceListState extends ConsumerState<_MobileVoiceList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final voices = widget.voices;
    final usesBytedanceSpeakerIds = widget.usesBytedanceSpeakerIds;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.8;
    return Semantics(
      container: true,
      label: context.l10n.text(
        zh: '音色列表，可横向滑动',
        en: 'Voice list, scroll horizontally',
      ),
      child: SizedBox(
        height: largeText
            ? (usesBytedanceSpeakerIds ? 420 : 340)
            : (usesBytedanceSpeakerIds ? 168 : 160),
        child: Scrollbar(
          key: const Key('mobileTtsVoiceScrollbar'),
          controller: _scrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView.separated(
            key: const Key('mobileVoiceList'),
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            itemCount: voices.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final voice = voices[index];
              return _MobileVoiceCard(
                voice: voice,
                selected: voice == state.voice,
                enabled: !state.isGenerating,
                modelSpecific: usesBytedanceSpeakerIds,
                onTap: () => ref.read(ttsProvider.notifier).setVoice(voice),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MobileVoiceCard extends StatelessWidget {
  const _MobileVoiceCard({
    required this.voice,
    required this.selected,
    required this.enabled,
    required this.modelSpecific,
    required this.onTap,
  });

  final String voice;
  final bool selected;
  final bool enabled;
  final bool modelSpecific;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final metadata = _voiceMetadata(context, voice, modelSpecific);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.8;
    final preserveSpeakerId = largeText && modelSpecific;
    final card = Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label:
          '${metadata.name}, ${modelSpecific ? '$voice, ' : ''}${metadata.description}',
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.mobileCard),
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadii.mobileCard),
            child: AnimatedContainer(
              duration: MobileMotion.duration(context),
              width: largeText
                  ? (modelSpecific ? 248 : 196)
                  : (modelSpecific ? 220 : 168),
              constraints: const BoxConstraints(minHeight: 112),
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.mobileCard),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.10),
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          metadata.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: selected ? 1 : 0,
                        duration: MobileMotion.duration(context),
                        child: Icon(
                          Icons.check,
                          size: 14,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (modelSpecific) ...[
                    Text(
                      voice,
                      maxLines: preserveSpeakerId ? null : 2,
                      overflow: preserveSpeakerId
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontFamily: 'Cascadia Code',
                        fontFamilyFallback: const [
                          'JetBrains Mono',
                          'Consolas',
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    metadata.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final tag in metadata.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(
                              AppRadii.mobileBadge,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 10.5,
                                ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Tooltip(message: voice, child: card);
  }
}

class _MobileSynthesisControls extends ConsumerWidget {
  const _MobileSynthesisControls({
    required this.state,
    required this.controller,
    required this.onSynthesize,
  });

  final TtsState state;
  final TextEditingController controller;
  final VoidCallback onSynthesize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final speedText = '${_compactNumber(state.speed)}×';
        final estimate = _estimatedSeconds(value.text.length, state.speed);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileSurfaceCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              radius: AppRadii.mobileControl,
              shadow: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.text(zh: '合成语速', en: 'Synthesis speed'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      MobilePill(label: speedText),
                    ],
                  ),
                  Slider(
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
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
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
                  Text(context.l10n.text(zh: '生成语音', en: 'Generate speech')),
                  Text(context.l10n.text(zh: '正在合成…', en: 'Generating…')),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
              textAlign: TextAlign.center,
              style: AppTypography.numeric(
                Theme.of(context).textTheme.labelSmall,
              ).copyWith(color: colors.onSurfaceVariant, fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}

class _MobilePlayerEntrance extends StatelessWidget {
  const _MobilePlayerEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MobileMotion.duration(
        context,
        const Duration(milliseconds: 320),
      ),
      curve: MobileMotion.entranceCurve,
      child: child,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * 40),
          child: child,
        ),
      ),
    );
  }
}

class _MobilePlayerDock extends ConsumerWidget {
  const _MobilePlayerDock({
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
    final durationMilliseconds = math.max(state.duration.inMilliseconds, 1);
    final position = state.position.inMilliseconds.clamp(
      0,
      durationMilliseconds,
    );
    return MobileGlassSurface(
      key: const Key('mobileTtsPlayer'),
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.4;
          final playButton = IconButton.filled(
            tooltip: state.isPlaying
                ? context.l10n.text(zh: '暂停', en: 'Pause')
                : context.l10n.text(zh: '播放', en: 'Play'),
            onPressed: notifier.playOrPause,
            icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
          );
          final closeButton = IconButton(
            tooltip: context.l10n.text(zh: '关闭播放器', en: 'Close player'),
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 20),
          );
          final wave = _MobileWaveProgress(
            value: position.toDouble(),
            max: durationMilliseconds.toDouble(),
            onChanged: (value) =>
                notifier.seek(Duration(milliseconds: value.round())),
          );
          final time = Text(
            '${_durationWithTenths(state.position)} / ${_durationWithTenths(state.duration)}',
            maxLines: 1,
            style: AppTypography.numeric(
              Theme.of(context).textTheme.labelSmall,
            ).copyWith(color: colors.onSurfaceVariant, fontSize: 10.5),
          );
          final rateIndex = TtsNotifier.supportedPlaybackRates.indexWhere(
            (rate) => (rate - state.playbackRate).abs() < 0.001,
          );
          final nextRate = rateIndex < 0
              ? 1.0
              : TtsNotifier.supportedPlaybackRates[(rateIndex + 1) %
                    TtsNotifier.supportedPlaybackRates.length];
          final currentRateText = '${_compactNumber(state.playbackRate)}×';
          final nextRateText = '${_compactNumber(nextRate)}×';
          final playbackRate = Semantics(
            button: true,
            label: context.l10n.text(
              zh: '播放速度 $currentRateText',
              en: 'Playback speed $currentRateText',
            ),
            hint: context.l10n.text(
              zh: '激活后切换到 $nextRateText',
              en: 'Activate to switch to $nextRateText',
            ),
            onTap: notifier.cyclePlaybackRate,
            child: ExcludeSemantics(
              child: Tooltip(
                message: context.l10n.text(
                  zh: '播放速度 $currentRateText，点击切换到 $nextRateText',
                  en: 'Playback speed $currentRateText. Tap for $nextRateText',
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: const Key('ttsPlaybackRateButton'),
                      onTap: notifier.cyclePlaybackRate,
                      borderRadius: BorderRadius.circular(999),
                      child: Center(child: MobilePill(label: currentRateText)),
                    ),
                  ),
                ),
              ),
            ),
          );
          final saveButton = IconButton(
            tooltip: context.l10n.text(zh: '保存 MP3', en: 'Save MP3'),
            onPressed: onSave,
            icon: const Icon(Icons.download_outlined, size: 20),
          );
          final volume = Row(
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
                  semanticFormatterCallback: (volume) => context.l10n.text(
                    zh: '音量 ${(volume * 100).round()}%',
                    en: 'Volume ${(volume * 100).round()}%',
                  ),
                  onChanged: notifier.setVolume,
                ),
              ),
            ],
          );

          if (stacked) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    playButton,
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: wave),
                    closeButton,
                  ],
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [time, playbackRate, saveButton],
                ),
                volume,
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  playButton,
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: wave),
                  const SizedBox(width: AppSpacing.xs),
                  time,
                  const SizedBox(width: AppSpacing.xs),
                  playbackRate,
                  closeButton,
                ],
              ),
              Row(
                children: [
                  Expanded(child: volume),
                  saveButton,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MobileWaveProgress extends StatelessWidget {
  const _MobileWaveProgress({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalizedMax = math.max(max, 1).toDouble();
    final normalizedValue = value.clamp(0, normalizedMax).toDouble();
    final ratio = normalizedValue / normalizedMax;
    return Semantics(
      slider: true,
      label: context.l10n.text(zh: '播放进度', en: 'Playback position'),
      value: _duration(Duration(milliseconds: normalizedValue.round())),
      child: SizedBox(
        key: const Key('ttsWaveProgressHitTarget'),
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var index = 0; index < 20; index++)
                    Container(
                      width: 3,
                      height: 8 + ((index * 11) % 21).toDouble(),
                      decoration: BoxDecoration(
                        color: index / 20 <= ratio
                            ? colors.primary
                            : Color.lerp(
                                colors.outlineVariant,
                                colors.primary,
                                0.45,
                              ),
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
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: normalizedValue,
                min: 0,
                max: normalizedMax,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

_MobileVoiceMetadata _voiceMetadata(
  BuildContext context,
  String voice,
  bool modelSpecific,
) {
  final l10n = context.l10n;
  final volcengineVoice = VolcengineTtsVoiceCatalog.findBySpeakerId(voice);
  if (volcengineVoice != null) {
    return _MobileVoiceMetadata(
      name: volcengineVoice.displayName,
      description: volcengineVoice.language,
      tags: [volcengineVoice.scenario],
    );
  }
  return switch (voice.toLowerCase()) {
    'alloy' => _MobileVoiceMetadata(
      name: 'Alloy',
      description: l10n.text(zh: '中性 · 通用', en: 'Neutral · versatile'),
      tags: [
        l10n.text(zh: '通用', en: 'General'),
        l10n.text(zh: '助手', en: 'Assistant'),
      ],
    ),
    'echo' => _MobileVoiceMetadata(
      name: 'Echo',
      description: l10n.text(zh: '男声 · 旁白', en: 'Masculine · narration'),
      tags: [
        l10n.text(zh: '旁白', en: 'Narration'),
        l10n.text(zh: '纪实', en: 'Documentary'),
      ],
    ),
    'fable' => _MobileVoiceMetadata(
      name: 'Fable',
      description: l10n.text(zh: '叙事 · 故事', en: 'Expressive · storytelling'),
      tags: [
        l10n.text(zh: '有声书', en: 'Audiobook'),
        l10n.text(zh: '故事', en: 'Story'),
      ],
    ),
    'onyx' => _MobileVoiceMetadata(
      name: 'Onyx',
      description: l10n.text(zh: '男声 · 沉稳', en: 'Deep · composed'),
      tags: [
        l10n.text(zh: '新闻', en: 'News'),
        l10n.text(zh: '播报', en: 'Broadcast'),
      ],
    ),
    'nova' => _MobileVoiceMetadata(
      name: 'Nova',
      description: l10n.text(zh: '女声 · 清亮', en: 'Bright · clear'),
      tags: [
        l10n.text(zh: '课程', en: 'Course'),
        l10n.text(zh: '导学', en: 'Guide'),
      ],
    ),
    'shimmer' => _MobileVoiceMetadata(
      name: 'Shimmer',
      description: l10n.text(zh: '女声 · 轻柔', en: 'Soft · calm'),
      tags: [
        l10n.text(zh: '冥想', en: 'Meditation'),
        l10n.text(zh: '耳语', en: 'Whisper'),
      ],
    ),
    _ => _MobileVoiceMetadata(
      name: voice,
      description: modelSpecific
          ? l10n.text(zh: '模型专属 Speaker ID', en: 'Model-specific Speaker ID')
          : l10n.text(zh: '模型提供的音色', en: 'Voice provided by the model'),
      tags: [l10n.text(zh: '在线', en: 'Online')],
    ),
  };
}

class _MobileVoiceMetadata {
  const _MobileVoiceMetadata({
    required this.name,
    required this.description,
    required this.tags,
  });

  final String name;
  final String description;
  final List<String> tags;
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

String _durationWithTenths(Duration duration) {
  final tenths = (duration.inMilliseconds.remainder(1000) ~/ 100).toString();
  return '${_duration(duration)}.$tenths';
}
