import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:voxflow/features/history/models/history_record.dart';
import 'package:voxflow/features/history/services/history_repository.dart';

void main() {
  late Directory temporaryDirectory;
  late HistoryRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    temporaryDirectory = await Directory.systemTemp.createTemp('voxflow_test_');
    final path =
        '${temporaryDirectory.path}${Platform.pathSeparator}history.db';
    repository = HistoryRepository(
      factory: databaseFactoryFfi,
      pathProvider: () async => path,
    );
  });

  tearDown(() async {
    await repository.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('插入记录并按时间倒序查询', () async {
    await repository.insert(
      HistoryRecord(
        type: HistoryType.stt,
        text: '较早的转录',
        audioPath: 'first.wav',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await repository.insert(
      HistoryRecord(
        type: HistoryType.tts,
        text: '较新的语音',
        audioPath: 'second.mp3',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );

    final records = await repository.search();

    expect(records, hasLength(2));
    expect(records.first.text, '较新的语音');
    expect(records.first.type, HistoryType.tts);
  });

  test('关键词中的通配符按普通字符搜索并可删除', () async {
    final record = await repository.insert(
      HistoryRecord(
        type: HistoryType.stt,
        text: '进度 100%_完成',
        audioPath: 'audio.wav',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    expect(await repository.search('100%_'), hasLength(1));
    await repository.delete(record.id!);
    expect(await repository.search(), isEmpty);
  });

  test(
    'clear removes every record, is idempotent, and keeps audio files',
    () async {
      final externalAudio = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}user-import.wav',
      );
      await externalAudio.writeAsString('user owned');

      await repository.insert(
        HistoryRecord(
          type: HistoryType.stt,
          text: 'first',
          audioPath: externalAudio.path,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await repository.insert(
        HistoryRecord(
          type: HistoryType.tts,
          text: 'second',
          audioPath: externalAudio.path,
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      );

      await repository.clear();
      await repository.clear();

      expect(await repository.search(), isEmpty);
      expect(await externalAudio.exists(), isTrue);

      final insertedAfterReset = await repository.insert(
        HistoryRecord(
          type: HistoryType.stt,
          text: 'after reset',
          audioPath: externalAudio.path,
          createdAt: DateTime.utc(2026, 1, 3),
        ),
      );
      expect(insertedAfterReset.id, 1);
    },
  );
}
