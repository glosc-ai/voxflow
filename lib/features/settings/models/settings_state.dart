import 'dart:ui' show Locale;

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';

enum AppThemePreference {
  system,
  light,
  dark;

  static AppThemePreference fromStorage(String? value) {
    return AppThemePreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => AppThemePreference.system,
    );
  }
}

enum AppLocalePreference {
  system,
  zhHans,
  english;

  static AppLocalePreference fromStorage(String? value) {
    return AppLocalePreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => AppLocalePreference.system,
    );
  }
}

enum SettingsOperation {
  saving,
  testingConnection,
  fetchingModels,
}

class SettingsState {
  const SettingsState({
    this.apiKey = '',
    this.baseUrl = AppConstants.defaultBaseUrl,
    this.sttModel = AppConstants.defaultSttModel,
    this.ttsModel = AppConstants.defaultTtsModel,
    this.themePreference = AppThemePreference.system,
    this.localePreference = AppLocalePreference.system,
    this.availableSttModels = const [],
    this.availableTtsModels = const [],
    this.hasFetchedModels = false,
    this.activeOperation,
    this.lastConnectionSucceeded,
    this.feedback,
    String? message,
  }) : _legacyMessage = message;

  final String apiKey;
  final String baseUrl;
  final String sttModel;
  final String ttsModel;
  final AppThemePreference themePreference;
  final AppLocalePreference localePreference;
  final List<String> availableSttModels;
  final List<String> availableTtsModels;
  final bool hasFetchedModels;
  final SettingsOperation? activeOperation;
  final bool? lastConnectionSucceeded;
  final AppMessage? feedback;
  final String? _legacyMessage;

  /// Chinese compatibility getter for older callers and persisted test data.
  String? get message =>
      feedback?.resolve(const Locale('zh')) ?? _legacyMessage;

  String? messageFor(Locale locale) =>
      feedback?.resolve(locale) ?? _legacyMessage;

  bool get hasApiKey => apiKey.trim().isNotEmpty;
  bool get isBusy => activeOperation != null;

  SettingsState copyWith({
    String? apiKey,
    String? baseUrl,
    String? sttModel,
    String? ttsModel,
    AppThemePreference? themePreference,
    AppLocalePreference? localePreference,
    List<String>? availableSttModels,
    List<String>? availableTtsModels,
    bool clearAvailableModels = false,
    bool? hasFetchedModels,
    SettingsOperation? activeOperation,
    bool clearActiveOperation = false,
    bool? lastConnectionSucceeded,
    bool clearConnectionResult = false,
    AppMessage? feedback,
    String? message,
    bool clearMessage = false,
  }) {
    final nextFeedback = clearMessage
        ? null
        : (feedback ?? (message == null ? this.feedback : null));
    final nextLegacyMessage = clearMessage || feedback != null
        ? null
        : (message ?? (this.feedback == null ? _legacyMessage : null));
    return SettingsState(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      sttModel: sttModel ?? this.sttModel,
      ttsModel: ttsModel ?? this.ttsModel,
      themePreference: themePreference ?? this.themePreference,
      localePreference: localePreference ?? this.localePreference,
      availableSttModels: clearAvailableModels
          ? const []
          : (availableSttModels ?? this.availableSttModels),
      availableTtsModels: clearAvailableModels
          ? const []
          : (availableTtsModels ?? this.availableTtsModels),
      hasFetchedModels: hasFetchedModels ??
          (clearAvailableModels ? false : this.hasFetchedModels),
      activeOperation: clearActiveOperation
          ? null
          : (activeOperation ?? this.activeOperation),
      lastConnectionSucceeded: clearConnectionResult
          ? null
          : (lastConnectionSucceeded ?? this.lastConnectionSucceeded),
      feedback: nextFeedback,
      message: nextLegacyMessage,
    );
  }

  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        'API 地址必须是有效的 HTTPS 地址。',
        englishMessage: 'The API address must be a valid HTTPS URL.',
      );
    }
    var normalized = uri.toString();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  SettingsState validated() {
    final validatedCredentials = credentialsValidated();
    if (sttModel.trim().isEmpty || ttsModel.trim().isEmpty) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        '模型名称不能为空。',
        englishMessage: 'Model names cannot be empty.',
      );
    }
    return validatedCredentials.copyWith(
      sttModel: sttModel.trim(),
      ttsModel: ttsModel.trim(),
      clearMessage: true,
    );
  }

  SettingsState credentialsValidated() {
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty) {
      throw const AppException(
        AppErrorCode.missingApiKey,
        '请先填写 API Key。',
        englishMessage: 'Enter an API key first.',
      );
    }
    return copyWith(
      apiKey: normalizedKey,
      baseUrl: normalizeBaseUrl(baseUrl),
      clearMessage: true,
    );
  }
}
