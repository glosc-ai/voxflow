import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/settings_state.dart';
import '../services/settings_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences 尚未初始化。');
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref.watch(settingsRepositoryProvider));
});

final dioClientProvider = Provider<DioClient>((ref) {
  final settings = ref.watch(settingsProvider);
  return DioClient(settings);
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._repository) : super(_repository.load());

  final SettingsRepository _repository;

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
      state = validated.copyWith(isBusy: false, message: '设置已保存。');
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
}
