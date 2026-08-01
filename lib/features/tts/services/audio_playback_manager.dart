import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import '../../../core/errors/app_exception.dart';

abstract interface class PlaybackController {
  Stream<Duration> get positionChanges;
  Stream<Duration> get durationChanges;
  Stream<void> get completions;

  Future<void> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
}

class AudioPlaybackManager implements PlaybackController {
  AudioPlaybackManager({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  String? _path;

  @override
  Stream<Duration> get positionChanges => _player.onPositionChanged;

  @override
  Stream<Duration> get durationChanges => _player.onDurationChanged;

  @override
  Stream<void> get completions => _player.onPlayerComplete;

  @override
  Future<void> load(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw const AppException(
          AppErrorCode.fileNotFound,
          '音频文件不存在。',
          englishMessage: 'The audio file could not be found.',
        );
      }
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSource(DeviceFileSource(path));
      _path = path;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.playbackFailed,
        '无法加载音频文件。',
        englishMessage: 'Unable to load the audio file.',
      );
    }
  }

  @override
  Future<void> play() async {
    if (_path == null) {
      throw const AppException(
        AppErrorCode.playbackFailed,
        '请先生成或选择音频。',
        englishMessage: 'Generate or select audio first.',
      );
    }
    try {
      await _player.resume();
    } catch (_) {
      throw const AppException(
        AppErrorCode.playbackFailed,
        '播放音频失败。',
        englishMessage: 'Unable to play the audio.',
      );
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {
      throw const AppException(
        AppErrorCode.playbackFailed,
        '暂停播放失败。',
        englishMessage: 'Unable to pause playback.',
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {
      throw const AppException(
        AppErrorCode.playbackFailed,
        '停止播放失败。',
        englishMessage: 'Unable to stop playback.',
      );
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (_) {
      throw const AppException(
        AppErrorCode.playbackFailed,
        '调整播放进度失败。',
        englishMessage: 'Unable to seek in the audio.',
      );
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0, 1));
    } catch (_) {
      throw const AppException(
        AppErrorCode.playbackFailed,
        '调整音量失败。',
        englishMessage: 'Unable to change the volume.',
      );
    }
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {
      // Player disposal is best-effort during provider shutdown.
    }
  }
}
