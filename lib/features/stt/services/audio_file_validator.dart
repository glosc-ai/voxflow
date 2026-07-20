import 'dart:io';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/path_utils.dart';

class AudioFileValidator {
  const AudioFileValidator();

  Future<void> validate(File file) async {
    try {
      if (!await file.exists()) {
        throw const AppException(
          AppErrorCode.fileNotFound,
          '所选音频文件不存在。',
        );
      }
      final extension = PathUtils.extensionOf(file.path);
      if (!AppConstants.supportedImportExtensions.contains(extension)) {
        throw const AppException(
          AppErrorCode.invalidFile,
          '不支持此文件格式，请选择 MP3、MP4、MPEG、MPGA、M4A、WAV 或 WEBM。',
        );
      }
      if (await file.length() > AppConstants.maxTranscriptionBytes) {
        throw const AppException(
          AppErrorCode.fileTooLarge,
          '音频文件不能超过 25 MB。',
        );
      }
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.invalidFile,
        '无法读取所选音频文件。',
      );
    }
  }
}
