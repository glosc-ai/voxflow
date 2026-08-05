import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../errors/app_exception.dart';

typedef DirectoryProvider = Future<Directory> Function();

class PathUtils {
  PathUtils._();

  static final RegExp _voxFlowTemporaryAudioPattern = RegExp(
    r'^(?:voxflow_[a-zA-Z0-9_-]+_[0-9]+\.[a-z0-9]+(?:\.part)?|recording_[0-9]+\.(?:wav|m4a)|seed_asr_normalized_[0-9]+\.wav(?:\.part)?)$',
  );

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
        englishMessage: 'Unable to create the application audio directory.',
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
        englishMessage: 'Unable to create the local database directory.',
      );
    }
  }

  static Future<File> getLogFile() async {
    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory(_join([support.path, 'VoxFlow', 'logs']));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return File(_join([directory.path, 'voxflow.log']));
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法访问应用日志目录。',
        englishMessage: 'Unable to access the application log directory.',
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
        'voxflow_${_safeName(stem)}_${DateTime.now().microsecondsSinceEpoch}.${_safeExtension(extension)}',
      ]);
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法访问系统临时目录。',
        englishMessage: 'Unable to access the system temporary directory.',
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
          englishMessage: 'The audio file could not be found.',
        );
      }
      final directory = await getManagedAudioDirectory(category);
      final extension = extensionOf(source.path).isEmpty
          ? 'bin'
          : extensionOf(source.path);
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
        englishMessage: 'Unable to save the audio file.',
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
        _join([directory.path, '$baseName.${_safeExtension(extension)}']),
      );
      await temporaryFile.writeAsBytes(bytes, flush: true);
      return temporaryFile.rename(destination.path);
    } catch (_) {
      if (temporaryFile != null && await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法写入音频文件。',
        englishMessage: 'Unable to write the audio file.',
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

  /// Deletes only audio under VoxFlow's application-managed audio root.
  ///
  /// The documents directory itself and sibling user files are never scanned
  /// or removed. Links encountered below the managed root are deleted as links
  /// rather than followed.
  static Future<void> clearManagedAudio({
    DirectoryProvider? documentsDirectoryProvider,
  }) async {
    try {
      final documents =
          await (documentsDirectoryProvider ??
              getApplicationDocumentsDirectory)();
      final audioRoot = _join([documents.path, 'VoxFlow', 'audio']);
      await _deleteEntryWithoutFollowingLinks(audioRoot);
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法清理应用管理的音频文件。',
        englishMessage: 'Unable to clear application-managed audio files.',
      );
    }
  }

  /// Removes VoxFlow-owned temporary audio while preserving all other files.
  ///
  /// New files use the `voxflow_` namespace. The two exact legacy patterns
  /// cover recordings and SeedASR normalization files created by older builds.
  static Future<void> clearVoxFlowTemporaryFiles({
    DirectoryProvider? temporaryDirectoryProvider,
  }) async {
    try {
      final temporary =
          await (temporaryDirectoryProvider ?? getTemporaryDirectory)();
      if (!await temporary.exists()) {
        return;
      }

      var deletionFailed = false;
      await for (final entity in temporary.list(followLinks: false)) {
        final name = _fileName(entity.path);
        if (!_voxFlowTemporaryAudioPattern.hasMatch(name)) {
          continue;
        }
        try {
          final type = await FileSystemEntity.type(
            entity.path,
            followLinks: false,
          );
          if (type == FileSystemEntityType.file) {
            await File(entity.path).delete();
          } else if (type == FileSystemEntityType.link) {
            await Link(entity.path).delete();
          }
        } catch (_) {
          deletionFailed = true;
        }
      }
      if (deletionFailed) {
        throw const FileSystemException(
          'One or more VoxFlow temporary files could not be deleted.',
        );
      }
    } catch (_) {
      throw const AppException(
        AppErrorCode.storageFailure,
        '无法清理应用临时音频文件。',
        englishMessage: 'Unable to clear temporary application audio files.',
      );
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

  static Future<void> _deleteEntryWithoutFollowingLinks(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return;
    }
    if (type == FileSystemEntityType.link) {
      await Link(path).delete();
      return;
    }
    if (type == FileSystemEntityType.file) {
      await File(path).delete();
      return;
    }
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException('Unsupported managed entry type.', path);
    }

    final directory = Directory(path);
    await for (final entity in directory.list(followLinks: false)) {
      await _deleteEntryWithoutFollowingLinks(entity.path);
    }
    await directory.delete();
  }

  static String _fileName(String path) {
    final separator = path.lastIndexOf(Platform.pathSeparator);
    return separator < 0 ? path : path.substring(separator + 1);
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
