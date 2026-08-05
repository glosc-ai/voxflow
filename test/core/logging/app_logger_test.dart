import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/logging/app_logger.dart';

void main() {
  test('日志写入 JSONL 并脱敏密钥、认证头与输入内容', () async {
    final directory = await Directory.systemTemp.createTemp('voxflow_log_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}voxflow.log');
    final logger = AppLogger(fileResolver: () async => file);

    await logger.error(
      'network',
      'request_failed',
      fields: const {
        'status': 403,
        'model': 'bytedance/seed-tts-2.0',
        'api_key': 'plain-secret',
        'authorization': 'Bearer sk-secret123',
        'input': '不应写入日志的合成文本',
        'reason': 'model denied for sk-secret123',
      },
    );
    final contents = await logger.readAll();

    expect(contents, contains('request_failed'));
    expect(contents, contains('bytedance/seed-tts-2.0'));
    expect(contents, contains('[REDACTED]'));
    expect(contents, isNot(contains('plain-secret')));
    expect(contents, isNot(contains('sk-secret123')));
    expect(contents, isNot(contains('不应写入日志的合成文本')));
  });

  test('日志超过限制后轮转并保留上一份', () async {
    final directory = await Directory.systemTemp.createTemp('voxflow_rotate_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}voxflow.log');
    final logger = AppLogger(fileResolver: () async => file, maxFileBytes: 120);

    await logger.info('test', 'first', fields: {'reason': 'a' * 100});
    await logger.info('test', 'second');

    expect(await File('${file.path}.1').exists(), isTrue);
    expect(await logger.readAll(), contains('second'));
  });

  test('单次写入失败后日志队列仍可继续工作', () async {
    final directory = await Directory.systemTemp.createTemp('voxflow_retry_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}voxflow.log');
    var shouldFail = true;
    final logger = AppLogger(
      fileResolver: () async {
        if (shouldFail) {
          throw const FileSystemException('temporary failure');
        }
        return file;
      },
    );

    await logger.info('test', 'failed_write');
    shouldFail = false;
    await logger.info('test', 'recovered_write');

    expect(await logger.readAll(), contains('recovered_write'));
  });

  test(
    'clear removes current and rotated logs, is idempotent, and can log again',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'voxflow_log_clear_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}voxflow.log',
      );
      final rotated = File('${file.path}.1');
      final sibling = File('${file.path}.export');
      await file.writeAsString('current');
      await rotated.writeAsString('rotated');
      await sibling.writeAsString('user copy');
      final logger = AppLogger(fileResolver: () async => file);

      await logger.clear();
      await logger.clear();

      expect(await file.exists(), isFalse);
      expect(await rotated.exists(), isFalse);
      expect(await sibling.exists(), isTrue);

      await logger.info('test', 'after_clear');
      expect(await logger.readAll(), contains('after_clear'));
    },
  );
}
