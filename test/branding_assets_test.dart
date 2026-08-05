import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Android and Windows app icons use the white equalizer brand mark',
    () async {
      final androidBytes = await File(
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      ).readAsBytes();
      await _expectWhiteCenter(androidBytes, 'Android launcher icon');

      final windowsBytes = await File(
        'windows/runner/resources/app_icon.ico',
      ).readAsBytes();
      await _expectWhiteCenter(
        _largestPngFromIco(windowsBytes),
        'Windows application icon',
      );
    },
  );
}

Future<void> _expectWhiteCenter(Uint8List encoded, String reason) async {
  final image = await ui
      .instantiateImageCodec(encoded)
      .then((codec) => codec.getNextFrame().then((frame) => frame.image));
  final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(pixels, isNotNull, reason: '$reason must decode as RGBA');
  final offset = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
  final red = pixels!.getUint8(offset);
  final green = pixels.getUint8(offset + 1);
  final blue = pixels.getUint8(offset + 2);
  final alpha = pixels.getUint8(offset + 3);
  image.dispose();

  expect(
    (red, green, blue, alpha),
    predicate<(int, int, int, int)>(
      (color) =>
          color.$1 >= 235 &&
          color.$2 >= 235 &&
          color.$3 >= 235 &&
          color.$4 >= 235,
      'an opaque white center pixel',
    ),
    reason: '$reason should match the navigation equalizer mark',
  );
}

Uint8List _largestPngFromIco(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  expect(data.getUint16(0, Endian.little), 0);
  expect(data.getUint16(2, Endian.little), 1);
  final count = data.getUint16(4, Endian.little);
  var selectedWidth = -1;
  var selectedOffset = -1;
  var selectedSize = -1;
  for (var index = 0; index < count; index++) {
    final entry = 6 + index * 16;
    final width = bytes[entry] == 0 ? 256 : bytes[entry];
    final size = data.getUint32(entry + 8, Endian.little);
    final offset = data.getUint32(entry + 12, Endian.little);
    if (width > selectedWidth &&
        offset + size <= bytes.length &&
        bytes[offset] == 0x89 &&
        bytes[offset + 1] == 0x50) {
      selectedWidth = width;
      selectedOffset = offset;
      selectedSize = size;
    }
  }
  expect(selectedOffset, isNonNegative, reason: 'ICO must contain a PNG frame');
  return Uint8List.sublistView(
    bytes,
    selectedOffset,
    selectedOffset + selectedSize,
  );
}
