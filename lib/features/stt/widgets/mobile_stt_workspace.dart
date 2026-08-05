import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/transcript_exporter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_status_banner.dart';
import '../../../widgets/mobile_design.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/widgets/speech_model_selector.dart';
import '../models/stt_state.dart';
import '../models/transcription_result.dart';
import '../providers/stt_provider.dart';
import '../services/seed_asr_api_service.dart';

enum _TranscriptView { text, srt }

/// Android-only speech-to-text workspace based on the mobile handoff.
///
/// Recording, persistence and export remain owned by the existing providers;
/// this widget is intentionally presentation-only.
class MobileSttWorkspace extends ConsumerStatefulWidget {
  const MobileSttWorkspace({
    required this.state,
    required this.controller,
    required this.onExport,
    required this.onNewTranscript,
    super.key,
  });

  final SttState state;
  final TextEditingController controller;
  final Future<void> Function({required bool isSrt}) onExport;
  final Future<void> Function() onNewTranscript;

  @override
  ConsumerState<MobileSttWorkspace> createState() => _MobileSttWorkspaceState();
}

class _MobileSttWorkspaceState extends ConsumerState<MobileSttWorkspace> {
  _TranscriptView _view = _TranscriptView.text;

  @override
  void didUpdateWidget(covariant MobileSttWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.state.canExportSrt && _view == _TranscriptView.srt) {
      _view = _TranscriptView.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = widget.state.errorMessageFor(
      Localizations.localeOf(context),
    );
    final modelEnabled =
        !widget.state.hasActiveRecordingSession && !widget.state.isProcessing;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        key: const Key('mobileSttScrollView'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: MobileLayout.pagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MobileViewHeader(
                  eyebrow: context.l10n.text(
                    zh: 'SPEECH TO TEXT · 实时转写',
                    en: 'SPEECH TO TEXT · LIVE TRANSCRIPTION',
                  ),
                  title: context.l10n.text(
                    zh: '语音转文字',
                    en: 'Speech to text',
                  ),
                  accessories: [
                    MobilePill(
                      icon: Icons.language,
                      label: context.l10n.text(
                        zh: '自动识别',
                        en: 'Auto detect',
                      ),
                    ),
                    SpeechModelSelector(
                      kind: SpeechModelKind.stt,
                      enabled: modelEnabled,
                    ),
                  ],
                ),
                if (errorMessage != null) ...[
                  AppStatusBanner(
                    kind: AppStatusKind.error,
                    title: context.l10n.text(
                      zh: '转录未完成',
                      en: 'Transcription not completed',
                    ),
                    message: errorMessage,
                    action: _RecoveryActions(
                      state: widget.state,
                      onNewTranscript: widget.onNewTranscript,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _MobileRecorderCard(
                  state: widget.state,
                  onNewTranscript: widget.onNewTranscript,
                ),
                const SizedBox(height: AppSpacing.md),
                _MobileTranscriptCard(
                  state: widget.state,
                  controller: widget.controller,
                  view: _view,
                  onViewChanged: (view) => setState(() => _view = view),
                  onCopy: _copy,
                  onExport: widget.onExport,
                  onNewTranscript: widget.onNewTranscript,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copy() async {
    final result = widget.state.result;
    if (result == null) {
      return;
    }
    final contents = _view == _TranscriptView.srt
        ? TranscriptExporter.toSrt(result)
        : TranscriptExporter.toText(widget.state.editedText);
    await Clipboard.setData(ClipboardData(text: contents));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _view == _TranscriptView.srt
              ? context.l10n.text(
                  zh: 'SRT 内容已复制。',
                  en: 'SRT transcript copied.',
                )
              : context.l10n.text(
                  zh: '转录内容已复制。',
                  en: 'Transcript copied.',
                ),
        ),
      ),
    );
  }
}

class _RecoveryActions extends ConsumerWidget {
  const _RecoveryActions({
    required this.state,
    required this.onNewTranscript,
  });

  final SttState state;
  final Future<void> Function() onNewTranscript;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!state.canRetrySelectedSource) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.end,
      children: [
        TextButton.icon(
          key: const Key('retrySelectedSttSourceButton'),
          onPressed: ref.read(sttProvider.notifier).retrySelectedSource,
          icon: const Icon(Icons.refresh),
          label: Text(
            state.selectedSourceIsTemporaryRecording
                ? context.l10n.text(
                    zh: '重试此录音',
                    en: 'Retry this recording',
                  )
                : context.l10n.text(
                    zh: '重试此文件',
                    en: 'Retry this file',
                  ),
          ),
        ),
        if (state.hasRetainedTemporaryRecording)
          TextButton.icon(
            key: const Key('mobileDiscardFailedRecordingButton'),
            onPressed: onNewTranscript,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(
              context.l10n.text(
                zh: '放弃并新建',
                en: 'Discard and start new',
              ),
            ),
          ),
      ],
    );
  }
}

