import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/utils/path_utils.dart';

void main() {
  test('识别受管目录内路径并拒绝相似前缀', () {
    final separator = Platform.pathSeparator;
    final root = '${Directory.current.path}${separator}managed';
    final inside = '$root${separator}stt${separator}audio.wav';
    final outside = '${root}_other${separator}audio.wav';

    expect(PathUtils.isPathWithin(root, inside), isTrue);
    expect(PathUtils.isPathWithin(root, outside), isFalse);
  });

  test('安全解析文件扩展名', () {
    expect(PathUtils.extensionOf('voice.MP3'), 'mp3');
    expect(PathUtils.extensionOf('voice'), isEmpty);
  });

  test(
    'managed audio cleanup deletes only the VoxFlow audio directory',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'voxflow_documents_',
      );
      addTearDown(() async {
        if (await documents.exists()) {
          await documents.delete(recursive: true);
        }
      });
      final managedAudio = Directory(
        '${documents.path}${Platform.pathSeparator}VoxFlow'
        '${Platform.pathSeparator}audio${Platform.pathSeparator}stt',
      );
      await managedAudio.create(recursive: true);
      final managedFile = File(
        '${managedAudio.path}${Platform.pathSeparator}managed.wav',
      );
      await managedFile.writeAsString('managed');
      final sibling = File(
        '${documents.path}${Platform.pathSeparator}user-export.wav',
      );
      await sibling.writeAsString('user owned');
      final otherVoxFlowFile = File(
        '${documents.path}${Platform.pathSeparator}VoxFlow'
        '${Platform.pathSeparator}keep.txt',
      );
      await otherVoxFlowFile.writeAsString('not managed audio');

      await PathUtils.clearManagedAudio(
        documentsDirectoryProvider: () async => documents,
      );
      await PathUtils.clearManagedAudio(
        documentsDirectoryProvider: () async => documents,
      );

      expect(
        await Directory(
          '${documents.path}${Platform.pathSeparator}VoxFlow'
          '${Platform.pathSeparator}audio',
        ).exists(),
        isFalse,
      );
      expect(await sibling.exists(), isTrue);
      expect(await otherVoxFlowFile.exists(), isTrue);
    },
  );

  test('temporary cleanup removes only VoxFlow-owned audio patterns', () async {
    final temporary = await Directory.systemTemp.createTemp('voxflow_temp_');
    addTearDown(() async {
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    });
    final ownedNames = [
      'voxflow_recording_123456.wav',
      'voxflow_seed_asr_normalized_123456.wav.part',
      'recording_123456.m4a',
      'seed_asr_normalized_123456.wav',
    ];
    for (final name in ownedNames) {
      await File(
        '${temporary.path}${Platform.pathSeparator}$name',
      ).writeAsString('temporary');
    }
    final preservedNames = [
      'recording_notes.wav',
      'seed_asr_normalized_backup.wav',
      'voxflow_user-export.wav',
      'unrelated.mp3',
    ];
    for (final name in preservedNames) {
      await File(
        '${temporary.path}${Platform.pathSeparator}$name',
      ).writeAsString('user owned');
    }

    await PathUtils.clearVoxFlowTemporaryFiles(
      temporaryDirectoryProvider: () async => temporary,
    );
    await PathUtils.clearVoxFlowTemporaryFiles(
      temporaryDirectoryProvider: () async => temporary,
    );

    for (final name in ownedNames) {
      expect(
        await File('${temporary.path}${Platform.pathSeparator}$name').exists(),
        isFalse,
      );
    }
    for (final name in preservedNames) {
      expect(
        await File('${temporary.path}${Platform.pathSeparator}$name').exists(),
        isTrue,
      );
    }
  });
}
