import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/dio_client.dart';
import '../../settings/models/settings_state.dart';
import '../models/transcription_result.dart';
import 'audio_file_validator.dart';
import 'audio_normalization_service.dart';
import 'seed_asr_pcm_wav.dart';
import 'transcription_service.dart';

typedef SeedAsrSocketConnector =
    Future<SeedAsrSocket> Function(Uri uri, Map<String, String> headers);

abstract interface class SeedAsrSocket {
  void send(List<int> bytes);

  Future<Object?> receive(Duration timeout);

  Future<void> close();
}

class SeedAsrApiService implements TranscriptionService {
  SeedAsrApiService(
    DioClient client, {
    AudioFileValidator validator = const AudioFileValidator(),
    AudioNormalizationService? normalizer,
    SeedAsrSocketConnector? connect,
    this.chunkInterval = const Duration(milliseconds: 200),
    this.connectTimeout = const Duration(seconds: 30),
    this.initialResponseTimeout = const Duration(seconds: 15),
    this.finalResponseTimeout = const Duration(seconds: 15),
  }) : _client = client,
       _validator = validator,
       _normalizer =
           normalizer ??
           FfmpegAudioNormalizationService(eventLogger: client.logger),
       _connect = connect ?? _connectSocket;

  static const _endpointPath = '/api/v3/plan/sauc/bigmodel_nostream';
  static const _chunkBytes = 6400;

  final DioClient _client;
  final AudioFileValidator _validator;
  final AudioNormalizationService _normalizer;
  final SeedAsrSocketConnector _connect;
  final Duration chunkInterval;
  final Duration connectTimeout;
  final Duration initialResponseTimeout;
  final Duration finalResponseTimeout;

  static bool supportsModel(String model) {
    final normalized = model.trim().toLowerCase();
    return normalized == 'bytedance/volc.seedasr.sauc.duration' ||
        normalized.startsWith('bytedance/volc.seedasr.');
  }

  @override
  Future<TranscriptionResult> transcribe(
    File file, {
    UploadProgressCallback? onUploadProgress,
  }) async {
    final settings = _client.settings.validated();
    await _validator.validate(file);
    return _normalizer.withSeedAsrAudio(
      file,
      (_, normalizedAudio) =>
          _transcribeNormalized(normalizedAudio, settings, onUploadProgress),
    );
  }

  Future<TranscriptionResult> _transcribeNormalized(
    SeedAsrPcmWavAudio audio,
    SettingsState settings,
    UploadProgressCallback? onUploadProgress,
  ) async {
    final endpoint = _webSocketEndpoint(settings.baseUrl);
    final model = settings.sttModel;
    final requestId = _uuidV4();
    final headers = <String, String>{
      'X-Api-Key': settings.apiKey,
      'X-Api-Resource-Id': _resourceId(model),
      'X-Api-Request-Id': requestId,
      'X-Api-Connect-Id': requestId,
      'X-Api-Sequence': '-1',
      'User-Agent': 'VoxFlow/1.0',
    };
    SeedAsrSocket? socket;
    unawaited(
      _client.logger.info(
        'network',
        'request_started',
        fields: {
          'method': 'WEBSOCKET',
          'host': endpoint.host,
          'path': endpoint.path,
          'model': model,
          'transport': 'volc_binary_websocket',
        },
      ),
    );

    try {
      final connection = _connect(endpoint, headers);
      try {
        socket = await connection.timeout(connectTimeout);
      } on TimeoutException {
        unawaited(
          connection.then<void>(
            (lateSocket) => lateSocket.close(),
            onError: (_, __) {},
          ),
        );
        rethrow;
      }
      var sequence = 1;
      socket.send(
        _encodeMessage(
          messageType: 0x01,
          flags: 0x01,
          sequence: sequence,
          payload: utf8.encode(jsonEncode(_initialRequest(requestId))),
        ),
      );

      final initialRaw = await socket.receive(initialResponseTimeout);
      if (initialRaw == null) {
        throw const AppException(
          AppErrorCode.serviceUnavailable,
          'SeedASR 未返回初始化响应。',
          englishMessage: 'SeedASR did not return an initialization response.',
        );
      }
      final initialResponse = _decodeResponse(
        initialRaw,
        sensitiveValues: [settings.apiKey],
      );
      final receiver = _receiveUntilFinal(
        socket,
        initialResponse,
        sensitiveValues: [settings.apiKey],
      );
      Object? receiverError;
      StackTrace? receiverStack;
      final receiverFailed = Completer<void>();
      unawaited(
        receiver.then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            receiverError = error;
            receiverStack = stack;
            if (!receiverFailed.isCompleted) {
              receiverFailed.complete();
            }
          },
        ),
      );

