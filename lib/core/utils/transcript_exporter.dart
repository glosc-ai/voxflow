import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../features/stt/models/transcription_result.dart';
import '../errors/app_exception.dart';

class TranscriptExporter {
  TranscriptExporter._();

  static String toText(String text) => text.trim();

  static String ensureExtension(String filePath, String extension) {
    final normalizedExtension =
        extension.startsWith('.') ? extension.substring(1) : extension;
    if (normalizedExtension.isEmpty) {
      return filePath;
    }
    final suffix = '.$normalizedExtension';
    return filePath.toLowerCase().endsWith(suffix.toLowerCase())
        ? filePath
        : '$filePath$suffix';
  }

  static String toSrt(TranscriptionResult result) {
    if (!result.hasSegments) {
      throw const AppException(
        AppErrorCode.invalidFile,
        '当前转录没有时间戳片段，无法导出 SRT。',
      );
    }
    final buffer = StringBuffer();
    for (var index = 0; index < result.segments.length; index++) {
      final segment = result.segments[index];
      buffer
        ..writeln(index + 1)
        ..writeln('${_timestamp(segment.start)} --> ${_timestamp(segment.end)}')
        ..writeln(segment.text)
        ..writeln();
    }
    return buffer.toString().trimRight();
  }

  static Future<bool> saveText({
    required String contents,
    required String extension,
  }) async {
    try {
      final bytes = utf8.encode(contents);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出转录结果',
        fileName: 'voxflow_${DateTime.now().millisecondsSinceEpoch}.$extension',
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: Platform.isAndroid ? bytes : null,
      );
      if (path == null) {
        return false;
      }
      if (!Platform.isAndroid) {
        final outputPath = ensureExtension(path, extension);
        await File(outputPath).writeAsBytes(bytes, flush: true);
      }
      return true;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '导出文件失败，请重新选择保存位置。',
      );
    }
  }

  static String _timestamp(Duration duration) {
    final totalMilliseconds = duration.inMilliseconds.clamp(0, 359999999);
    final hours = totalMilliseconds ~/ Duration.millisecondsPerHour;
    final minutes = (totalMilliseconds % Duration.millisecondsPerHour) ~/
        Duration.millisecondsPerMinute;
    final seconds = (totalMilliseconds % Duration.millisecondsPerMinute) ~/
        Duration.millisecondsPerSecond;
    final milliseconds = totalMilliseconds % Duration.millisecondsPerSecond;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')},'
        '${milliseconds.toString().padLeft(3, '0')}';
  }
}
