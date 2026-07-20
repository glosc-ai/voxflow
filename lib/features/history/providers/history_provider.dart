import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/path_utils.dart';
import '../models/history_record.dart';
import '../services/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final repository = HistoryRepository();
  ref.onDispose(repository.close);
  return repository;
});

final historyProvider =
    StateNotifierProvider<HistoryNotifier, AsyncValue<List<HistoryRecord>>>(
        (ref) {
  final notifier = HistoryNotifier(ref.watch(historyRepositoryProvider));
  Future.microtask(notifier.load);
  return notifier;
});

class HistoryNotifier extends StateNotifier<AsyncValue<List<HistoryRecord>>> {
  HistoryNotifier(this._repository) : super(const AsyncValue.loading());

  final HistoryRepository _repository;
  String _query = '';

  Future<void> load({String? query}) async {
    if (query != null) {
      _query = query;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.search(_query));
  }

  Future<HistoryRecord> add({
    required HistoryType type,
    required String text,
    required String audioPath,
  }) async {
    try {
      final inserted = await _repository.insert(
        HistoryRecord(
          type: type,
          text: text,
          audioPath: audioPath,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      await load();
      return inserted;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法保存历史记录。',
      );
    }
  }

  Future<String?> delete(HistoryRecord record) async {
    final id = record.id;
    if (id == null) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '历史记录无效，无法删除。',
      );
    }
    await _repository.delete(id);
    String? warning;
    try {
      if (await PathUtils.isManagedAudioPath(record.audioPath)) {
        final file = File(record.audioPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {
      warning = '记录已删除，但音频文件未能清理。';
    }
    await load();
    return warning;
  }
}
