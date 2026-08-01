import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';

class AppSection extends StatelessWidget {
  const AppSection({
    required this.child,
    this.title,
    this.description,
    this.leading,
    this.trailing,
    this.padding,
    super.key,
  });

  final String? title;
  final String? description;
  final Widget? leading;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasHeader = title != null ||
        description != null ||
        leading != null ||
        trailing != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: padding ??
            EdgeInsets.all(
              MediaQuery.sizeOf(context).width < AppBreakpoints.compact ||
                      Theme.of(context).platform == TargetPlatform.android
                  ? AppSpacing.md
                  : AppSpacing.lg,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHeader) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final stackTrailing = trailing != null &&
                      (constraints.maxWidth < 480 ||
                          MediaQuery.textScalerOf(context).scale(1) >= 1.6);
                  final titleBlock = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (leading != null) ...[
                        IconTheme(
                          data: IconThemeData(
                            color: colors.primary,
                            size: 20,
                          ),
                          child: leading!,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null)
                              Text(title!, style: textTheme.titleMedium),
                            if (description != null) ...[
                              if (title != null)
                                const SizedBox(height: AppSpacing.xxs),
                              Text(
                                description!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                  if (stackTrailing) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        titleBlock,
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: trailing!,
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleBlock),
                      if (trailing != null) ...[
                        const SizedBox(width: AppSpacing.md),
                        trailing!,
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
