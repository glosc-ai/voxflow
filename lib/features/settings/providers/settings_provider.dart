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

  Future<String> save({
    required String apiKey,
    required String baseUrl,
    required String sttModel,
    required String ttsModel,
  }) async {
    state = state.copyWith(isBusy: true, clearMessage: true);
    try {
      final validated = SettingsState(
        apiKey: apiKey,
        baseUrl: baseUrl,
        sttModel: sttModel,
        ttsModel: ttsModel,
      ).validated();
      await _repository.save(validated);
      state = validated.copyWith(
        availableSttModels: state.availableSttModels,
        availableTtsModels: state.availableTtsModels,
        hasFetchedModels: state.hasFetchedModels,
        isBusy: false,
        message: '设置已保存。',
      );
      return '设置已保存。';
    } on AppException catch (error) {
      state = state.copyWith(isBusy: false, message: error.message);
      rethrow;
    } catch (_) {
      const error = AppException(
        AppErrorCode.unknown,
        '设置保存失败，请重试。',
      );
      state = state.copyWith(isBusy: false, message: error.message);
      throw error;
    }
  }

  Future<String> testConnection({
    required String apiKey,
    required String baseUrl,
    required String sttModel,
    required String ttsModel,
  }) async {
    state = state.copyWith(
      isBusy: true,
      clearConnectionResult: true,
      clearMessage: true,
    );
    try {
      final validated = SettingsState(
        apiKey: apiKey,
        baseUrl: baseUrl,
        sttModel: sttModel,
        ttsModel: ttsModel,
      ).validated();
      await DioClient(validated).testConnection();
      await _repository.save(validated);
      state = validated.copyWith(
        availableSttModels: state.availableSttModels,
        availableTtsModels: state.availableTtsModels,
        hasFetchedModels: state.hasFetchedModels,
        isBusy: false,
        lastConnectionSucceeded: true,
        message: '连接成功，设置已保存。',
      );
      return '连接成功，设置已保存。';
    } on AppException catch (error) {
      state = state.copyWith(
        isBusy: false,
        lastConnectionSucceeded: false,
        message: error.message,
      );
      rethrow;
    } catch (_) {
      const error = AppException(
        AppErrorCode.unknown,
        'API 连通性测试失败，请检查配置。',
      );
      state = state.copyWith(
        isBusy: false,
        lastConnectionSucceeded: false,
        message: error.message,
      );
      throw error;
    }
  }

  Future<ModelCatalog> fetchModels({
    required String apiKey,
    required String baseUrl,
  }) async {
    state = state.copyWith(
      isBusy: true,
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
      ).credentialsValidated();
      final catalog = ModelCatalog.fromIds(await _modelLoader(credentials));
      if (catalog.stt.isEmpty && catalog.tts.isEmpty) {
        throw const AppException(
          AppErrorCode.invalidConfiguration,
          '已连接服务，但未识别到语音转文字或文字转语音模型。',
        );
      }
      final summary = '已获取 ${catalog.stt.length} 个语音转文字模型、'
          '${catalog.tts.length} 个文字转语音模型；选择后请保存设置。';
      state = state.copyWith(
        availableSttModels: catalog.stt,
        availableTtsModels: catalog.tts,
        hasFetchedModels: true,
        isBusy: false,
        lastConnectionSucceeded: true,
        message: summary,
      );
      return catalog;
    } on AppException catch (error) {
      state = state.copyWith(
        isBusy: false,
        lastConnectionSucceeded: false,
        message: error.message,
      );
      rethrow;
    } catch (_) {
      const error = AppException(
        AppErrorCode.unknown,
        '无法获取模型列表，请稍后重试。',
      );
      state = state.copyWith(
        isBusy: false,
        lastConnectionSucceeded: false,
        message: error.message,
      );
      throw error;
    }
  }
}