      void throwIfReceiverFailed() {
        final error = receiverError;
        final stack = receiverStack;
        if (error != null && stack != null) {
          Error.throwWithStackTrace(error, stack);
        }
      }

      sequence++;
      for (var offset = 0; offset < audio.bytes.length;) {
        throwIfReceiverFailed();
        final end = min(offset + _chunkBytes, audio.bytes.length);
        final isLast = end == audio.bytes.length;
        socket.send(
          _encodeMessage(
            messageType: 0x02,
            flags: isLast ? 0x03 : 0x01,
            sequence: isLast ? -sequence : sequence,
            payload: audio.bytes.sublist(offset, end),
          ),
        );
        onUploadProgress?.call(end / audio.bytes.length);
        offset = end;
        if (!isLast) {
          sequence++;
          if (chunkInterval > Duration.zero) {
            await Future.any<void>([
              Future<void>.delayed(chunkInterval),
              receiverFailed.future,
            ]);
            throwIfReceiverFailed();
          }
        }
      }

      throwIfReceiverFailed();
      final outcome = await receiver.timeout(finalResponseTimeout);

      final text = outcome.text.trim();
      if (text.isEmpty) {
        throw const AppException(
          AppErrorCode.serviceUnavailable,
          'SeedASR 未返回转写文字。',
          englishMessage: 'SeedASR returned no transcribed text.',
        );
      }
      unawaited(
        _client.logger.info(
          'network',
          'request_completed',
          fields: {
            'method': 'WEBSOCKET',
            'host': endpoint.host,
            'path': endpoint.path,
            'model': model,
            'transport': 'volc_binary_websocket',
            'final_received': outcome.finalReceived,
          },
        ),
      );
      return TranscriptionResult(
        text: text,
        segments: const [],
        duration: audio.duration,
      );
    } on AppException catch (error) {
      _logFailure(endpoint, model, error.message, settings.apiKey);
      rethrow;
    } on TimeoutException {
      const error = AppException(
        AppErrorCode.networkTimeout,
        'SeedASR 请求超时，请检查网络后重试。',
        englishMessage:
            'The SeedASR request timed out. Check the network and try again.',
      );
      _logFailure(endpoint, model, error.message, settings.apiKey);
      throw error;
    } on SocketException catch (error) {
      final detail = AppLogger.redact(
        error.message,
        sensitiveValues: [settings.apiKey],
        maxLength: 240,
      );
      final mapped = AppException(
        AppErrorCode.serviceUnavailable,
        '无法连接 SeedASR 服务。',
        englishMessage: 'Unable to connect to the SeedASR service.',
        technicalDetail: detail,
      );
      _logFailure(endpoint, model, mapped.message, settings.apiKey);
      throw mapped;
    } on WebSocketException catch (error) {
      final detail = AppLogger.redact(
        error.message,
        sensitiveValues: [settings.apiKey],
        maxLength: 240,
      );
      final mapped = AppException(
        AppErrorCode.serviceUnavailable,
        'SeedASR WebSocket 连接失败。',
        englishMessage: 'The SeedASR WebSocket connection failed.',
        technicalDetail: detail,
      );
      _logFailure(endpoint, model, mapped.message, settings.apiKey);
      throw mapped;
    } catch (error) {
      final reason = AppLogger.redact(
        error.toString(),
        sensitiveValues: [settings.apiKey],
        maxLength: 240,
      );
      final mapped = AppException(
        AppErrorCode.serviceUnavailable,
        'SeedASR 转写失败。',
        englishMessage: 'SeedASR transcription failed.',
        technicalDetail: reason,
      );
      _logFailure(endpoint, model, mapped.message, settings.apiKey);
      throw mapped;
    } finally {
      try {
        await socket?.close();
      } catch (_) {
        // The request outcome is already known; closing is best-effort.
      }
    }
  }

  void _logFailure(Uri endpoint, String model, String reason, String apiKey) {
    unawaited(
      _client.logger.error(
        'network',
        'request_failed',
        fields: {
          'method': 'WEBSOCKET',
          'host': endpoint.host,
          'path': endpoint.path,
          'model': model,
          'transport': 'volc_binary_websocket',
          'reason': AppLogger.redact(
            reason,
            sensitiveValues: [apiKey],
            maxLength: 300,
          ),
        },
      ),
    );
  }

  static Uri _webSocketEndpoint(String baseUrl) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: _endpointPath,
      query: null,
      fragment: null,
    );
  }

  static String _resourceId(String model) {
    final slash = model.lastIndexOf('/');
    return slash >= 0 ? model.substring(slash + 1) : model;
  }

  static Map<String, Object?> _initialRequest(String requestId) {
    return {
      'user': {'uid': 'voxflow-${requestId.substring(0, 12)}'},
      'audio': {
        'format': 'wav',
        'codec': 'raw',
        'rate': 16000,
        'bits': 16,
        'channel': 1,
      },
      'request': {
        'model_name': 'bigmodel',
        'enable_itn': true,
        'enable_punc': true,
        'enable_ddc': true,
        'enable_nonstream': false,
        'show_utterances': true,
        'result_type': 'full',
      },
    };
  }

  static Uint8List _encodeMessage({
    required int messageType,
    required int flags,
    required int sequence,
    required List<int> payload,
  }) {
    final compressed = gzip.encode(payload);
    final builder = BytesBuilder(copy: false)
      ..add([0x11, (messageType << 4) | (flags & 0x0f), 0x11, 0x00])
      ..add(_int32(sequence))
      ..add(_uint32(compressed.length))
      ..add(compressed);
    return builder.takeBytes();
  }

  static Future<_SeedAsrOutcome> _receiveUntilFinal(
    SeedAsrSocket socket,
    _SeedAsrResponse initial, {
    required Iterable<String> sensitiveValues,
  }) async {
    var latestText = initial.text;
    var finalReceived = initial.isFinal;
    while (!finalReceived) {
      final raw = await socket.receive(const Duration(days: 1));
      if (raw == null) {
        break;
      }
      final response = _decodeResponse(raw, sensitiveValues: sensitiveValues);
      if (response.text.isNotEmpty) {
        latestText = response.text;
      }
      finalReceived = response.isFinal;
    }
    return _SeedAsrOutcome(finalReceived: finalReceived, text: latestText);
  }

  static _SeedAsrResponse _decodeResponse(
    Object raw, {
    Iterable<String> sensitiveValues = const [],
  }) {
    if (raw is! List<int>) {
      throw const AppException(
        AppErrorCode.serviceUnavailable,
        'SeedASR 返回了非二进制响应。',
        englishMessage: 'SeedASR returned a non-binary response.',
      );
    }
    final bytes = Uint8List.fromList(raw);
    if (bytes.length < 8) {
      throw const AppException(
        AppErrorCode.serviceUnavailable,
        'SeedASR 返回了无效的短响应。',
        englishMessage: 'SeedASR returned an invalid short response.',
      );
    }
    final headerSize = (bytes[0] & 0x0f) * 4;
    final messageType = (bytes[1] >> 4) & 0x0f;
    final flags = bytes[1] & 0x0f;
    final serialization = (bytes[2] >> 4) & 0x0f;
    final compression = bytes[2] & 0x0f;
    if (headerSize < 4 || bytes.length < headerSize) {
      throw const AppException(
        AppErrorCode.serviceUnavailable,
        'SeedASR 响应头无效。',
        englishMessage: 'The SeedASR response header is invalid.',
      );
    }
    var offset = headerSize;
    if (flags & 0x01 != 0) {
      _requireLength(bytes, offset, 4);
      offset += 4;
    }
    if (flags & 0x04 != 0) {
      _requireLength(bytes, offset, 4);
      offset += 4;
    }
    final isFinal = flags & 0x02 != 0;

    if (messageType == 0x0f) {
      _requireLength(bytes, offset, 8);
      final data = ByteData.sublistView(bytes);
      final errorCode = data.getInt32(offset, Endian.big);
      final payloadLength = data.getUint32(offset + 4, Endian.big);
      offset += 8;
      final payload = _payload(bytes, offset, payloadLength, compression);
      final detail = utf8.decode(payload, allowMalformed: true).trim();
      if (errorCode == 0 && detail.isEmpty) {
        return const _SeedAsrResponse(isFinal: true, text: '');
      }
      final safeDetail = AppLogger.redact(
        detail,
        sensitiveValues: sensitiveValues,
        maxLength: 240,
      );
      throw AppException(
        AppErrorCode.serviceUnavailable,
        'SeedASR 服务错误 $errorCode。',
        englishMessage: 'SeedASR service error $errorCode.',
        technicalDetail: safeDetail.isEmpty ? null : safeDetail,
      );
    }

    _requireLength(bytes, offset, 4);
    final payloadLength = ByteData.sublistView(
      bytes,
    ).getUint32(offset, Endian.big);
    offset += 4;
    final payload = _payload(bytes, offset, payloadLength, compression);
    if (serialization != 0x01 || payload.isEmpty) {
      return _SeedAsrResponse(isFinal: isFinal, text: '');
    }
    final decoded = jsonDecode(utf8.decode(payload));
    return _SeedAsrResponse(isFinal: isFinal, text: _extractText(decoded));
  }

  static List<int> _payload(
    Uint8List bytes,
    int offset,
    int payloadLength,
    int compression,
  ) {
    _requireLength(bytes, offset, payloadLength);
    final payload = bytes.sublist(offset, offset + payloadLength);
    return compression == 0x01 ? gzip.decode(payload) : payload;
  }

  static void _requireLength(Uint8List bytes, int offset, int length) {
    if (offset < 0 || length < 0 || offset + length > bytes.length) {
      throw const AppException(
        AppErrorCode.serviceUnavailable,
        'SeedASR 响应负载不完整。',
        englishMessage: 'The SeedASR response payload is incomplete.',
      );
    }
  }

  static String _extractText(Object? decoded) {
    if (decoded is! Map) {
      return '';
    }
    final result = decoded['result'];
    if (result is! Map) {
      return '';
    }
    final fullText = result['text'];
    if (fullText is String && fullText.trim().isNotEmpty) {
      return fullText.trim();
    }
    final utterances = result['utterances'];
    if (utterances is! List) {
      return '';
    }
    return utterances
        .whereType<Map>()
        .where((item) => item['definite'] == true)
        .map((item) => item['text'])
        .whereType<String>()
        .join()
        .trim();
  }
}

