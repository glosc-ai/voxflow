import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows Release 使用当前插件兼容的固定 runner', () {
    final workflow = File(
      '${Directory.current.path}${Platform.pathSeparator}.github'
      '${Platform.pathSeparator}workflows${Platform.pathSeparator}release.yml',
    ).readAsStringSync();
    final windowsJob = workflow.substring(
      workflow.indexOf('  build_windows:'),
      workflow.indexOf('  publish:'),
    );

    expect(windowsJob, contains('runs-on: windows-2022'));
    expect(windowsJob, isNot(contains('runs-on: windows-latest')));
  });

  test('依赖锁文件使用 CI 可复现的官方 hosted 地址', () {
    final lockFile = File(
      '${Directory.current.path}${Platform.pathSeparator}pubspec.lock',
    ).readAsStringSync();

    expect(lockFile, isNot(contains('https://pub.flutter-io.cn')));
    expect(lockFile, contains('https://pub.dev'));
  });

  test('Release 所有 Flutter 作业都强制使用依赖锁文件', () {
    final workflow = File(
      '${Directory.current.path}${Platform.pathSeparator}.github'
      '${Platform.pathSeparator}workflows${Platform.pathSeparator}release.yml',
    ).readAsStringSync();

    expect(
      RegExp(
        r'run: flutter pub get --enforce-lockfile',
      ).allMatches(workflow).length,
      3,
    );
    expect(workflow, isNot(contains('run: flutter pub get\n')));
  });
}
