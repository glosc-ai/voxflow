import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../errors/app_exception.dart';
import '../utils/path_utils.dart';

enum AppLogLevel { debug, info, warning, error }

typedef LogFileResolver = Future<File> Function();

class AppLogger {
  AppLogger({
    LogFileResolver? fileResolver,
    this.maxFileBytes = 1024 * 1024,
  }) : _fileResolver = fileResolver ?? PathUtils.getLogFile;

  static final AppLogger instance = AppLogger();

  final LogFileResolver _fileResolver;
  final int maxFileBytes;
  Future<void> _pending = Future<void>.value();

  Future<void> debug(
    String category,
    String event, {
    Map<String, Object?> fields = const {},
  }) {
    return _write(AppLogLevel.debug, category, event, fields);
  }

  Future<void> info(
    String category,
    String event, {
    Map<String, Object?> fields = const {},
  }) {
    return _write(AppLogLevel.info, category, event, fields);
  }

  Future<void> warning(
    String category,
    String event, {
    Map<String, Object?> fields = const {},
  }) {
    return _write(AppLogLevel.warning, category, event, fields);
  }

  Future<void> error(
    String category,
    String event, {
    Map<String, Object?> fields = const {},
  }) {
    return _write(AppLogLevel.error, category, event, fields);
  }

  Future<String> readAll() {
    return _enqueue(() async {
      try {
        final file = await _fileResolver();
        final rotated = File('${file.path}.1');
        final parts = <String>[];
        if (await rotated.exists()) {
          parts.add(await rotated.readAsString());
        }
        if (await file.exists()) {
          parts.add(await file.readAsString());
        }
        return parts.where((part) => part.trim().isNotEmpty).join('\n');
      } catch (_) {
        throw const AppException(
          AppErrorCode.storageFailure,
          '无法读取诊断日志。',
        );
      }
    });
  }

  Future<void> flush() => _pending;

  Future<void> _write(
    AppLogLevel level,
    String category,
    String event,
    Map<String, Object?> fields,
  ) async {
    try {
      await _enqueue(() async {
        final file = await _fileResolver();
        await _rotateIfNeeded(file);
        final entry = <String, Object?>{
          'time': DateTime.now().toUtc().toIso8601String(),
          'level': level.name.toUpperCase(),
          'category': redact(category),
          'event': redact(event),
          for (final field in fields.entries)
            if (!_isSensitiveField(field.key))
              redact(field.key): _safeValue(field.value),
        };
        await file.writeAsString(
          '${jsonEncode(entry)}\n',
          mode: FileMode.append,
          flush: true,
        );
      });
    } catch (_) {
      // Logging must never replace the original application error.
    }
  }

  Future<void> _rotateIfNeeded(File file) async {
    if (!await file.exists() || await file.length() < maxFileBytes) {
      return;
    }
    final rotated = File('${file.path}.1');
    if (await rotated.exists()) {
      await rotated.delete();
    }
    await file.rename(rotated.path);
  }

  Object? _safeValue(Object? value) {
    if (value == null || value is bool || value is num) {
      return value;
    }
    return redact(value.toString());
  }

  static bool _isSensitiveField(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized == 'apikey' ||
        normalized == 'authorization' ||
        normalized == 'token' ||
        normalized == 'password' ||
        normalized == 'body' ||
        normalized == 'requestbody' ||
        normalized == 'input' ||
        normalized == 'text' ||
        normalized == 'audio' ||
        normalized == 'file';
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final queued = _pending.then((_) => action());
    _pending = queued.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return queued;
  }

  static String redact(
    String input, {
    Iterable<String> sensitiveValues = const [],
    int maxLength = 500,
  }) {
    var result = input.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    for (final secret in sensitiveValues) {
      final value = secret.trim();
      if (value.isNotEmpty) {
        result = result.replaceAll(value, '[REDACTED]');
      }
    }
    result = result
        .replaceAll(
          RegExp(r'Bearer\s+[^\s,;]+', caseSensitive: false),
          'Bearer [REDACTED]',
        )
        .replaceAll(
          RegExp(r'sk-[A-Za-z0-9_-]{6,}'),
          '[REDACTED]',
        )
        .replaceAll(
          RegExp(
            r'(api[_ -]?key|authorization)\s*[:=]\s*[^\s,;]+',
            caseSensitive: false,
          ),
          r'$1=[REDACTED]',
        );
    if (result.length > maxLength) {
      return '${result.substring(0, maxLength)}…';
    }
    return result;
  }
}
