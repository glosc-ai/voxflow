enum HistoryType {
  stt,
  tts;

  String get label => this == HistoryType.stt ? '语音转文字' : '文字转语音';

  static HistoryType fromStorage(String value) {
    return value == HistoryType.tts.name ? HistoryType.tts : HistoryType.stt;
  }
}

class HistoryRecord {
  const HistoryRecord({
    this.id,
    required this.type,
    required this.text,
    required this.audioPath,
    required this.createdAt,
  });

  final int? id;
  final HistoryType type;
  final String text;
  final String audioPath;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type.name,
      'text': text,
      'audio_path': audioPath,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
    };
  }

  factory HistoryRecord.fromMap(Map<String, Object?> map) {
    return HistoryRecord(
      id: map['id'] as int?,
      type: HistoryType.fromStorage(map['type'] as String? ?? ''),
      text: map['text'] as String? ?? '',
      audioPath: map['audio_path'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? 0,
        isUtc: true,
      ),
    );
  }
}
