import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxflow/bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('安全凭据损坏时可在启动页清除凭据并恢复进入应用', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('ai.glosc.voxflow/secure_credentials/v1');
    var corrupt = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'readApiKey':
              if (corrupt) {
                throw PlatformException(code: 'secure_storage_corrupt');
              }
              return null;
            case 'deleteApiKey':
              corrupt = false;
              return null;
            case 'writeApiKey':
              return null;
          }
          throw PlatformException(code: 'not_implemented');
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(const VoxFlowBootstrap());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('bootstrapClearCredentialButton')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('bootstrapClearCredentialButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('bootstrapClearCredentialConfirmButton')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('bootstrapClearCredentialConfirmButton')),
    );
    await tester.pumpAndSettle();

    expect(corrupt, isFalse);
    expect(
      find.byKey(const Key('bootstrapClearCredentialButton')),
      findsNothing,
    );
    expect(find.byKey(const Key('privacyNoticeAcceptButton')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
