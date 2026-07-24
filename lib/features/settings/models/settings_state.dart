import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';

class SettingsState {
  const SettingsState({
    this.apiKey = '',
    this.baseUrl = AppConstants.defaultBaseUrl,
    this.sttModel = AppConstants.defaultSttModel,
    this.ttsModel = AppConstants.defaultTtsModel,
    this.availableSttModels = const [],
    this.availableTtsModels = const [],
    this.hasFetchedModels = false,
    this.isBusy = false,
    this.lastConnectionSucceeded,
    this.message,
  });

  final String apiKey;
  final String baseUrl;
  final String sttModel;
  final String ttsModel;
  final List<String> availableSttModels;
  final List<String> availableTtsModels;
  final bool hasFetchedModels;
  final bool isBusy;
  final bool? lastConnectionSucceeded;
  final String? message;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  SettingsState copyWith({
    String? apiKey,
    String? baseUrl,
    String? sttModel,
    String? ttsModel,
    List<String>? availableSttModels,
    List<String>? availableTtsModels,
    bool clearAvailableModels = false,
    bool? hasFetchedModels,
    bool? isBusy,
    bool? lastConnectionSucceeded,
    bool clearConnectionResult = false,
    String? message,
    bool clearMessage = false,
  }) {
    return SettingsState(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      sttModel: sttModel ?? this.sttModel,
      ttsModel: ttsModel ?? this.ttsModel,
      availableSttModels: clearAvailableModels
          ? const []
          : (availableSttModels ?? this.availableSttModels),
      availableTtsModels: clearAvailableModels
          ? const []
          : (availableTtsModels ?? this.availableTtsModels),
      hasFetchedModels: hasFetchedModels ??
          (clearAvailableModels ? false : this.hasFetchedModels),
      isBusy: isBusy ?? this.isBusy,
      lastConnectionSucceeded: clearConnectionResult
          ? null
          : (lastConnectionSucceeded ?? this.lastConnectionSucceeded),
      message: clearMessage ? null : (message ?? this.message),
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
      );
    }
    return copyWith(
      apiKey: normalizedKey,
      baseUrl: normalizeBaseUrl(baseUrl),
      clearMessage: true,
    );
  }
}
