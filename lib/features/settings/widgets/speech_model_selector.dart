import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';

enum SpeechModelKind { stt, tts }

class SpeechModelSelector extends ConsumerStatefulWidget {
  const SpeechModelSelector({
    required this.kind,
    this.enabled = true,
    super.key,
  });

  final SpeechModelKind kind;
  final bool enabled;

  @override
  ConsumerState<SpeechModelSelector> createState() =>
      _SpeechModelSelectorState();
}

class _SpeechModelSelectorState extends ConsumerState<SpeechModelSelector> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final current = widget.kind == SpeechModelKind.stt
        ? settings.sttModel
        : settings.ttsModel;
    final fetchedModels = widget.kind == SpeechModelKind.stt
        ? settings.availableSttModels
        : settings.availableTtsModels;
    final models = <String>{
      current,
      ...fetchedModels.where((model) => model.trim().isNotEmpty),
    }.toList(growable: false);
    final enabled = widget.enabled && !_saving && models.isNotEmpty;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isAndroid = theme.platform == TargetPlatform.android;
    final menuRadius = isAndroid ? AppRadii.mobileCard : AppRadii.dialog;

    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: widget.kind == SpeechModelKind.stt
          ? context.l10n.text(zh: '选择转录模型', en: 'Choose transcription model')
          : context.l10n.text(zh: '选择合成模型', en: 'Choose speech model'),
      initialValue: current,
      position: PopupMenuPosition.under,
      constraints: BoxConstraints(
        minWidth: isAndroid ? 176 : 180,
        maxWidth: isAndroid ? 300 : 320,
      ),
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(menuRadius),
        side: BorderSide(color: colors.outlineVariant),
      ),
      onSelected: _select,
      itemBuilder: (context) => [
        for (final model in models)
          PopupMenuItem<String>(
            value: model,
            height: isAndroid ? 48 : kMinInteractiveDimension,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    model,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'Cascadia Code',
                      fontFamilyFallback: const ['JetBrains Mono', 'Consolas'],
                    ),
                  ),
                ),
                if (model == current) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.check, size: 16, color: colors.primary),
                ],
              ],
            ),
          ),
      ],
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.kind == SpeechModelKind.stt
            ? context.l10n.text(
                zh: '当前转录模型 $current',
                en: 'Current transcription model $current',
              )
            : context.l10n.text(
                zh: '当前合成模型 $current',
                en: 'Current speech model $current',
              ),
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            constraints: BoxConstraints(
              minHeight: isAndroid ? 48 : 34,
              maxWidth: isAndroid ? 280 : 260,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: ShapeDecoration(
              color: colors.surface,
              shape: isAndroid
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppRadii.mobileControl,
                      ),
                      side: BorderSide(
                        color: enabled ? colors.outlineVariant : colors.outline,
                      ),
                    )
                  : StadiumBorder(
                      side: BorderSide(
                        color: enabled ? colors.outlineVariant : colors.outline,
                      ),
                    ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    current,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: enabled
                          ? colors.onSurfaceVariant
                          : colors.onSurfaceVariant.withValues(alpha: 0.55),
                      fontFamily: 'Cascadia Code',
                      fontFamilyFallback: const ['JetBrains Mono', 'Consolas'],
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                if (_saving)
                  SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colors.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _select(String model) async {
    setState(() => _saving = true);
    try {
      final notifier = ref.read(settingsProvider.notifier);
      if (widget.kind == SpeechModelKind.stt) {
        await notifier.setSttModel(model);
      } else {
        await notifier.setTtsModel(model);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.text(
                zh: '无法保存模型选择，请重试。',
                en: 'The model selection could not be saved. Try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
