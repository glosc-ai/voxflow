import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformClock {
  PlatformClock._();

  static const _channel = MethodChannel('ai.glosc.voxflow/window');

  static Future<DateTime> nowUtc() async {
    if (defaultTargetPlatform != TargetPlatform.windows) {
      return DateTime.now().toUtc();
    }
    try {
      final microseconds = await _channel.invokeMethod<int>(
        'nowUtcMicroseconds',
      );
      if (microseconds != null) {
        return DateTime.fromMicrosecondsSinceEpoch(microseconds, isUtc: true);
      }
    } on MissingPluginException {
      // Unit tests and non-runner hosts use the Dart clock fallback.
    } on PlatformException {
      // Keep recording usable if the optional native clock is unavailable.
    }
    return DateTime.now().toUtc();
  }
}
