import 'dart:async';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final attempts = arguments.isEmpty ? 10 : int.tryParse(arguments.first);
  if (attempts == null || attempts < 1 || attempts > 100) {
    stderr.writeln('Usage: dart tool/github_network_probe.dart [1-100]');
    exitCode = 64;
    return;
  }

  final target = Uri.https('github.com', '/');
  var failures = 0;

  for (var attempt = 1; attempt <= attempts; attempt++) {
    final stopwatch = Stopwatch()..start();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'VoxFlow diagnostic probe';
    try {
      final request = await client
          .headUrl(target)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final remoteAddress =
          response.connectionInfo?.remoteAddress.address ?? 'unknown-address';
      await response.drain<void>().timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 400) {
        failures++;
        stdout.writeln(
          '[probe] $attempt/$attempts failed: HTTP ${response.statusCode} '
          'via $remoteAddress (${stopwatch.elapsedMilliseconds} ms)',
        );
      } else {
        stdout.writeln(
          '[probe] $attempt/$attempts passed: HTTP ${response.statusCode} '
          'via $remoteAddress (${stopwatch.elapsedMilliseconds} ms)',
        );
      }
    } on Object catch (error) {
      failures++;
      stdout.writeln(
        '[probe] $attempt/$attempts failed: '
        '${error.runtimeType}: $error '
        '(${stopwatch.elapsedMilliseconds} ms)',
      );
    } finally {
      client.close(force: true);
    }
  }

  stdout.writeln('[probe] failures: $failures/$attempts');
  if (failures > 0) {
    exitCode = 1;
  }
}
