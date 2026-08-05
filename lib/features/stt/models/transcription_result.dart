class TranscriptionSegment {
  const TranscriptionSegment({
    this.id,
    required this.start,
    required this.end,
    required this.text,
  });

  final int? id;
  final Duration start;
  final Duration end;
  final String text;

  factory TranscriptionSegment.fromJson(Map<String, Object?> json) {
    return TranscriptionSegment(
      id: (json['id'] as num?)?.toInt(),
      start: _durationFromSeconds(json['start']),
      end: _durationFromSeconds(json['end']),
      text: (json['text'] as String? ?? '').trim(),
    );
  }

  static Duration _durationFromSeconds(Object? value) {
    final seconds = value is num ? value.toDouble() : 0.0;
    return Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    );
  }
}

class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    required this.segments,
    this.duration,
    this.sourcePath,
  });

  final String text;
  final List<TranscriptionSegment> segments;
  final Duration? duration;
  final String? sourcePath;

  bool get hasSegments => segments.isNotEmpty;

  TranscriptionResult copyWith({
    String? text,
    List<TranscriptionSegment>? segments,
    Duration? duration,
    String? sourcePath,
  }) {
    return TranscriptionResult(
      text: text ?? this.text,
      segments: segments ?? this.segments,
      duration: duration ?? this.duration,
      sourcePath: sourcePath ?? this.sourcePath,
    );
  }

  factory TranscriptionResult.fromJson(Map<String, Object?> json) {
    final rawSegments = json['segments'];
    final segments = rawSegments is List
        ? rawSegments
              .whereType<Map>()
              .map(
                (item) => TranscriptionSegment.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false)
        : const <TranscriptionSegment>[];
    final durationValue = json['duration'];
    return TranscriptionResult(
      text: (json['text'] as String? ?? '').trim(),
      segments: segments,
      duration: durationValue is num
          ? Duration(
              microseconds:
                  (durationValue.toDouble() * Duration.microsecondsPerSecond)
                      .round(),
            )
          : null,
    );
  }
}
