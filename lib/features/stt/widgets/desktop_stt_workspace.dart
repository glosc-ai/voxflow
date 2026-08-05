import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/transcript_exporter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_status_banner.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/widgets/speech_model_selector.dart';
import '../models/stt_state.dart';
import '../models/transcription_result.dart';
import '../providers/stt_provider.dart';
import '../services/seed_asr_api_service.dart';

enum _TranscriptView { text, srt }

class DesktopSttWorkspace extends ConsumerStatefulWidget {
  const DesktopSttWorkspace({
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
  ConsumerState<DesktopSttWorkspace> createState() =>
      _DesktopSttWorkspaceState();
}

class _DesktopSttWorkspaceState extends ConsumerState<DesktopSttWorkspace> {
  _TranscriptView _transcriptView = _TranscriptView.text;

  @override
  void didUpdateWidget(covariant DesktopSttWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.state.canExportSrt && _transcriptView == _TranscriptView.srt) {
      _transcriptView = _TranscriptView.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = widget.state.errorMessageFor(
      Localizations.localeOf(context),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        120,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (errorMessage != null) ...[
                AppStatusBanner(
                  kind: AppStatusKind.error,
                  title: context.l10n.text(
                    zh: '转录未完成',
                    en: 'Transcription not completed',
                  ),
                  message: errorMessage,
                  action: widget.state.canRetrySelectedSource
                      ? Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            TextButton.icon(
                              key: const Key('retrySelectedSttSourceButton'),
                              onPressed: ref
                                  .read(sttProvider.notifier)
                                  .retrySelectedSource,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                widget.state.selectedSourceIsTemporaryRecording
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
                            if (widget.state.hasRetainedTemporaryRecording)
                              TextButton.icon(
                                onPressed: widget.onNewTranscript,
                                icon: const Icon(Icons.add_circle_outline),
                                label: Text(
                                  context.l10n.text(
                                    zh: '放弃并新建',
                                    en: 'Discard and start new',
                                  ),
                                ),
                              ),
                          ],
                        )
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _DesktopPageHeader(state: widget.state),
              const SizedBox(height: AppSpacing.xl),
              _DesktopRecorderCard(
                state: widget.state,
                onNewTranscript: widget.onNewTranscript,
              ),
              const SizedBox(height: AppSpacing.lg),
              _DesktopTranscriptCard(
                state: widget.state,
                controller: widget.controller,
                view: _transcriptView,
                onViewChanged: (view) {
                  setState(() => _transcriptView = view);
                },
                onCopy: _copy,
                onExport: widget.onExport,
                onNewTranscript: widget.onNewTranscript,
              ),
            ],
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
    final text = _transcriptView == _TranscriptView.srt
        ? TranscriptExporter.toSrt(result)
        : widget.state.editedText;
    if (text.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.text(zh: '转录内容已复制。', en: 'Transcript copied.'),
          ),
        ),
      );
    }
  }
}

class _DesktopPageHeader extends StatelessWidget {
  const _DesktopPageHeader({required this.state});

  final SttState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.text(
            zh: 'SPEECH TO TEXT · 实时转写',
            en: 'SPEECH TO TEXT · TRANSCRIPTION',
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
          context.l10n.text(zh: '语音转文字', en: 'Speech to text'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
    final controls = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LanguagePill(
          label: context.l10n.text(zh: '中文 · 普通话', en: 'Auto language'),
        ),
        SpeechModelSelector(
          key: const Key('desktopSttModelSelector'),
          kind: SpeechModelKind.stt,
          enabled: !state.hasActiveRecordingSession && !state.isProcessing,
        ),
      ],
    );
    final rightAlignedControls = Align(
      alignment: Alignment.centerRight,
      child: controls,
    );

