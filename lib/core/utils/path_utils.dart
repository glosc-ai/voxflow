import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../errors/app_exception.dart';

class PathUtils {
  PathUtils._();

  static Future<Directory> getManagedAudioDirectory(String category) async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory(
        _join([documents.path, 'VoxFlow', 'audio', _safeName(category)]),
      );
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法创建应用音频目录。',
      );
    }
  }

  static Future<String> getDatabasePath() async {
    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory(_join([support.path, 'VoxFlow']));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return _join([directory.path, 'voxflow.db']);
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法创建本地数据库目录。',
      );
    }
  }

  static Future<String> temporaryAudioPath({
    required String stem,
    required String extension,
  }) async {
    try {
      final temporary = await getTemporaryDirectory();
      return _join([
        temporary.path,
        '${_safeName(stem)}_${DateTime.now().microsecondsSinceEpoch}.${_safeExtension(extension)}',
      ]);
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法访问系统临时目录。',
      );
    }
  }

  static Future<File> persistManagedAudio(
    File source, {
    required String category,
  }) async {
    try {
      if (!await source.exists()) {
        throw const AppException(
          AppErrorCode.fileNotFound,
          '音频文件不存在。',
        );
      }
      final directory = await getManagedAudioDirectory(category);
      final extension =
          extensionOf(source.path).isEmpty ? 'bin' : extensionOf(source.path);
      final destination = File(
        _join([
          directory.path,
          '${_safeName(category)}_${DateTime.now().microsecondsSinceEpoch}.$extension',
        ]),
      );
      return source.copy(destination.path);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法保存音频文件。',
      );
    }
  }

  static Future<File> writeManagedAudio(
    Uint8List bytes, {
    required String category,
    required String extension,
  }) async {
    File? temporaryFile;
    try {
      final directory = await getManagedAudioDirectory(category);
      final baseName =
          '${_safeName(category)}_${DateTime.now().microsecondsSinceEpoch}';
      temporaryFile = File(_join([directory.path, '$baseName.part']));
      final destination = File(
          _join([directory.path, '$baseName.${_safeExtension(extension)}']));
      await temporaryFile.writeAsBytes(bytes, flush: true);
      return temporaryFile.rename(destination.path);
    } catch (_) {
      if (temporaryFile != null && await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法写入音频文件。',
      );
    }
  }

  static Future<bool> isManagedAudioPath(String path) async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      final root = Directory(_join([documents.path, 'VoxFlow', 'audio']));
      return isPathWithin(root.path, path);
    } catch (_) {
      return false;
    }
  }

  static bool isPathWithin(String root, String candidate) {
    var normalizedRoot = Directory(root).absolute.path;
    var normalizedCandidate = File(candidate).absolute.path;
    if (Platform.isWindows) {
      normalizedRoot = normalizedRoot.toLowerCase();
      normalizedCandidate = normalizedCandidate.toLowerCase();
    }
    final prefix = normalizedRoot.endsWith(Platform.pathSeparator)
        ? normalizedRoot
        : '$normalizedRoot${Platform.pathSeparator}';
    return normalizedCandidate.startsWith(prefix);
  }

  static String extensionOf(String path) {
    final fileName = File(path).uri.pathSegments.last;
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) {
      return '';
    }
    return _safeExtension(fileName.substring(dot + 1));
  }

  static String _join(List<String> parts) => parts.join(Platform.pathSeparator);

  static String _safeName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return sanitized.isEmpty ? 'audio' : sanitized;
  }

  static String _safeExtension(String value) {
    final sanitized = value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    return sanitized.isEmpty ? 'bin' : sanitized;
  }
}
