import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/utils/path_utils.dart';
import '../../history/services/history_repository.dart';
import 'api_key_store.dart';

typedef DataResetAction = Future<void> Function();

class ApplicationDataResetService {
  ApplicationDataResetService({
    required SharedPreferences preferences,
    required ApiKeyStore apiKeyStore,
    required HistoryRepository historyRepository,
    required AppLogger logger,
    DataResetAction? clearManagedAudio,
    DataResetAction? clearTemporaryFiles,
  }) : _preferences = preferences,
       _apiKeyStore = apiKeyStore,
       _historyRepository = historyRepository,
       _logger = logger,
       _clearManagedAudio = clearManagedAudio ?? PathUtils.clearManagedAudio,
       _clearTemporaryFiles =
           clearTemporaryFiles ?? PathUtils.clearVoxFlowTemporaryFiles;

  final SharedPreferences _preferences;
  final ApiKeyStore _apiKeyStore;
  final HistoryRepository _historyRepository;
  final AppLogger _logger;
  final DataResetAction _clearManagedAudio;
  final DataResetAction _clearTemporaryFiles;

  Future<void> reset() async {
    try {
      // Credentials are the reset transaction's safety boundary. Continuing
      // with a retained key but cleared API Root could send it to the default
      // service on the next launch.
      await _apiKeyStore.delete();
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法清除安全凭据，其他本机数据未作更改，请重试。',
        englishMessage:
            'The secure credential could not be cleared. No other local data was changed.',
      );
    }

    var failed = false;

    Future<void> run(DataResetAction action) async {
      try {
        await action();
      } catch (_) {
        failed = true;
      }
    }

    await run(() async {
      if (!await _preferences.clear()) {
        throw StateError('Shared preferences could not be cleared.');
      }
    });
    await run(_historyRepository.clear);
    await run(_clearManagedAudio);
    await run(_clearTemporaryFiles);
    await run(_logger.clear);

    if (failed) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '部分本机数据未能清除，请重试。',
        englishMessage: 'Some local data could not be cleared. Try again.',
      );
    }
  }
}
