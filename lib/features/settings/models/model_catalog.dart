class ModelCatalog {
  static final RegExp _asrModelToken = RegExp(
    r'(^|[^a-z0-9])(?:seed)?asr($|[^a-z0-9])',
  );

  const ModelCatalog({
    required this.all,
    required this.stt,
    required this.tts,
  });

  final List<String> all;
  final List<String> stt;
  final List<String> tts;

  factory ModelCatalog.fromIds(Iterable<String> ids) {
    final all = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ModelCatalog(
      all: List.unmodifiable(all),
      stt: List.unmodifiable(all.where(_isSttModel)),
      tts: List.unmodifiable(all.where(_isTtsModel)),
    );
  }

  static bool _isSttModel(String id) {
    final normalized = id.toLowerCase();
    return normalized.contains('whisper') ||
        normalized.contains('transcrib') ||
        normalized.contains('speech-to-text') ||
        normalized.contains('speech_to_text') ||
        normalized.contains('-stt') ||
        normalized.startsWith('stt-') ||
        _asrModelToken.hasMatch(normalized);
  }

  static bool _isTtsModel(String id) {
    final normalized = id.toLowerCase();
    return normalized.contains('tts') ||
        normalized.contains('text-to-speech') ||
        normalized.contains('text_to_speech') ||
        normalized.contains('speech-synthesis') ||
        normalized.contains('speech_synthesis');
  }
}
