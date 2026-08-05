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

  test('Android Release 从 APK 证书 DER 计算签名指纹', () {
    final workflow = File(
      '${Directory.current.path}${Platform.pathSeparator}.github'
      '${Platform.pathSeparator}workflows${Platform.pathSeparator}release.yml',
    ).readAsStringSync();
    final androidJob = workflow.substring(
      workflow.indexOf('  build_android:'),
      workflow.indexOf('  build_windows:'),
    );

    expect(androidJob, contains('verify --print-certs-pem'));
    expect(androidJob, contains('openssl x509 -inform PEM -outform DER'));
    expect(androidJob, contains("grep -c '^-----BEGIN CERTIFICATE-----\$'"));
    expect(androidJob, contains('Expected exactly one signing certificate'));
    expect(androidJob, contains('Actual certificate SHA-256'));
    expect(
      androidJob,
      isNot(contains("sed -n 's/^Signer #1 certificate SHA-256 digest: //p'")),
    );
  });
}
