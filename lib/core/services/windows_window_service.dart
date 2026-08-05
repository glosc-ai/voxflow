import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowsWindowService {
  WindowsWindowService._();

  static const MethodChannel _channel = MethodChannel(
    'ai.glosc.voxflow/window',
  );

  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.windows;

  static Future<void> enableFrameless() => _invokeVoid('enableFrameless');

  static Future<void> minimize() => _invokeVoid('minimize');

  static Future<void> maximizeOrRestore() => _invokeVoid('maximizeOrRestore');

  static Future<void> close() => _invokeVoid('close');

  static Future<void> startDrag() => _invokeVoid('startDrag');

  static Future<void> setBrightness(Brightness brightness) =>
      _invokeVoid('setBrightness', brightness.name);

  static Future<bool> isMaximized() async {
    if (!isSupported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isMaximized') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<String?> version() async {
    if (!isSupported) {
      return null;
    }
    try {
      final version = await _channel.invokeMethod<String>('getVersion');
      final normalized = version?.trim();
      if (normalized == null || normalized.isEmpty) {
        return null;
      }
      return normalized.split('+').first;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> _invokeVoid(String method, [Object? arguments]) async {
    if (!isSupported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Widget tests and non-Windows hosts intentionally have no native bridge.
    } on PlatformException {
      // Window chrome must remain usable even if an optional native call fails.
    }
  }
}
