import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../errors/app_exception.dart';
import 'app_logger.dart';

class DiagnosticLogExporter {
  const DiagnosticLogExporter(this._logger);

  final AppLogger _logger;

  Future<bool> export() async {
    try {
      final contents = await _logger.readAll();
      final bytes = utf8.encode(contents);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出 VoxFlow 诊断日志',
        fileName: 'voxflow_log_${DateTime.now().millisecondsSinceEpoch}.jsonl',
        type: FileType.custom,
        allowedExtensions: const ['jsonl'],
        bytes: Platform.isAndroid ? bytes : null,
      );
      if (path == null) {
        return false;
      }
      if (!Platform.isAndroid) {
        await File(path).writeAsBytes(bytes, flush: true);
      }
      return true;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '导出诊断日志失败，请重新选择保存位置。',
      );
    }
  }
}
