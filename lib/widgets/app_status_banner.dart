import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';

enum AppStatusKind { info, success, warning, error }

class AppStatusBanner extends StatelessWidget {
  const AppStatusBanner({
    required this.kind,
    required this.message,
    this.title,
    this.action,
    this.messageKey,
    super.key,
  });

  final AppStatusKind kind;
  final String? title;
  final String message;
  final Widget? action;
  final Key? messageKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantics = context.semanticColors;
    final (foreground, background, icon) = switch (kind) {
      AppStatusKind.info => (
          semantics.info,
          semantics.infoContainer,
          Icons.info_outline,
        ),
      AppStatusKind.success => (
          semantics.success,
          semantics.successContainer,
          Icons.check_circle_outline,
        ),
      AppStatusKind.warning => (
          semantics.warning,
          semantics.warningContainer,
          Icons.warning_amber_rounded,
        ),
      AppStatusKind.error => (
          colors.error,
          colors.errorContainer,
          Icons.error_outline,
        ),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      label: [title, message]
          .whereType<String>()
          .join(context.l10n.text(zh: '。', en: '. ')),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(color: foreground.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackAction = action != null &&
                  (constraints.maxWidth < 420 ||
                      MediaQuery.textScalerOf(context).scale(1) >= 1.6);
              final messageContent = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: foreground, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null) ...[
                          Text(
                            title!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                        ],
                        Text(
                          message,
                          key: messageKey,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: foreground,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              if (stackAction) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    messageContent,
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: action!,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: messageContent),
                  if (action != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    action!,
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