class _MobileRecorderCard extends ConsumerWidget {
  const _MobileRecorderCard({
    required this.state,
    required this.onNewTranscript,
  });

  final SttState state;
  final Future<void> Function() onNewTranscript;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sttProvider.notifier);
    final primaryAction = _primaryAction(notifier);
    final status = _recordingStatus(context, state);
    final semantics = context.semanticColors;
    final active = state.phase == SttPhase.recording;

    return MobileSurfaceCard(
      key: const Key('mobileSttRecorderCard'),
      radius: AppRadii.mobileHero,
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _RecorderButton(
              state: state,
              onPressed: primaryAction,
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            label: context.l10n.text(
              zh: '录音时长 ${_spokenDuration(context, state.elapsed)}',
              en: 'Recording duration ${_spokenDuration(context, state.elapsed)}',
            ),
            child: ExcludeSemantics(
              child: Text(
                _timer(state.elapsed),
                key: const Key('mobileSttTimer'),
                textAlign: TextAlign.center,
                style: AppTypography.numeric(
                  Theme.of(context).textTheme.headlineMedium,
                ).copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  color: state.phase == SttPhase.recording ||
                          state.phase == SttPhase.paused
                      ? semantics.success
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            label: status,
            child: ExcludeSemantics(
              child: Text(
                status,
                key: const Key('mobileSttStatus'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: MobileMotion.duration(context),
            child: active
                ? Padding(
                    key: const ValueKey('recordingWave'),
                    padding: const EdgeInsets.only(top: 14),
                    child: Center(
                      child: _LiveWave(color: semantics.success),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('noRecordingWave')),
          ),
          if (state.phase == SttPhase.recording ||
              state.phase == SttPhase.paused) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (state.phase == SttPhase.recording)
                  TextButton.icon(
                    onPressed: notifier.pauseRecording,
                    icon: const Icon(Icons.pause),
                    label: Text(
                      context.l10n.text(zh: '暂停', en: 'Pause'),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: notifier.resumeRecording,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      context.l10n.text(zh: '继续', en: 'Resume'),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    await notifier.cancelRecording();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    context.l10n.text(zh: '放弃录音', en: 'Discard'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _UploadZone(state: state),
          if (state.isProcessing) ...[
            const SizedBox(height: AppSpacing.md),
            _ProcessingStatus(state: state),
          ],
        ],
      ),
    );
  }

  VoidCallback? _primaryAction(SttNotifier notifier) {
    switch (state.phase) {
      case SttPhase.countdown:
        return () async {
          await notifier.cancelRecording();
        };
      case SttPhase.recording:
      case SttPhase.paused:
        return () {
          unawaited(notifier.stopRecording());
        };
      case SttPhase.uploading:
      case SttPhase.transcribing:
        return null;
      case SttPhase.success:
        return () {
          unawaited(onNewTranscript());
        };
      case SttPhase.failure:
        if (state.canRetrySelectedSource) {
          return () {
            unawaited(notifier.retrySelectedSource());
          };
        }
        if (state.canStart) {
          return () {
            unawaited(notifier.startRecording());
          };
        }
        return null;
      case SttPhase.idle:
        return state.canStart
            ? () {
                unawaited(notifier.startRecording());
              }
            : null;
    }
  }
}

class _RecorderButton extends StatefulWidget {
  const _RecorderButton({required this.state, required this.onPressed});

  final SttState state;
  final VoidCallback? onPressed;

  @override
  State<_RecorderButton> createState() => _RecorderButtonState();
}

class _RecorderButtonState extends State<_RecorderButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _auraController;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAura();
  }

  @override
  void didUpdateWidget(covariant _RecorderButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAura();
  }

  @override
  void dispose() {
    _auraController.dispose();
    super.dispose();
  }

  void _syncAura() {
    final animate = widget.state.phase == SttPhase.recording &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_auraController.isAnimating) {
      _auraController.repeat();
    } else if (!animate && _auraController.isAnimating) {
      _auraController.stop();
      _auraController.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semanticColors = context.semanticColors;
    final isActive = widget.state.phase == SttPhase.recording ||
        widget.state.phase == SttPhase.paused;
    final isFailure = widget.state.phase == SttPhase.failure;
    final foreground = isFailure
        ? colors.error
        : isActive
            ? semanticColors.success
            : colors.primary;
    final background = isFailure
        ? colors.errorContainer
        : isActive
            ? semanticColors.successContainer
            : colors.surfaceContainerLowest;
    final border = isFailure
        ? colors.error.withValues(alpha: 0.42)
        : isActive
            ? semanticColors.success.withValues(alpha: 0.42)
            : colors.outlineVariant;

    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: _recordButtonLabel(context, widget.state),
      value: _recordingStatus(context, widget.state),
      child: SizedBox.square(
        dimension: 152,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (widget.state.phase == SttPhase.recording)
              AnimatedBuilder(
                animation: _auraController,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    _AuraRing(
                      progress: _auraController.value,
                      color: semanticColors.success,
                    ),
                    _AuraRing(
                      progress: (_auraController.value + 0.5) % 1,
                      color: semanticColors.success,
                    ),
                  ],
                ),
              ),
            AnimatedContainer(
              key: const Key('startRecordingButton'),
              duration: MobileMotion.duration(context),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: _focused ? semanticColors.focus : border,
                  width: _focused ? 2 : 1,
                ),
                boxShadow: [context.surfaceEffects.cardShadow],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(36),
                child: InkWell(
                  onTap: widget.onPressed,
                  onFocusChange: (focused) {
                    if (_focused != focused) {
                      setState(() => _focused = focused);
                    }
                  },
                  borderRadius: BorderRadius.circular(36),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: MobileDashedOutline(
                      radius: 28,
                      color: border,
                      padding: EdgeInsets.zero,
                      child: Center(
                        child: _RecorderGlyph(
                          state: widget.state,
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuraRing extends StatelessWidget {
  const _AuraRing({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final value = reduced ? 0.15 : progress;
    return Opacity(
      opacity: (0.5 * (1 - value)).clamp(0, 0.5),
      child: Transform.scale(
        scale: 0.84 + (0.4 * value),
        child: Container(
          width: 136,
          height: 136,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(46),
            border: Border.all(color: color, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _RecorderGlyph extends StatelessWidget {
  const _RecorderGlyph({required this.state, required this.color});

  final SttState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return switch (state.phase) {
      SttPhase.countdown => Text(
          '${state.countdown}',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      SttPhase.paused => Icon(Icons.pause_rounded, color: color, size: 42),
      SttPhase.uploading =>
        Icon(Icons.cloud_upload_outlined, color: color, size: 40),
      SttPhase.transcribing => SizedBox.square(
          dimension: 34,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
        ),
      SttPhase.success => Icon(Icons.check_rounded, color: color, size: 42),
      SttPhase.failure => Icon(Icons.error_outline, color: color, size: 40),
      _ => Icon(Icons.mic_none_rounded, color: color, size: 42),
    };
  }
}

class _LiveWave extends StatefulWidget {
  const _LiveWave({required this.color});

  final Color color;

  @override
  State<_LiveWave> createState() => _LiveWaveState();
}

class _LiveWaveState extends State<_LiveWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const _heights = <double>[
    0.38,
    0.55,
    0.72,
    0.50,
    0.88,
    0.64,
    0.42,
    0.76,
    0.95,
    0.58,
    0.46,
    0.70,
    0.84,
    0.52,
    0.36,
    0.62,
    0.90,
    0.68,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 24,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var index = 0; index < _heights.length; index++) ...[
                Container(
                  width: 3,
                  height: 24 *
                      _heights[index] *
                      (0.42 + 0.58 * ((_controller.value + index * 0.13) % 1)),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (index != _heights.length - 1) const SizedBox(width: 3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadZone extends ConsumerStatefulWidget {
  const _UploadZone({required this.state});

  final SttState state;

  @override
  ConsumerState<_UploadZone> createState() => _UploadZoneState();
}

class _UploadZoneState extends ConsumerState<_UploadZone> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = widget.state;
    final path = state.selectedFilePath;
    final fileName = path == null ? null : File(path).uri.pathSegments.last;
    final seedAsrSelected = SeedAsrApiService.supportsModel(
      ref.watch(settingsProvider).sttModel,
    );
    final enabled = state.canStart;
    final label = fileName ??
        context.l10n.text(
          zh: '上传音频或视频文件转写',
          en: 'Choose file',
        );
    final detail = seedAsrSelected
        ? context.l10n.text(
            zh: 'MP3 / MP4 / MPEG / MPGA / M4A / WAV / WEBM · SeedASR 自动转换 · 最大 25 MB',
            en: 'MP3 / MP4 / MPEG / MPGA / M4A / WAV / WEBM · auto-converted for SeedASR · 25 MB max',
          )
        : context.l10n.text(
            zh: 'MP3 / MP4 / MPEG / M4A / WAV / WEBM · 最大 25 MB',
            en: 'MP3 / MP4 / MPEG / M4A / WAV / WEBM · 25 MB max',
          );

    return Semantics(
      key: const Key('mobileSttUploadZone'),
      button: true,
      enabled: enabled,
      label: label,
      hint: detail,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.mobileControl),
        child: InkWell(
          onTap: enabled
              ? () {
                  unawaited(
                    ref.read(sttProvider.notifier).pickAndTranscribe(
                          dialogTitle: context.l10n.text(
                            zh: '选择音频或视频文件',
                            en: 'Choose an audio or video file',
                          ),
                        ),
                  );
                }
              : null,
          onFocusChange: (focused) {
            if (_focused != focused) {
              setState(() => _focused = focused);
            }
          },
          borderRadius: BorderRadius.circular(AppRadii.mobileControl),
          child: MobileDashedOutline(
            color: _focused && enabled
                ? context.semanticColors.focus
                : enabled
                    ? colors.outlineVariant
                    : colors.outlineVariant.withValues(alpha: 0.55),
            strokeWidth: _focused && enabled ? 2 : 1.5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  fileName == null
                      ? Icons.upload_file_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 18,
                  color: enabled
                      ? colors.onSurfaceVariant
                      : colors.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: enabled
                                  ? colors.onSurfaceVariant
                                  : colors.onSurfaceVariant
                                      .withValues(alpha: 0.55),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant
                                  .withValues(alpha: 0.78),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final hasProgress = uploading && progress > 0;
    final percent = (progress * 100).round();
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
          message: hasProgress
              ? context.l10n.text(
                  zh: '已上传 $percent%',
                  en: '$percent% uploaded',
                )
              : context.l10n.text(
                  zh: '正在准备结果，请稍候。',
                  en: 'Preparing the result. Please wait.',
                ),
        ),
        const SizedBox(height: AppSpacing.xs),
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
          value: hasProgress
              ? '$percent%'
              : context.l10n.text(zh: '处理中', en: 'Processing'),
          child: LinearProgressIndicator(value: hasProgress ? progress : null),
        ),
      ],
    );
  }
}

class _MobileTranscriptCard extends ConsumerWidget {
  const _MobileTranscriptCard({
    required this.state,
    required this.controller,
    required this.view,
    required this.onViewChanged,
    required this.onCopy,
    required this.onExport,
    required this.onNewTranscript,
  });

  final SttState state;
  final TextEditingController controller;
  final _TranscriptView view;
  final ValueChanged<_TranscriptView> onViewChanged;
  final Future<void> Function() onCopy;
  final Future<void> Function({required bool isSrt}) onExport;
  final Future<void> Function() onNewTranscript;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final result = state.result;
    final segmentCount = result?.segments.length ?? 0;
    final duration = result?.duration ?? state.elapsed;
    final meta = result == null
        ? context.l10n.text(zh: '等待录音', en: 'Waiting for audio')
        : context.l10n.text(
            zh: '$segmentCount 段 · ${_duration(duration)}',
            en: '$segmentCount ${segmentCount == 1 ? 'segment' : 'segments'} · ${_duration(duration)}',
          );

    return MobileSurfaceCard(
      key: const Key('mobileSttTranscriptCard'),
      radius: AppRadii.mobileCard,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 1.4;
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.text(zh: '转录结果', en: 'Transcript'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: AppTypography.numeric(
                        Theme.of(context).textTheme.labelSmall,
                      ).copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                );
                final toolbar = _TranscriptToolbar(
                  state: state,
                  view: view,
                  onViewChanged: onViewChanged,
                  onCopy: onCopy,
                  onExport: onExport,
                  onNewTranscript: onNewTranscript,
                );
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: toolbar,
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: AppSpacing.sm),
                    toolbar,
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          if (result == null)
            const _TranscriptSkeleton()
          else ...[
            if (result.hasSegments)
              _SegmentTimeline(
                segments: result.segments,
                srt: view == _TranscriptView.srt,
              )
            else
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SelectableText(
                  state.editedText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.65,
                      ),
                ),
              ),
            Divider(height: 1, color: colors.outlineVariant),
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                key: const Key('mobileTranscriptEditorExpander'),
                maintainState: true,
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xxs,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                title: Text(
                  context.l10n.text(
                    zh: '编辑全文',
                    en: 'Edit full transcript',
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  context.l10n.text(
                    zh: '修改全文不会改变原始音频或 SRT 时间轴。',
                    en: 'Edits do not change the source audio or SRT timeline.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
                children: [
                  TextField(
                    key: const Key('transcriptionEditor'),
                    controller: controller,
                    minLines: 6,
                    maxLines: 14,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: ref.read(sttProvider.notifier).updateEditedText,
                    decoration: InputDecoration(
                      labelText: context.l10n.text(
                        zh: '可编辑全文',
                        en: 'Editable transcript',
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            if (!state.canExportSrt)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: AppStatusBanner(
                  kind: AppStatusKind.info,
                  message: context.l10n.text(
                    zh: '当前服务未返回时间戳片段，无法导出 SRT。',
                    en: 'The service did not return timestamped segments, so SRT export is unavailable.',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TranscriptToolbar extends StatelessWidget {
  const _TranscriptToolbar({
    required this.state,
    required this.view,
    required this.onViewChanged,
    required this.onCopy,
    required this.onExport,
    required this.onNewTranscript,
  });

  final SttState state;
  final _TranscriptView view;
  final ValueChanged<_TranscriptView> onViewChanged;
  final Future<void> Function() onCopy;
  final Future<void> Function({required bool isSrt}) onExport;
  final Future<void> Function() onNewTranscript;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<_TranscriptView>(
          key: const Key('mobileSttFormatSelector'),
          segments: [
            const ButtonSegment(
              value: _TranscriptView.text,
              label: Text('TXT'),
            ),
            ButtonSegment(
              value: _TranscriptView.srt,
              label: const Text('SRT'),
              enabled: state.canExportSrt,
            ),
          ],
          selected: {view},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              onViewChanged(selection.single);
            }
          },
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 48)),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
        IconButton(
          key: const Key('mobileSttCopyButton'),
          tooltip: context.l10n.text(zh: '复制全文', en: 'Copy transcript'),
          onPressed: state.canExport ? onCopy : null,
          icon: const Icon(Icons.copy_all_outlined, size: 19),
        ),
        IconButton(
          key: const Key('mobileSttExportButton'),
          tooltip: view == _TranscriptView.srt
              ? context.l10n.text(zh: '导出 SRT', en: 'Export SRT')
              : context.l10n.text(zh: '导出 TXT', en: 'Export TXT'),
          onPressed: view == _TranscriptView.srt
              ? (state.canExportSrt ? () => onExport(isSrt: true) : null)
              : (state.canExport ? () => onExport(isSrt: false) : null),
          icon: const Icon(Icons.download_outlined, size: 20),
        ),
        if (state.result != null)
          IconButton(
            key: const Key('mobileSttNewTranscriptButton'),
            tooltip: context.l10n.text(zh: '新建转录', en: 'New transcript'),
            onPressed: onNewTranscript,
            icon: const Icon(Icons.add_circle_outline, size: 20),
          ),
      ],
    );
  }
}

class _TranscriptSkeleton extends StatelessWidget {
  const _TranscriptSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.text(
        zh: '等待转录结果',
        en: 'Waiting for transcript results',
      ),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Opacity(
            opacity: 0.5,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.mobileControl),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  const _SkeletonRow(
                    time: '00:00.00 → 00:03.84',
                    widthFactor: 0.86,
                  ),
                  const _SkeletonRow(
                    time: '00:03.84 → 00:08.21',
                    widthFactor: 0.62,
                  ),
                  const _SkeletonRow(
                    time: '00:08.21 → 00:12.47',
                    widthFactor: 0.74,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.l10n.text(
                      zh: '完成一次录音后，带时间轴的转录片段会显示在这里',
                      en: 'Timestamped transcript segments will appear here after recording.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.time, required this.widthFactor});

  final String time;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final timeLabel = Text(
      time,
      style: AppTypography.numeric(
        Theme.of(context).textTheme.labelSmall,
      ).copyWith(color: colors.onSurfaceVariant, fontSize: 10.5),
    );
    final bar = FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.4;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                timeLabel,
                const SizedBox(height: AppSpacing.xs),
                bar,
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 126, child: timeLabel),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: bar),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentTimeline extends StatelessWidget {
  const _SegmentTimeline({required this.segments, required this.srt});

  final List<TranscriptionSegment> segments;
  final bool srt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Column(
        children: [
          for (var index = 0; index < segments.length; index++) ...[
            if (index > 0) Divider(height: 1, color: colors.outlineVariant),
            _SegmentRow(
              index: index,
              segment: segments[index],
              srt: srt,
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    required this.index,
    required this.segment,
    required this.srt,
  });

  final int index;
  final TranscriptionSegment segment;
  final bool srt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = srt
        ? '${index + 1}\n${_srtTimestamp(segment.start)}\n→ ${_srtTimestamp(segment.end)}'
        : '${_clockTimestamp(segment.start)} → ${_clockTimestamp(segment.end)}';
    final timeLabel = Text(
      time,
      style: AppTypography.numeric(
        Theme.of(context).textTheme.labelSmall,
      ).copyWith(
        color: colors.onSurfaceVariant,
        fontSize: 10.5,
        height: 1.45,
      ),
    );
    final content = Text(
      segment.text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.65),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 380 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.4;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                timeLabel,
                const SizedBox(height: AppSpacing.xs),
                content,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: srt ? 144 : 126, child: timeLabel),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

String _recordButtonLabel(BuildContext context, SttState state) {
  return switch (state.phase) {
    SttPhase.countdown => context.l10n.text(
        zh: '取消录音倒计时',
        en: 'Cancel recording countdown',
      ),
    SttPhase.recording || SttPhase.paused => context.l10n.text(
        zh: '停止录音并转录',
        en: 'Stop and transcribe',
      ),
    SttPhase.uploading || SttPhase.transcribing => context.l10n.text(
        zh: '正在处理，录音按钮不可用',
        en: 'Processing; recording button unavailable',
      ),
    SttPhase.success => context.l10n.text(
        zh: '新建转录',
        en: 'New transcript',
      ),
    SttPhase.failure when state.canRetrySelectedSource => context.l10n.text(
        zh: '重试当前来源',
        en: 'Retry current source',
      ),
    _ => context.l10n.text(zh: '开始录音', en: 'Start recording'),
  };
}

String _recordingStatus(BuildContext context, SttState state) {
  return switch (state.phase) {
    SttPhase.countdown => context.l10n.text(
        zh: '准备录音 · 点按取消',
        en: 'Preparing to record · tap to cancel',
      ),
    SttPhase.recording => context.l10n.text(
        zh: '正在录音 · 点按停止',
        en: 'Recording · tap to stop',
      ),
    SttPhase.paused => context.l10n.text(
        zh: '录音已暂停 · 点按完成',
        en: 'Recording paused · tap to finish',
      ),
    SttPhase.uploading => context.l10n.text(
        zh: '正在上传音频',
        en: 'Uploading audio',
      ),
    SttPhase.transcribing => context.l10n.text(
        zh: '正在整理转录结果',
        en: 'Preparing transcript',
      ),
    SttPhase.success => context.l10n.text(
        zh: '转录已完成 · 可在下方校对',
        en: 'Transcription complete · review below',
      ),
    SttPhase.failure => context.l10n.text(
        zh: '转录未完成 · 可重试或重新开始',
        en: 'Transcription incomplete · retry or start again',
      ),
    SttPhase.idle => context.l10n.text(
        zh: '点按开始录音',
        en: 'Start recording',
      ),
  };
}

String _timer(Duration duration) {
  return _clockTimestamp(duration);
}

String _duration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String _clockTimestamp(Duration duration) {
  final totalMilliseconds = duration.inMilliseconds.clamp(0, 359999999);
  final minutes = totalMilliseconds ~/ Duration.millisecondsPerMinute;
  final seconds = (totalMilliseconds % Duration.millisecondsPerMinute) ~/
      Duration.millisecondsPerSecond;
  final centiseconds =
      (totalMilliseconds % Duration.millisecondsPerSecond) ~/ 10;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${centiseconds.toString().padLeft(2, '0')}';
}

String _srtTimestamp(Duration duration) {
  final totalMilliseconds = duration.inMilliseconds.clamp(0, 359999999);
  final hours = totalMilliseconds ~/ Duration.millisecondsPerHour;
  final minutes = (totalMilliseconds % Duration.millisecondsPerHour) ~/
      Duration.millisecondsPerMinute;
  final seconds = (totalMilliseconds % Duration.millisecondsPerMinute) ~/
      Duration.millisecondsPerSecond;
  final milliseconds = totalMilliseconds % Duration.millisecondsPerSecond;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')},'
      '${milliseconds.toString().padLeft(3, '0')}';
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
