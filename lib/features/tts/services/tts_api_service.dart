import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/path_utils.dart';
import '../models/tts_request.dart';

typedef AudioBytesWriter = Future<File> Function(Uint8List bytes);

class TtsApiService {
  TtsApiService(
    this._client, {
    AudioBytesWriter? writer,
  }) : _writer = writer ??
            ((bytes) => PathUtils.writeManagedAudio(
                  bytes,
                  category: 'tts',
                  extension: 'mp3',
                ));

  final DioClient _client;
  final AudioBytesWriter _writer;

  Future<File> synthesize(TtsRequest request) async {
    final settings = _client.settings.validated();
    final validRequest = request.validated();
    try {
      final response = await _client.dio.post<List<int>>(
        _client.endpoint(
          'audio/speech',
          requestSettings: settings,
        ),
        data: validRequest.toJson(),
        options: _client.requestOptions(
          settings,
          model: validRequest.model,
          responseType: ResponseType.bytes,
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const AppException(
          AppErrorCode.serviceUnavailable,
          '语音服务未返回音频。',
          englishMessage: 'The speech service returned no audio.',
        );
      }
      return _writer(Uint8List.fromList(bytes));
    } on DioException catch (error) {
      throw DioClient.mapException(error);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.unknown,
        '语音合成失败，请稍后重试。',
        englishMessage: 'Speech synthesis failed. Try again later.',
      );
    }
  }
}
