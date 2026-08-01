import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voxflow/core/errors/app_exception.dart';
import 'package:voxflow/core/logging/app_logger.dart';
import 'package:voxflow/core/network/dio_client.dart';
import 'package:voxflow/features/settings/models/settings_state.dart';
import 'package:voxflow/features/stt/services/seed_asr_api_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('voxflow_seed_asr_');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('SeedASR 使用文档约定的 WebSocket 头和二进制帧', () async {
    final socket = _FakeSeedAsrSocket([
      _responseFrame({
        'result': {'text': ''}
      }),
      _responseFrame(
        {
          'result': {'text': 'seed result'},
        },
        isFinal: true,
      ),
    ]);
    Uri? connectedUri;
    Map<String, String>? connectedHeaders;
    final settings = _seedSettings();
    final logger = AppLogger(
      fileResolver: () async => File('${directory.path}/voxflow.log'),
    );
    final service = SeedAsrApiService(
      DioClient(settings, logger: logger),
      connect: (uri, headers) async {
        connectedUri = uri;
        connectedHeaders = Map.of(headers);
        return socket;
      },
      chunkInterval: Duration.zero,
    );
    final input = File('${directory.path}/sample.wav');
    await input.writeAsBytes(_pcmWav(dataBytes: 12800));
    final progress = <double>[];

    final result = await service.transcribe(
      input,
      onUploadProgress: progress.add,
    );

    expect(result.text, 'seed result');
    expect(result.segments, isEmpty);
    expect(result.duration, const Duration(milliseconds: 400));
    expect(connectedUri?.scheme, 'wss');
    expect(
      connectedUri?.path,
      '/api/v3/plan/sauc/bigmodel_nostream',
    );
    expect(
      connectedHeaders?['X-Api-Resource-Id'],
      'volc.seedasr.sauc.duration',
    );
    expect(connectedHeaders?['X-Api-Key'], 'test-key');
    expect(connectedHeaders, isNot(contains('Authorization')));
    expect(socket.sent, hasLength(4));
    expect(socket.sent.first[0], 0x11);
    expect(socket.sent.first[1], 0x11);
    expect(socket.sent.last[1], 0x23);
    expect(_sequenceOf(socket.sent.last), isNegative);
    expect(_requestJson(socket.sent.first), {
      'user': isA<Map>(),
      'audio': {
        'format': 'wav',
        'codec': 'raw',
        'rate': 16000,
        'bits': 16,
        'channel': 1,
      },
      'request': containsPair('model_name', 'bigmodel'),
    });
    expect(progress.last, 1);
    expect(socket.closed, isTrue);
    final firstReceive = socket.events.indexOf('receive');
    final secondReceive = socket.events.indexOf('receive', firstReceive + 1);
    final firstAudioSend = socket.events.indexOf('send', 1);
    expect(secondReceive, lessThan(firstAudioSend));
  });

  test('SeedASR 拒绝无法直接流式发送的非 PCM WAV', () async {
    var connectCalls = 0;
    final settings = _seedSettings();
    final service = SeedAsrApiService(
      DioClient(settings),
      connect: (uri, headers) async {
        connectCalls++;
        return _FakeSeedAsrSocket(const []);
      },
    );
    final input = File('${directory.path}/sample.mp3');
    await input.writeAsBytes([1, 2, 3]);

    await expectLater(
      service.transcribe(input),
      throwsA(
        isA<AppException>()
            .having(
              (error) => error.code,
              'code',
              AppErrorCode.invalidFile,
            )
            .having(
              (error) => error.message,
              'message',
              contains('PCM WAV'),
            ),
      ),
    );
    expect(connectCalls, 0);
  });

  test('SeedASR 服务端错误不会在界面异常中回显自定义密钥', () async {
    const customKey = 'plain-custom-key';
    final socket = _FakeSeedAsrSocket([
      _errorFrame(45000001, 'rejected $customKey'),
    ]);
    const settings = SettingsState(
      apiKey: customKey,
      baseUrl: 'https://one.gloscai.com/v1',
      sttModel: 'bytedance/volc.seedasr.sauc.duration',
      ttsModel: 'bytedance/seed-tts-2.0',
    );
    final service = SeedAsrApiService(
      DioClient(settings),
      connect: (uri, headers) async => socket,
      chunkInterval: Duration.zero,
    );
    final input = File('${directory.path}/sample.wav');
    await input.writeAsBytes(_pcmWav(dataBytes: 3200));

    late AppException exception;
    try {
      await service.transcribe(input);
      fail('Expected SeedASR to reject the request.');
    } on AppException catch (error) {
      exception = error;
    }

    expect(exception.message, isNot(contains(customKey)));
    expect(exception.message, contains('SeedASR'));
    expect(exception.technicalDetail, contains('[REDACTED]'));
    expect(
        exception.englishMessage, contains('SeedASR service error 45000001.'));
    expect(exception.englishMessage, contains('Service response:'));
    expect(exception.englishMessage, isNot(contains(customKey)));
  });

  test('SeedASR 连接超时后关闭晚完成的 WebSocket', () async {
    final connection = Completer<SeedAsrSocket>();
    final socket = _FakeSeedAsrSocket(const []);
    final service = SeedAsrApiService(
      DioClient(_seedSettings()),
      connect: (uri, headers) => connection.future,
      connectTimeout: const Duration(milliseconds: 10),
    );
    final input = File('${directory.path}/sample.wav');
    await input.writeAsBytes(_pcmWav(dataBytes: 3200));

    await expectLater(
      service.transcribe(input),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          AppErrorCode.networkTimeout,
        ),
      ),
    );
    connection.complete(socket);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(socket.closed, isTrue);
  });
}

