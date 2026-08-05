import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/core/services/external_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ai.glosc.voxflow/external_links/v1');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses the fixed platform contract for an HTTPS URL', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return null;
        });

    await const ExternalLinkService().open(' https://www.glosc.ai/keys ');

    expect(receivedCall?.method, 'open');
    expect(receivedCall?.arguments, {'url': 'https://www.glosc.ai/keys'});
  });

  test('rejects every URL outside the fixed HTTPS allowlist', () async {
    var callCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          callCount += 1;
          return null;
        });
    const service = ExternalLinkService();

    for (final url in [
      'http://www.glosc.ai/keys',
      'www.glosc.ai/keys',
      'https:///keys',
      'https://example.com/keys',
      'https://www.glosc.ai/other',
      'https://www.glosc.ai/keys?source=app',
    ]) {
      await expectLater(
        service.open(url),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            AppErrorCode.invalidConfiguration,
          ),
        ),
      );
    }

    expect(callCount, 0);
  });

  test(
    'maps platform failures without exposing native error details',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'cannot_open_url',
              message: 'sentinel-native-detail',
              details: 'sentinel-native-detail',
            );
          });

      await expectLater(
        const ExternalLinkService().open('https://www.glosc.ai/keys'),
        throwsA(
          isA<AppException>()
              .having(
                (error) => error.code,
                'code',
                AppErrorCode.serviceUnavailable,
              )
              .having(
                (error) => error.toString(),
                'message',
                isNot(contains('sentinel-native-detail')),
              ),
        ),
      );
    },
  );

  test('maps native URL validation to invalid configuration', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'invalid_url');
        });

    await expectLater(
      const ExternalLinkService().open('https://www.glosc.ai/keys'),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          AppErrorCode.invalidConfiguration,
        ),
      ),
    );
  });
}
