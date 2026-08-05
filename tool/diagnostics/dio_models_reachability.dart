import 'dart:io';

import 'package:dio/dio.dart';

const _target = 'https://one.gloscai.com/v1/models';
const _writeReport = bool.fromEnvironment('probe.writeReport');

final _reportLines = <String>[];

Future<void> main(List<String> arguments) async {
  final attempts = arguments.isEmpty ? 3 : int.tryParse(arguments.single);
  if (attempts == null || attempts < 1 || attempts > 20) {
    stderr.writeln(
      'Usage: dart run tool/diagnostics/dio_models_reachability.dart [1-20]',
    );
    exitCode = 64;
    return;
  }

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(minutes: 5),
      headers: const {'Accept': 'application/json'},
    ),
  );

  var failures = 0;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await dio.get<Object?>(_target);
      _emit(
        '[dio-models-probe] $attempt/$attempts reachable: '
        'HTTP ${response.statusCode ?? 'unknown'} '
        '(${stopwatch.elapsedMilliseconds} ms)',
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        // Authentication and other HTTP failures still prove that Dart/Dio
        // completed DNS, TCP and TLS and reached the configured API service.
        _emit(
          '[dio-models-probe] $attempt/$attempts reachable: '
          'HTTP $statusCode (${stopwatch.elapsedMilliseconds} ms)',
        );
        continue;
      }

      failures++;
      final cause = _singleLine(
        error.error ?? error.message ?? error.type.name,
      );
      _emit(
        '[dio-models-probe] $attempt/$attempts unreachable: '
        '${error.type.name}; $cause '
        '(${stopwatch.elapsedMilliseconds} ms)',
      );
    } on Object catch (error) {
      failures++;
      _emit(
        '[dio-models-probe] $attempt/$attempts unreachable: '
        '${error.runtimeType}; ${_singleLine(error)} '
        '(${stopwatch.elapsedMilliseconds} ms)',
      );
    }
  }

  dio.close(force: true);
  _emit(
    '[dio-models-probe] verdict: '
    '${failures == 0 ? 'REACHABLE' : 'UNREACHABLE'} '
    '($failures/$attempts transport failures)',
  );
  if (failures > 0) {
    exitCode = 1;
  }

  if (_writeReport) {
    final executable = File(Platform.resolvedExecutable);
    final report = File(
      '${executable.parent.path}${Platform.pathSeparator}'
      'dio_models_reachability.result.txt',
    );
    await report.writeAsString('${_reportLines.join('\n')}\n', flush: true);
  }
}

void _emit(String line) {
  _reportLines.add(line);
  stdout.writeln(line);
}

String _singleLine(Object value) {
  final text = value.toString().replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
  return text.length <= 500 ? text : '${text.substring(0, 500)}...';
}