class _SeedAsrResponse {
  const _SeedAsrResponse({required this.isFinal, required this.text});

  final bool isFinal;
  final String text;
}

class _SeedAsrOutcome {
  const _SeedAsrOutcome({required this.finalReceived, required this.text});

  final bool finalReceived;
  final String text;
}

class _IoSeedAsrSocket implements SeedAsrSocket {
  _IoSeedAsrSocket(this._socket) : _events = StreamIterator<Object?>(_socket);

  final WebSocket _socket;
  final StreamIterator<Object?> _events;
  bool _closed = false;

  @override
  void send(List<int> bytes) => _socket.add(bytes);

  @override
  Future<Object?> receive(Duration timeout) async {
    final hasEvent = await _events.moveNext().timeout(timeout);
    return hasEvent ? _events.current : null;
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _events.cancel();
    await _socket.close();
  }
}

Future<SeedAsrSocket> _connectSocket(
  Uri uri,
  Map<String, String> headers,
) async {
  final socket = await WebSocket.connect(uri.toString(), headers: headers);
  return _IoSeedAsrSocket(socket);
}

Uint8List _int32(int value) {
  final data = ByteData(4)..setInt32(0, value, Endian.big);
  return data.buffer.asUint8List();
}

Uint8List _uint32(int value) {
  final data = ByteData(4)..setUint32(0, value, Endian.big);
  return data.buffer.asUint8List();
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
  final joined = hex.join();
  return '${joined.substring(0, 8)}-'
      '${joined.substring(8, 12)}-'
      '${joined.substring(12, 16)}-'
      '${joined.substring(16, 20)}-'
      '${joined.substring(20)}';
}
