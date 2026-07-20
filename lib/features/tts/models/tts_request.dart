import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';

class TtsRequest {
  const TtsRequest({
    required this.text,
    required this.model,
    required this.voice,
    required this.speed,
    this.responseFormat = 'mp3',
  });

  final String text;
  final String model;
  final String voice;
  final double speed;
  final String responseFormat;

  TtsRequest validated() {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        '请输入要合成的文字。',
      );
    }
    if (normalizedText.length > AppConstants.maxTtsCharacters) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        '文字不能超过 4096 个字符。',
      );
    }
    if (!AppConstants.voices.contains(voice)) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        '请选择有效的音色。',
      );
    }
    if (speed < 0.25 || speed > 4.0) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        '语速必须在 0.25 到 4.0 之间。',
      );
    }
    if (model.trim().isEmpty) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        'TTS 模型不能为空。',
      );
    }
    return TtsRequest(
      text: normalizedText,
      model: model.trim(),
      voice: voice,
      speed: speed,
      responseFormat: responseFormat,
    );
  }

  Map<String, Object> toJson() {
    return {
      'model': model,
      'input': text,
      'voice': voice,
      'speed': speed,
      'response_format': responseFormat,
    };
  }
}
