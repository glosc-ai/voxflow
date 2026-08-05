import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/errors/app_exception.dart';

/// The locales VoxFlow can render without generated localization packages.
///
/// App-owned copy uses [text]. Framework-owned copy is provided by Flutter's
/// official localization delegates so controls and semantics match the UI.
class AppLocalizations {
  const AppLocalizations(this.locale);

  static const englishLocale = Locale('en');
  static const simplifiedChineseLocale = Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hans',
  );
  static const supportedLocales = <Locale>[
    englishLocale,
    simplifiedChineseLocale,
  ];

  static const delegate = _AppLocalizationsDelegate();
  static const delegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  final Locale locale;

  bool get isSimplifiedChinese => locale.languageCode.toLowerCase() == 'zh';

  static AppLocalizations of(BuildContext context) {
    // A Chinese fallback keeps isolated widget tests and embedders that have
    // not yet registered [delegate] source-compatible with the original UI.
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(simplifiedChineseLocale);
  }

  /// Selects app-owned copy while keeping call sites short and reviewable.
  String text({required String zh, required String en}) {
    return isSimplifiedChinese ? zh : en;
  }

  /// Maps the app's existing user-facing exceptions at the presentation edge.
  /// Unknown English/provider detail is preserved; unknown Chinese detail gets
  /// a safe localized message based on its stable error code.
  String appError(AppException error) {
    if (isSimplifiedChinese) {
      return error.message;
    }
    final known = _knownEnglishMessages[error.message];
    if (known != null) {
      return known;
    }
    if (!_containsHan(error.message)) {
      return error.message;
    }
    return error.englishMessage;
  }

  static Locale resolveLocale(Locale? locale) {
    return locale?.languageCode.toLowerCase() == 'zh'
        ? simplifiedChineseLocale
        : englishLocale;
  }

  static Locale localeResolutionCallback(
    Locale? locale,
    Iterable<Locale> supportedLocales,
  ) {
    return resolveLocale(locale);
  }

  /// Scans the complete system preference list instead of assuming the first
  /// locale is usable. English keeps its region so dates and numbers follow
  /// regional conventions; all Chinese variants use the supported Hans copy.
  static Locale localeListResolutionCallback(
    List<Locale>? locales,
    Iterable<Locale> supportedLocales,
  ) {
    for (final locale in locales ?? const <Locale>[]) {
      switch (locale.languageCode.toLowerCase()) {
        case 'zh':
          return simplifiedChineseLocale;
        case 'en':
          return locale;
      }
    }
    return englishLocale;
  }
}

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'zh';

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(
      AppLocalizations(AppLocalizations.resolveLocale(locale)),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

bool _containsHan(String value) => RegExp(r'[\u3400-\u9fff]').hasMatch(value);

const _knownEnglishMessages = <String, String>{
  '设置已保存。': 'Settings saved.',
  '连接成功，设置已保存。': 'Connection succeeded and settings were saved.',
  '设置保存失败，请重试。': 'Settings could not be saved. Try again.',
  'API 连通性测试失败，请检查配置。':
      'The API connection test failed. Check the configuration.',
  '无法获取模型列表，请稍后重试。': 'The model list could not be fetched. Try again later.',
  '已连接服务，但未识别到语音转文字或文字转语音模型。':
      'The service connected, but no compatible speech models were found.',
  'API 地址必须是有效的 HTTPS 地址。': 'The API address must be a valid HTTPS URL.',
  '模型名称不能为空。': 'Model names cannot be empty.',
  '请先填写 API Key。': 'Enter an API key first.',
  '无法读取本机设置。': 'Local settings could not be loaded.',
  '无法读取数据与隐私说明状态。': 'The privacy acknowledgement could not be loaded.',
  '无法保存数据与隐私说明状态。': 'The privacy acknowledgement could not be saved.',
};
