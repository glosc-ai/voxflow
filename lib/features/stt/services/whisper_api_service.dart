import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../models/transcription_result.dart';
import 'audio_file_validator.dart';
import 'seed_asr_api_service.dart';
import 'transcription_service.dart';

class WhisperApiService implements TranscriptionService {
  WhisperApiService(
    DioClient client, {
    AudioFileValidator validator = const AudioFileValidator(),
    TranscriptionService? seedAsrService,
  }) : _client = client,
       _validator = validator,
       _seedAsrService =
           seedAsrService ?? SeedAsrApiService(client, validator: validator);

  final DioClient _client;
  final AudioFileValidator _validator;
  final TranscriptionService _seedAsrService;

  @override
  Future<TranscriptionResult> transcribe(
    File file, {
    UploadProgressCallback? onUploadProgress,
  }) async {
    final settings = _client.settings.validated();
    if (SeedAsrApiService.supportsModel(settings.sttModel)) {
      return _seedAsrService.transcribe(
        file,
        onUploadProgress: onUploadProgress,
      );
    }
    await _validator.validate(file);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'model': settings.sttModel,
        'response_format': 'verbose_json',
        'timestamp_granularities[]': 'segment',
      });
      final response = await _client.dio.post<Object?>(
        _client.endpoint('audio/transcriptions', requestSettings: settings),
        data: formData,
        options: _client.requestOptions(settings, model: settings.sttModel),
        onSendProgress: (sent, total) {
          if (total > 0) {
            onUploadProgress?.call((sent / total).clamp(0, 1));
          }
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const AppException(
          AppErrorCode.serviceUnavailable,
          '转录服务返回了无法识别的数据。',
          englishMessage:
              'The transcription service returned an unrecognized response.',
        );
      }
      final json = data.map((key, value) => MapEntry(key.toString(), value));
      final result = TranscriptionResult.fromJson(json);
      if (result.text.isEmpty) {
        throw const AppException(
          AppErrorCode.serviceUnavailable,
          '转录服务未返回文字。',
          englishMessage: 'The transcription service returned no text.',
        );
      }
      return result;
    } on DioException catch (error) {
      throw DioClient.mapException(error);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        AppErrorCode.unknown,
        '音频转录失败，请稍后重试。',
        englishMessage: 'Audio transcription failed. Try again later.',
      );
    }
  }
}
