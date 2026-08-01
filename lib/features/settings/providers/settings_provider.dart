import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/dio_client.dart';
import '../models/model_catalog.dart';
import '../models/settings_state.dart';
import '../services/settings_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences 尚未初始化。');
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

final appLoggerProvider = Provider<AppLogger>((ref) => AppLogger.instance);

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref.watch(settingsRepositoryProvider));
});

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient.withSettings(
    () => ref.read(settingsProvider),
  );
});

typedef ModelLoader = Future<List<String>> Function(SettingsState settings);

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(
    this._repository, {
    ModelLoader? modelLoader,
  })  : _modelLoader = modelLoader ?? _loadModels,
        super(_repository.load());

  final SettingsRepository _repository;
  final ModelLoader _modelLoader;

  static Future<List<String>> _loadModels(SettingsState settings) {
    return DioClient(settings).fetchModelIds();
  }

  Future<AppMessage> save({
    required String apiKey,
    required String baseUrl,
    required String sttModel,
    required String ttsModel,
  }) async {
    state = state.copyWith(
      activeOperation: SettingsOperation.saving,
      clearMessage: true,
    );
    try {
      final validated = SettingsState(
        apiKey: apiKey,
        baseUrl: baseUrl,
        sttModel: sttModel,
        ttsModel: ttsModel,
        themePreference: state.themePreference,
        localePreference: state.localePreference,
      ).validated();
      await _repository.save(validated);
      const feedback = AppMessage(
        zh: '设置已保存。',
        en: 'Settings saved.',
      );
      state = validated.copyWith(
        availableSttModels: state.availableSttModels,
        availableTtsModels: state.availableTtsModels,
        hasFetchedModels: state.hasFetchedModels,
        clearActiveOperation: true,
        feedback: feedback,
      );
      return feedback;
    } on AppException catch (error) {
      state = state.copyWith(
        clearActiveOperation: true,
        feedback: error.localizedMessage,
      );
      rethrow;
    } catch (_) {
      final error = AppException.localized(
        AppErrorCode.unknown,
        const AppMessage(
          zh: '设置保存失败，请重试。',
          en: 'Settings could not be saved. Try again.',
        ),
      );
      state = state.copyWith(
        clearActiveOperation: true,
        feedback: error.localizedMessage,
      );
      throw error;
    }
  }

  Future<AppMessage> testConnection({
    required String apiKey,
    required String baseUrl,
    required String sttModel,
    required String ttsModel,
  }) async {
    state = state.copyWith(
      activeOperation: SettingsOperation.testingConnection,
      clearConnectionResult: true,
      clearMessage: true,
    );
    try {
      final validated = SettingsState(
        apiKey: apiKey,
        baseUrl: baseUrl,
        sttModel: sttModel,
        ttsModel: ttsModel,
        themePreference: state.themePreference,
        localePreference: state.localePreference,
      ).validated();
      await DioClient(validated).testConnection();
      await _repository.save(validated);
      const feedback = AppMessage(
        zh: '连接成功，设置已保存。',
        en: 'Connection succeeded and settings were saved.',
      );
      state = validated.copyWith(
        availableSttModels: state.availableSttModels,
        availableTtsModels: state.availableTtsModels,
        hasFetchedModels: state.hasFetchedModels,
        clearActiveOperation: true,
        lastConnectionSucceeded: true,
        feedback: feedback,
      );
      return feedback;
    } on AppException catch (error) {
      state = state.copyWith(
        clearActiveOperation: true,
        lastConnectionSucceeded: false,
        feedback: error.localizedMessage,
      );
      rethrow;
    } catch (_) {
      final error = AppException.localized(
        AppErrorCode.unknown,
        const AppMessage(
          zh: 'API 连通性测试失败，请检查配置。',
          en: 'The API connection test failed. Check the configuration.',
        ),
      );
      state = state.copyWith(
        clearActiveOperation: true,
        lastConnectionSucceeded: false,
        feedback: error.localizedMessage,
      );
      throw error;
    }
  }

  Future<ModelCatalog> fetchModels({
    required String apiKey,
    required String baseUrl,
  }) async {
    state = state.copyWith(
      activeOperation: SettingsOperation.fetchingModels,
      clearAvailableModels: true,
      clearConnectionResult: true,
      clearMessage: true,
    );
    try {
      final credentials = SettingsState(
        apiKey: apiKey,
        baseUrl: baseUrl,
        sttModel: state.sttModel,
        ttsModel: state.ttsModel,
        themePreference: state.themePreference,
        localePreference: state.localePreference,
      ).credentialsValidated();
      final catalog = ModelCatalog.fromIds(await _modelLoader(credentials));
      if (catalog.stt.isEmpty && catalog.tts.isEmpty) {
        throw AppException.localized(
          AppErrorCode.invalidConfiguration,
          const AppMessage(
            zh: '已连接服务，但未识别到语音转文字或文字转语音模型。',
            en: 'The service connected, but no compatible speech models were found.',
          ),
        );
      }
      final feedback = AppMessage(
        zh: '已获取 ${catalog.stt.length} 个语音转文字模型、'
            '${catalog.tts.length} 个文字转语音模型；选择后请保存设置。',
        en: 'Fetched ${catalog.stt.length} speech-to-text '
            '${catalog.stt.length == 1 ? 'model' : 'models'} and '
            '${catalog.tts.length} text-to-speech '
            '${catalog.tts.length == 1 ? 'model' : 'models'}. Save settings '
            'after choosing models.',
      );
      state = state.copyWith(
        availableSttModels: catalog.stt,
        availableTtsModels: catalog.tts,
        hasFetchedModels: true,
        clearActiveOperation: true,
        lastConnectionSucceeded: true,
        feedback: feedback,
      );
      return catalog;
    } on AppException catch (error) {
      state = state.copyWith(
        clearActiveOperation: true,
        lastConnectionSucceeded: false,
        feedback: error.localizedMessage,
      );
      rethrow;
    } catch (_) {
      final error = AppException.localized(
        AppErrorCode.unknown,
        const AppMessage(
          zh: '无法获取模型列表，请稍后重试。',
          en: 'The model list could not be fetched. Try again later.',
        ),
      );
      state = state.copyWith(
        clearActiveOperation: true,
        lastConnectionSucceeded: false,
        feedback: error.localizedMessage,
      );
      throw error;
    }
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    if (state.themePreference == preference) {
      return;
    }
    final previous = state;
    state = state.copyWith(themePreference: preference);
    try {
      await _repository.save(state);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> setLocalePreference(AppLocalePreference preference) async {
    if (state.localePreference == preference) {
      return;
    }
    final previous = state;
    state = state.copyWith(localePreference: preference);
    try {
      await _repository.save(state);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}