SettingsState _seedSettings() {
  return const SettingsState(
    apiKey: 'test-key',
    baseUrl: 'https://one.gloscai.com/v1',
    sttModel: 'bytedance/volc.seedasr.sauc.duration',
    ttsModel: 'bytedance/seed-tts-2.0',
  );
}

class _FakeSeedAsrSocket implements SeedAsrSocket {
  _FakeSeedAsrSocket(Iterable<Object?> responses)
      : responses = Queue.of(responses);

  final Queue<Object?> responses;
  final List<Uint8List> sent = [];
  final List<String> events = [];
  bool closed = false;

  @override
  void send(List<int> bytes) {
    events.add('send');
    sent.add(Uint8List.fromList(bytes));
  }

  @override
  Future<Object?> receive(Duration timeout) async {
    events.add('receive');
    return responses.isEmpty ? null : responses.removeFirst();
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

Uint8List _pcmWav({required int dataBytes}) {
  final bytes = Uint8List(44 + dataBytes);
  final data = ByteData.sublistView(bytes);
  void writeAscii(int offset, String value) {
    bytes.setRange(offset, offset + value.length, ascii.encode(value));
  }

  writeAscii(0, 'RIFF');
  data.setUint32(4, 36 + dataBytes, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  data.setUint32(40, dataBytes, Endian.little);
  return bytes;
}

Uint8List _responseFrame(
  Map<String, Object?> payload, {
  bool isFinal = false,
}) {
  final compressed = gzip.encode(utf8.encode(jsonEncode(payload)));
  final bytes = BytesBuilder(copy: false)
    ..add([0x11, 0x90 | (isFinal ? 0x03 : 0x01), 0x11, 0x00])
    ..add(_int32(1))
    ..add(_uint32(compressed.length))
    ..add(compressed);
  return bytes.takeBytes();
}

Uint8List _errorFrame(int code, String message) {
  final compressed = gzip.encode(utf8.encode(message));
  final bytes = BytesBuilder(copy: false)
    ..add([0x11, 0xf0, 0x11, 0x00])
    ..add(_int32(code))
    ..add(_uint32(compressed.length))
    ..add(compressed);
  return bytes.takeBytes();
}

int _sequenceOf(Uint8List frame) {
  return ByteData.sublistView(frame, 4, 8).getInt32(0, Endian.big);
}

Map<String, Object?> _requestJson(Uint8List frame) {
  final data = ByteData.sublistView(frame);
  final payloadLength = data.getUint32(8, Endian.big);
  final compressed = frame.sublist(12, 12 + payloadLength);
  final decoded = jsonDecode(utf8.decode(gzip.decode(compressed)));
  return (decoded as Map).map(
    (key, value) => MapEntry(key.toString(), value),
  );
}

Uint8List _int32(int value) {
  final data = ByteData(4)..setInt32(0, value, Endian.big);
  return data.buffer.asUint8List();
}

Uint8List _uint32(int value) {
  final data = ByteData(4)..setUint32(0, value, Endian.big);
  return data.buffer.asUint8List();
}
