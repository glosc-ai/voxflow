import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/core/logging/app_logger.dart';
import 'package:voxflow/features/history/services/history_repository.dart';
import 'package:voxflow/features/settings/services/application_data_reset_service.dart';

import '../../support/memory_api_key_store.dart';

void main() {
  test('完整重置清除凭据、偏好、历史、音频、临时文件和日志', () async {
    SharedPreferences.setMockInitialValues({
      'privacy_notice.acknowledged.v1': true,
      'settings.base_url': 'https://proxy.example/v1',
    });
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore(initialValue: 'test-secret');
    final history = _TrackingHistoryRepository();
    final directory = await Directory.systemTemp.createTemp('voxflow_reset_');
    addTearDown(() => directory.delete(recursive: true));
    final logFile = File(
      '${directory.path}${Platform.pathSeparator}voxflow.log',
    );
    final logger = AppLogger(fileResolver: () async => logFile);
    await logger.info('test', 'before_reset');
    var managedAudioCleared = false;
    var temporaryFilesCleared = false;
    final service = ApplicationDataResetService(
      preferences: preferences,
      apiKeyStore: apiKeyStore,
      historyRepository: history,
      logger: logger,
      clearManagedAudio: () async => managedAudioCleared = true,
      clearTemporaryFiles: () async => temporaryFilesCleared = true,
    );

    await service.reset();

    expect(apiKeyStore.value, isNull);
    expect(preferences.getKeys(), isEmpty);
    expect(history.clearCount, 1);
    expect(managedAudioCleared, isTrue);
    expect(temporaryFilesCleared, isTrue);
    expect(await logFile.exists(), isFalse);
  });

  test('凭据删除后某一步失败仍继续执行后续清理并返回固定错误', () async {
    SharedPreferences.setMockInitialValues({'settings.base_url': 'stale'});
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore(initialValue: 'test-secret');
    final history = _TrackingHistoryRepository();
    final directory = await Directory.systemTemp.createTemp('voxflow_reset_');
    addTearDown(() => directory.delete(recursive: true));
    final logger = AppLogger(
      fileResolver: () async =>
          File('${directory.path}${Platform.pathSeparator}voxflow.log'),
    );
    var managedAudioAttempted = false;
    var temporaryFilesAttempted = false;
    final service = ApplicationDataResetService(
      preferences: preferences,
      apiKeyStore: apiKeyStore,
      historyRepository: history,
      logger: logger,
      clearManagedAudio: () async {
        managedAudioAttempted = true;
        throw StateError('audio sentinel');
      },
      clearTemporaryFiles: () async => temporaryFilesAttempted = true,
    );

    await expectLater(
      service.reset(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.storageFailure)
            .having(
              (error) => error.toString(),
              'message',
              isNot(
                anyOf(contains('secret sentinel'), contains('audio sentinel')),
              ),
            ),
      ),
    );

    expect(preferences.getKeys(), isEmpty);
    expect(history.clearCount, 1);
    expect(managedAudioAttempted, isTrue);
    expect(temporaryFilesAttempted, isTrue);
    expect(apiKeyStore.value, isNull);
  });

  test('安全凭据删除失败时中止且不改动其他本机数据', () async {
    SharedPreferences.setMockInitialValues({'settings.base_url': 'stale'});
    final preferences = await SharedPreferences.getInstance();
    final apiKeyStore = MemoryApiKeyStore(initialValue: 'test-secret')
      ..deleteError = StateError('secret sentinel');
    final history = _TrackingHistoryRepository();
    final directory = await Directory.systemTemp.createTemp('voxflow_reset_');
    addTearDown(() => directory.delete(recursive: true));
    final service = ApplicationDataResetService(
      preferences: preferences,
      apiKeyStore: apiKeyStore,
      historyRepository: history,
      logger: AppLogger(
        fileResolver: () async =>
            File('${directory.path}${Platform.pathSeparator}voxflow.log'),
      ),
      clearManagedAudio: () async => throw StateError('must not run'),
      clearTemporaryFiles: () async => throw StateError('must not run'),
    );

    await expectLater(
      service.reset(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.storageFailure)
            .having(
              (error) => error.toString(),
              'message',
              isNot(contains('secret sentinel')),
            ),
      ),
    );

    expect(apiKeyStore.value, 'test-secret');
    expect(preferences.getString('settings.base_url'), 'stale');
    expect(history.clearCount, 0);
  });
}

class _TrackingHistoryRepository extends HistoryRepository {
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
  }
}
