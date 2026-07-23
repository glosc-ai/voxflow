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
    final normalizedModel = model.trim();
    if (normalizedModel.isEmpty) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        'TTS 模型不能为空。',
      );
    }
    if (!AppConstants.ttsVoicesForModel(normalizedModel).contains(voice)) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        '所选音色不适用于当前 TTS 模型。',
      );
    }
    if (speed < 0.25 || speed > 4.0) {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        '语速必须在 0.25 到 4.0 之间。',
      );
    }
    if (responseFormat != 'mp3') {
      throw const AppException(
        AppErrorCode.invalidConfiguration,
        '当前仅支持 MP3 输出格式。',
      );
    }
    return TtsRequest(
      text: normalizedText,
      model: normalizedModel,
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
      if (speed != 1.0) 'speed': speed,
    };
  }
}