    if (textScale >= 1.6) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: AppSpacing.md),
          rightAlignedControls,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: header),
        const SizedBox(width: AppSpacing.md),
        Flexible(child: rightAlignedControls),
      ],
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.language, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontFamily: 'Cascadia Code',
              fontFamilyFallback: const ['JetBrains Mono', 'Consolas'],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopRecorderCard extends ConsumerWidget {
  const _DesktopRecorderCard({
    required this.state,
    required this.onNewTranscript,
  });

  final SttState state;
  final Future<void> Function() onNewTranscript;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final notifier = ref.read(sttProvider.notifier);
    final isRecording = state.phase == SttPhase.recording;
    final status = _recordingStatus(context, state);
    final hasCompletedResult = state.result != null;

    return _DesktopSurface(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(32, 38, 32, 32),
      child: Column(
        children: [
          _DesktopRecordButton(
            state: state,
            onPressed: switch (state.phase) {
              SttPhase.countdown => notifier.cancelRecording,
              SttPhase.recording || SttPhase.paused => notifier.stopRecording,
              _ when state.canStart => notifier.startRecording,
              _ when hasCompletedResult => onNewTranscript,
              _ => null,
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            liveRegion: true,
            label: context.l10n.text(
              zh: '录音时长 ${_spokenDuration(context, state.elapsed)}',
              en: 'Recording duration ${_spokenDuration(context, state.elapsed)}',
            ),
            child: ExcludeSemantics(
              child: Text(
                _duration(state.elapsed),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: isRecording ? colors.tertiary : colors.onSurface,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Cascadia Code',
                  fontFamilyFallback: const ['JetBrains Mono', 'Consolas'],
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasCompletedResult
                ? context.l10n.text(
                    zh: '转录已完成，可在下方校对结果',
                    en: 'Transcription complete. Review the result below.',
                  )
                : status,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          _LiveWave(active: isRecording),
          const SizedBox(height: AppSpacing.sm),
          if (state.phase == SttPhase.recording ||
              state.phase == SttPhase.paused)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (state.phase == SttPhase.recording)
                  TextButton.icon(
                    onPressed: notifier.pauseRecording,
                    icon: const Icon(Icons.pause, size: 17),
                    label: Text(context.l10n.text(zh: '暂停', en: 'Pause')),
                  )
                else
                  TextButton.icon(
                    onPressed: notifier.resumeRecording,
                    icon: const Icon(Icons.play_arrow, size: 17),
                    label: Text(context.l10n.text(zh: '继续', en: 'Resume')),
                  ),
                TextButton.icon(
                  onPressed: notifier.cancelRecording,
                  icon: const Icon(Icons.close, size: 17),
                  label: Text(context.l10n.text(zh: '放弃录音', en: 'Discard')),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _KeyboardKey(label: 'SPACE'),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    context.l10n.text(
                      zh: '快捷键开始 / 停止',
                      en: 'Shortcut to start / stop',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _UploadZone(state: state),
          if (state.isProcessing) ...[
            const SizedBox(height: AppSpacing.lg),
            _DesktopProcessingStatus(state: state),
          ],
        ],
      ),
    );
  }
}

class _DesktopRecordButton extends StatefulWidget {
  const _DesktopRecordButton({required this.state, required this.onPressed});

  final SttState state;
  final Future<void> Function()? onPressed;

  @override
  State<_DesktopRecordButton> createState() => _DesktopRecordButtonState();
}

class _DesktopRecordButtonState extends State<_DesktopRecordButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = widget.state;
    final isRecording = state.phase == SttPhase.recording;
    final activeColor = isRecording ? colors.tertiary : colors.primary;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final semanticLabel = switch (state.phase) {
      SttPhase.countdown => context.l10n.text(
        zh: '取消录音倒计时',
        en: 'Cancel recording countdown',
      ),
      SttPhase.recording || SttPhase.paused => context.l10n.text(
        zh: '停止录音并转录',
        en: 'Stop recording and transcribe',
      ),
      _ when state.result != null => context.l10n.text(
        zh: '新建转录',
        en: 'New transcript',
      ),
      _ => context.l10n.text(zh: '开始录音', en: 'Start recording'),
    };

    return SizedBox.square(
      dimension: 152,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _RecordingAura(active: isRecording),
          AnimatedScale(
            scale: _hovered && widget.onPressed != null ? 1.025 : 1,
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Semantics(
              button: true,
              enabled: widget.onPressed != null,
              label: semanticLabel,
              child: ExcludeSemantics(
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hovered = true),
                  onExit: (_) => setState(() => _hovered = false),
                  child: Material(
                    key: state.canStart
                        ? const Key('startRecordingButton')
                        : null,
                    color: isRecording
                        ? colors.tertiaryContainer
                        : colors.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                      side: BorderSide(
                        color: isRecording
                            ? colors.tertiary.withValues(alpha: 0.45)
                            : colors.outlineVariant,
                      ),
                    ),
                    elevation: _hovered ? 3 : 1,
                    shadowColor: colors.shadow.withValues(alpha: 0.12),
                    child: InkWell(
                      onTap: widget.onPressed == null
                          ? null
                          : () => widget.onPressed!(),
                      borderRadius: BorderRadius.circular(36),
                      focusColor: colors.primary.withValues(alpha: 0.10),
                      child: SizedBox.square(
                        dimension: 120,
                        child: Center(child: _recordIcon(activeColor)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordIcon(Color color) {
    return switch (widget.state.phase) {
      SttPhase.countdown => Text(
        '${widget.state.countdown}',
        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      SttPhase.uploading || SttPhase.transcribing => SizedBox.square(
        dimension: 36,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      ),
      _ when widget.state.result != null => Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.mic_none_rounded, size: 44, color: color),
          Positioned(
            right: -5,
            top: -5,
            child: Icon(Icons.add_circle, size: 19, color: color),
          ),
        ],
      ),
      _ => Icon(Icons.mic_none_rounded, size: 44, color: color),
    };
  }
}

class _RecordingAura extends StatefulWidget {
  const _RecordingAura({required this.active});

  final bool active;

  @override
  State<_RecordingAura> createState() => _RecordingAuraState();
}

class _RecordingAuraState extends State<_RecordingAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _RecordingAura oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldAnimate =
        widget.active && !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    final color = Theme.of(context).colorScheme.tertiary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          _ring(color, _controller.value),
          _ring(color, (_controller.value + 0.5) % 1),
        ],
      ),
    );
  }

  Widget _ring(Color color, double progress) {
    return Opacity(
      opacity: (1 - progress) * 0.42,
      child: Transform.scale(
        scale: 0.82 + progress * 0.42,
        child: Container(
          width: 142,
          height: 142,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(46),
            border: Border.all(color: color, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _LiveWave extends StatefulWidget {
  const _LiveWave({required this.active});

  final bool active;

  @override
  State<_LiveWave> createState() => _LiveWaveState();
}

class _LiveWaveState extends State<_LiveWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _LiveWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldAnimate =
        widget.active && !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox(height: 0);
    }
    return ExcludeSemantics(
      child: SizedBox(
        height: 30,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var index = 0; index < 18; index++)
                Container(
                  width: 3,
                  height:
                      6 +
                      17 *
                          ((math.sin(
                                    _controller.value * math.pi * 2 +
                                        index * 0.62,
                                  ) +
                                  1) /
                              2),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadZone extends ConsumerWidget {
  const _UploadZone({required this.state});

  final SttState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final seedAsrSelected = SeedAsrApiService.supportsModel(
      ref.watch(settingsProvider).sttModel,
    );
    final filePath = state.selectedFilePath;
    final fileName = filePath == null
        ? null
        : File(filePath).uri.pathSegments.last;
    final detail = seedAsrSelected
        ? context.l10n.text(
            zh: 'MP3 / MP4 / MPEG / MPGA / M4A / WAV / WEBM · SeedASR 自动转换 · 最大 25 MB',
            en: 'MP3 / MP4 / MPEG / MPGA / M4A / WAV / WEBM · auto-converted for SeedASR · up to 25 MB',
          )
        : context.l10n.text(
            zh: 'MP3 / MP4 / M4A / WAV / WEBM · 最大 25 MB',
            en: 'MP3 / MP4 / M4A / WAV / WEBM · up to 25 MB',
          );
    final enabled = state.canStart;
    final label =
        fileName ??
        context.l10n.text(
          zh: '或上传音频、视频文件转写',
          en: 'Or upload audio or video to transcribe',
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: enabled ? colors.outline : colors.outlineVariant,
          radius: 13,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled
                ? () => ref
                      .read(sttProvider.notifier)
                      .pickAndTranscribe(
                        dialogTitle: context.l10n.text(
                          zh: '选择音频或视频文件',
                          en: 'Choose an audio or video file',
                        ),
                      )
                : null,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 18,
                    color: enabled
                        ? colors.onSurfaceVariant
                        : colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: enabled
                                    ? colors.onSurfaceVariant
                                    : colors.onSurfaceVariant.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                        ),
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: 0.78,
                                ),
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
      ),
    );
  }
}

class _DesktopProcessingStatus extends StatelessWidget {
  const _DesktopProcessingStatus({required this.state});

  final SttState state;

  @override
  Widget build(BuildContext context) {
    final uploading = state.phase == SttPhase.uploading;
    final progress = state.uploadProgress.clamp(0.0, 1.0).toDouble();
    final hasProgress = uploading && progress > 0;
    final percent = (progress * 100).round();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppStatusBanner(
            kind: AppStatusKind.info,
            title: uploading
                ? context.l10n.text(zh: '正在上传音频…', en: 'Uploading audio…')
                : context.l10n.text(zh: 'AI 正在转录…', en: 'Transcribing…'),
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
          LinearProgressIndicator(value: hasProgress ? progress : null),
        ],
      ),
    );
  }
}

class _DesktopTranscriptCard extends ConsumerWidget {
  const _DesktopTranscriptCard({
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
    final result = state.result;
    final colors = Theme.of(context).colorScheme;
    final segmentCount = result?.segments.length ?? 0;
    final duration = result?.duration ?? state.elapsed;
    final resultMeta = result == null
        ? context.l10n.text(zh: '等待录音', en: 'Waiting for audio')
        : context.l10n.text(
            zh: '$segmentCount 段 · ${_duration(duration)}',
            en: '$segmentCount ${segmentCount == 1 ? 'segment' : 'segments'} · ${_duration(duration)}',
          );

    return _DesktopSurface(
      radius: 19,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.text(zh: '转录结果', en: 'Transcript'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        resultMeta,
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
                    ),
                  ],
                ),
                _TranscriptToolbar(
                  state: state,
                  view: view,
                  onViewChanged: onViewChanged,
                  onCopy: onCopy,
                  onExport: onExport,
                  onNewTranscript: onNewTranscript,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          if (result == null)
            const _TranscriptSkeleton()
          else if (view == _TranscriptView.srt)
            _SegmentList(segments: result.segments)
          else
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                key: const Key('transcriptionEditor'),
                controller: controller,
                minLines: 8,
                maxLines: 16,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onChanged: ref.read(sttProvider.notifier).updateEditedText,
                decoration: InputDecoration(
                  labelText: context.l10n.text(
                    zh: '可编辑全文',
                    en: 'Editable transcript',
                  ),
                  helperText: context.l10n.text(
                    zh: '修改全文不会改变原始音频或 SRT 时间轴。',
                    en: 'Editing does not change the source audio or SRT timeline.',
                  ),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          if (result != null && !state.canExportSrt)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
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
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<_TranscriptView>(
          segments: const [
            ButtonSegment(value: _TranscriptView.text, label: Text('TXT')),
            ButtonSegment(value: _TranscriptView.srt, label: Text('SRT')),
          ],
          selected: {view},
          onSelectionChanged: (selection) {
            final next = selection.single;
            if (next != _TranscriptView.srt || state.canExportSrt) {
              onViewChanged(next);
            }
          },
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        IconButton(
          tooltip: context.l10n.text(zh: '复制全文', en: 'Copy transcript'),
          onPressed: state.canExport ? onCopy : null,
          icon: const Icon(Icons.copy_all_outlined, size: 19),
        ),
        IconButton(
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.5,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                const _SkeletonRow(time: '00:00 → 00:04', widthFactor: 0.86),
                const _SkeletonRow(time: '00:04 → 00:08', widthFactor: 0.62),
                const _SkeletonRow(time: '00:08 → 00:12', widthFactor: 0.74),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.text(
                    zh: '完成一次录音后，带时间轴的转录片段会显示在这里',
                    en: 'Timestamped transcript segments will appear here after recording.',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 126,
            child: Text(
              time,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontFamily: 'Cascadia Code',
                fontFamilyFallback: const ['JetBrains Mono', 'Consolas'],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: widthFactor,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentList extends StatelessWidget {
  const _SegmentList({required this.segments});

  final List<TranscriptionSegment> segments;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          for (var index = 0; index < segments.length; index++) ...[
            if (index > 0) Divider(height: 1, color: colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 132,
                    child: Text(
                      '${_duration(segments[index].start)} → ${_duration(segments[index].end)}',
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
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      segments[index].text,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KeyboardKey extends StatelessWidget {
  const _KeyboardKey({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontFamily: 'Cascadia Code',
          fontFamilyFallback: const ['JetBrains Mono', 'Consolas'],
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
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.24
                  : 0.04,
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 6, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color || radius != oldDelegate.radius;
  }
}

String _recordingStatus(BuildContext context, SttState state) {
  return switch (state.phase) {
    SttPhase.countdown => context.l10n.text(
      zh: '准备录音…',
      en: 'Preparing to record…',
    ),
    SttPhase.recording => context.l10n.text(
      zh: '正在录音 · 再次点击停止',
      en: 'Recording · select again to stop',
    ),
    SttPhase.paused => context.l10n.text(zh: '录音已暂停', en: 'Recording paused'),
    SttPhase.uploading => context.l10n.text(
      zh: '正在上传音频',
      en: 'Uploading audio',
    ),
    SttPhase.transcribing => context.l10n.text(
      zh: '正在整理转录结果',
      en: 'Preparing transcript',
    ),
    _ => context.l10n.text(zh: '点击开始录音', en: 'Select to start recording'),
  };
}

String _duration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String _spokenDuration(BuildContext context, Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return context.l10n.text(
    zh: '$minutes 分 $seconds 秒',
    en:
        '$minutes ${minutes == 1 ? 'minute' : 'minutes'} '
        '$seconds ${seconds == 1 ? 'second' : 'seconds'}',
  );
}
