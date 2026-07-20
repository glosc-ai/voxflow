import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/utils/path_utils.dart';

void main() {
  test('识别受管目录内路径并拒绝相似前缀', () {
    final separator = Platform.pathSeparator;
    final root = '${Directory.current.path}${separator}managed';
    final inside = '$root${separator}stt${separator}audio.wav';
    final outside = '${root}_other${separator}audio.wav';

    expect(PathUtils.isPathWithin(root, inside), isTrue);
    expect(PathUtils.isPathWithin(root, outside), isFalse);
  });

  test('安全解析文件扩展名', () {
    expect(PathUtils.extensionOf('voice.MP3'), 'mp3');
    expect(PathUtils.extensionOf('voice'), isEmpty);
  });
}
