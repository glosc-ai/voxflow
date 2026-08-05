import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_status_banner.dart';

class InlineErrorBanner extends StatelessWidget {
  const InlineErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppStatusBanner(
      kind: AppStatusKind.error,
      title: context.l10n.text(zh: '操作未完成', en: 'Operation not completed'),
      message: message,
      messageKey: const Key('inlineErrorMessage'),
    );
  }
}
