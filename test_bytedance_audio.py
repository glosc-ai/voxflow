#!/usr/bin/env python3
"""Test ByteDance TTS and streaming SeedASR through one.gloscai.com.

TTS uses the OpenAI-compatible endpoint. SeedASR follows the official binary
WebSocket example: gzip-compressed, sequenced request frames and WAV chunks.
"""

import argparse
import gzip
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import uuid
import wave
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional, Tuple
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


DEFAULT_BASE_URL = "https://one.gloscai.com"
DEFAULT_TTS_MODEL = "bytedance/seed-tts-2.0"
DEFAULT_ASR_MODEL = "bytedance/volc.seedasr.sauc.duration"
DEFAULT_ASR_RESOURCE_ID = "volc.seedasr.sauc.duration"
DEFAULT_ASR_WS_URL = "wss://one.gloscai.com/api/v3/plan/sauc/bigmodel_nostream"
DEFAULT_VOICE = "zh_female_cancan_uranus_bigtts"
DEFAULT_TEXT = "你好，这是一段语音模型连通性测试。"
USER_AGENT = "bytedance-audio-connectivity-test/1.0"
ASR_SAMPLE_RATE = 16000
ASR_SAMPLE_WIDTH = 2
ASR_CHANNELS = 1


class ApiError(Exception):
    def __init__(
        self,
        message: str,
        *,
        status: Optional[int] = None,
        code: Optional[str] = None,
        body: Optional[str] = None,
    ) -> None:
        super().__init__(message)
        self.status = status
        self.code = code
        self.body = body


def load_dotenv(path: Path) -> None:
    """Load uncomplicated .env entries without adding a dependency."""
    if not path.is_file():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if value[:1] == value[-1:] and value[:1] in {"'", '"'}:
            value = value[1:-1]
        if key:
            os.environ.setdefault(key, value)


def decode_json(body: bytes) -> Optional[Any]:
    try:
        return json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None


def error_details(body: bytes, fallback: str) -> Tuple[str, Optional[str]]:
    parsed = decode_json(body)
    if isinstance(parsed, dict):
        error = parsed.get("error")
        if isinstance(error, dict):
            message = error.get("message")
            code = error.get("code")
            return str(message or fallback), str(code) if code else None
        message = parsed.get("message")
        if message:
            return str(message), None
    text = body.decode("utf-8", errors="replace").strip()
    return text[:4000] or fallback, None


def api_request(
    url: str,
    token: str,
    *,
    data: Optional[bytes] = None,
    content_type: Optional[str] = None,
    accept: str = "application/json",
    timeout: float = 180,
) -> Tuple[bytes, str, int, float]:
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": accept,
        "User-Agent": USER_AGENT,
    }
    if content_type:
        headers["Content-Type"] = content_type

    request = Request(
        url,
        data=data,
        headers=headers,
        method="POST" if data is not None else "GET",
    )
    started = time.monotonic()
    try:
        with urlopen(request, timeout=timeout) as response:
            body = response.read()
            elapsed = time.monotonic() - started
            return (
                body,
                response.headers.get("Content-Type", ""),
                response.status,
                elapsed,
            )
    except HTTPError as error:
        body = error.read()
        message, code = error_details(body, f"HTTP {error.code} {error.reason}")
        raise ApiError(
            message,
            status=error.code,
            code=code,
            body=body.decode("utf-8", errors="replace")[:4000],
        ) from error
    except (URLError, TimeoutError, OSError) as error:
        reason = getattr(error, "reason", error)
        raise ApiError(f"请求失败：{reason}") from error


def list_models(
    base_url: str, token: str, wanted: set, timeout: float
) -> Dict[str, Any]:
    body, content_type, status, elapsed = api_request(
        f"{base_url}/v1/models", token, timeout=timeout
    )
    parsed = decode_json(body)
    if not isinstance(parsed, dict) or not isinstance(parsed.get("data"), list):
        raise ApiError("模型列表接口没有返回预期的 JSON 数据")

    models = [item for item in parsed["data"] if isinstance(item, dict)]
    matches = {
        item.get("id"): item for item in models if item.get("id") in wanted
    }
    return {
        "ok": wanted.issubset(matches),
        "http_status": status,
        "content_type": content_type,
        "elapsed_seconds": round(elapsed, 3),
        "models_returned": len(models),
        "found": sorted(matches),
        "missing": sorted(wanted.difference(matches)),
        "details": matches,
    }


def test_tts(
    base_url: str,
    token: str,
    model: str,
    voice: str,
    text: str,
    output_file: Path,
    timeout: float,
) -> Dict[str, Any]:
    payload = {
        "model": model,
        "input": text,
        "voice": voice,
        "response_format": "mp3",
    }
    body, content_type, status, elapsed = api_request(
        f"{base_url}/v1/audio/speech",
        token,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        content_type="application/json",
        accept="audio/mpeg,application/octet-stream,application/json",
        timeout=timeout,
    )

    if "json" in content_type.lower() or isinstance(decode_json(body), dict):
        message, code = error_details(body, "TTS 返回了 JSON，而不是音频")
        raise ApiError(message, status=status, code=code)
    if not body:
        raise ApiError("TTS 返回了空音频", status=status)

    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_bytes(body)
    return {
        "ok": True,
        "model": model,
        "voice": voice,
        "http_status": status,
        "content_type": content_type,
        "elapsed_seconds": round(elapsed, 3),
        "bytes": len(body),
        "output_file": str(output_file.resolve()),
    }


def volc_message(
    message_type: int,
    flags: int,
    serialization: int,
    sequence: int,
    payload: bytes,
) -> bytes:
    """Encode one official gzip-compressed, sequenced ASR request."""
    compressed_payload = gzip.compress(payload)
    header = bytes(
        [
            0x11,  # protocol version 1, header size 4 bytes
            (message_type << 4) | (flags & 0x0F),
            (serialization << 4) | 0x01,  # gzip
            0x00,
        ]
    )
    return (
        header
        + struct.pack(">i", sequence)
        + struct.pack(">I", len(compressed_payload))
        + compressed_payload
    )


def volc_full_client_request(uid: str, sequence: int) -> bytes:
    payload = {
        "user": {"uid": uid},
        "audio": {
            "format": "wav",
            "codec": "raw",
            "rate": ASR_SAMPLE_RATE,
            "bits": ASR_SAMPLE_WIDTH * 8,
            "channel": ASR_CHANNELS,
        },
        "request": {
            "model_name": "bigmodel",
            "enable_itn": True,
            "enable_punc": True,
            "enable_ddc": True,
            "enable_nonstream": False,
            "show_utterances": True,
            "result_type": "full",
            "end_window_size": 3000,
        },
    }
    return volc_message(
        message_type=0x01,
        flags=0x01,
        serialization=0x01,
        sequence=sequence,
        payload=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
    )


def volc_audio_message(audio: bytes, sequence: int, is_last: bool) -> bytes:
    wire_sequence = -sequence if is_last else sequence
    return volc_message(
        message_type=0x02,
        flags=0x03 if is_last else 0x01,
        serialization=0x01,
        sequence=wire_sequence,
        payload=audio,
    )


def volc_decode_response(message: bytes) -> Dict[str, Any]:
    if len(message) < 8:
        raise ApiError("ASR WebSocket 返回了过短的二进制消息")

    header_size = (message[0] & 0x0F) * 4
    message_type = (message[1] >> 4) & 0x0F
    flags = message[1] & 0x0F
    serialization = (message[2] >> 4) & 0x0F
    compression = message[2] & 0x0F
    offset = header_size

    if flags & 0x01:
        if len(message) < offset + 4:
            raise ApiError("ASR WebSocket 响应缺少 sequence")
        offset += 4

    if flags & 0x04:
        if len(message) < offset + 4:
            raise ApiError("ASR WebSocket 响应缺少 event")
        offset += 4

    is_final = bool(flags & 0x02)
    if message_type == 0x0F:
        if len(message) < offset + 8:
            raise ApiError("ASR WebSocket 返回了无效错误消息")
        error_code = struct.unpack(">i", message[offset : offset + 4])[0]
        payload_size = struct.unpack(">I", message[offset + 4 : offset + 8])[0]
        payload = message[offset + 8 : offset + 8 + payload_size]
        if compression == 0x01 and payload:
            payload = gzip.decompress(payload)
        detail = payload.decode("utf-8", errors="replace").strip()
        if error_code == 0 and not detail:
            return {"is_final": True, "data": None}
        raise ApiError(
            f"火山 ASR 错误 {error_code}：{detail or '无错误详情'}",
            code=str(error_code),
        )

    if len(message) < offset + 4:
        raise ApiError("ASR WebSocket 响应缺少 payload size")
    payload_size = struct.unpack(">I", message[offset : offset + 4])[0]
    payload = message[offset + 4 : offset + 4 + payload_size]
    if len(payload) != payload_size:
        raise ApiError("ASR WebSocket 响应 payload 不完整")
    if compression == 0x01 and payload:
        payload = gzip.decompress(payload)

    data: Optional[Any] = None
    if serialization == 0x01 and payload:
        try:
            data = json.loads(payload.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ApiError(f"ASR WebSocket JSON 解析失败：{error}") from error
    return {"is_final": is_final, "data": data}


def extract_stream_text(data: Any) -> Tuple[str, str]:
    if not isinstance(data, dict):
        return "", ""
    result = data.get("result")
    if not isinstance(result, dict):
        return "", ""

    full_text = result.get("text") if isinstance(result.get("text"), str) else ""
    utterances = result.get("utterances")
    definite = ""
    if isinstance(utterances, list):
        definite = "".join(
            item.get("text", "")
            for item in utterances
            if isinstance(item, dict)
            and item.get("definite")
            and isinstance(item.get("text"), str)
        )
    return full_text, definite


def read_compatible_wav(path: Path) -> Optional[bytes]:
    try:
        with wave.open(str(path), "rb") as audio:
            if (
                audio.getframerate() == ASR_SAMPLE_RATE
                and audio.getnchannels() == ASR_CHANNELS
                and audio.getsampwidth() == ASR_SAMPLE_WIDTH
                and audio.getcomptype() == "NONE"
            ):
                return path.read_bytes()
    except (wave.Error, EOFError):
        pass
    return None


def convert_to_wav(input_file: Path) -> bytes:
    """Return a 16 kHz, 16-bit, mono PCM WAV including its RIFF header."""
    if not input_file.is_file():
        raise ApiError(f"ASR 测试文件不存在：{input_file}")
    if input_file.stat().st_size == 0:
        raise ApiError(f"ASR 测试文件为空：{input_file}")

    wav_data = read_compatible_wav(input_file)
    if wav_data is not None:
        return wav_data

    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        command = [
            ffmpeg,
            "-v",
            "error",
            "-i",
            str(input_file),
            "-ar",
            str(ASR_SAMPLE_RATE),
            "-ac",
            str(ASR_CHANNELS),
            "-f",
            "wav",
            "-acodec",
            "pcm_s16le",
            "pipe:1",
        ]
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode == 0 and result.stdout:
            return result.stdout
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise ApiError(f"ffmpeg 转换 ASR 音频失败：{detail or result.returncode}")

    afconvert = shutil.which("afconvert")
    if afconvert:
        temporary_name: Optional[str] = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temporary:
                temporary_name = temporary.name
            result = subprocess.run(
                [
                    afconvert,
                    str(input_file),
                    temporary_name,
                    "-f",
                    "WAVE",
                    "-d",
                    f"LEI16@{ASR_SAMPLE_RATE}",
                    "-c",
                    str(ASR_CHANNELS),
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            if result.returncode != 0:
                detail = result.stderr.decode("utf-8", errors="replace").strip()
                raise ApiError(
                    f"afconvert 转换 ASR 音频失败：{detail or result.returncode}"
                )
            wav_data = read_compatible_wav(Path(temporary_name))
            if wav_data:
                return wav_data
            raise ApiError("afconvert 没有生成有效的 16 kHz PCM WAV")
        finally:
            if temporary_name:
                try:
                    Path(temporary_name).unlink()
                except FileNotFoundError:
                    pass

    raise ApiError(
        "ASR 输入必须是 16 kHz/16-bit/mono PCM WAV，"
        "或安装 ffmpeg（macOS 也可使用 afconvert）"
    )


def test_asr_streaming(
    ws_url: str,
    api_key: str,
    resource_id: str,
    model: str,
    input_file: Path,
    timeout: float,
    chunk_ms: int,
    realtime_factor: float,
) -> Dict[str, Any]:
    try:
        from websockets.sync.client import connect
    except ImportError as error:
        raise ApiError(
            "缺少 websockets；请运行：uv pip install --python .venv/bin/python -r requirements.txt"
        ) from error

    wav_data = convert_to_wav(input_file)
    if not wav_data:
        raise ApiError("ASR 音频转换后没有 WAV 数据")
    bytes_per_chunk = (
        ASR_SAMPLE_RATE * ASR_SAMPLE_WIDTH * ASR_CHANNELS * chunk_ms // 1000
    )
    if bytes_per_chunk <= 0:
        raise ApiError("--asr-chunk-ms 必须大于 0")

    request_id = str(uuid.uuid4())
    headers = {
        "X-Api-Key": api_key,
        "X-Api-Resource-Id": resource_id,
        "X-Api-Request-Id": request_id,
        "X-Api-Connect-Id": request_id,
        "X-Api-Sequence": "-1",
    }
    started = time.monotonic()
    events_received = 0
    latest_text = ""
    definite_text = ""
    final_received = False
    last_printed = ""

    try:
        with connect(
            ws_url,
            additional_headers=headers,
            open_timeout=min(timeout, 30),
            close_timeout=5,
            user_agent_header=USER_AGENT,
        ) as websocket:
            sequence = 1
            websocket.send(
                volc_full_client_request(f"test-{uuid.uuid4().hex[:12]}", sequence)
            )

            try:
                initial_message = websocket.recv(timeout=min(timeout, 15))
            except TimeoutError as error:
                raise ApiError("ASR 初始化响应超时") from error
            if not isinstance(initial_message, bytes):
                raise ApiError("ASR 初始化返回了非二进制消息")
            initial = volc_decode_response(initial_message)
            events_received += 1
            full, definite = extract_stream_text(initial.get("data"))
            latest_text = full or latest_text
            definite_text = definite or definite_text
            final_received = bool(initial.get("is_final"))

            sequence += 1
            chunk_count = (len(wav_data) + bytes_per_chunk - 1) // bytes_per_chunk
            for index in range(chunk_count):
                chunk_started = time.monotonic()
                start = index * bytes_per_chunk
                chunk = wav_data[start : start + bytes_per_chunk]
                is_last = index == chunk_count - 1
                websocket.send(volc_audio_message(chunk, sequence, is_last))
                if not is_last:
                    sequence += 1

                try:
                    message = websocket.recv(timeout=0.02)
                except TimeoutError:
                    message = None
                if isinstance(message, bytes):
                    decoded = volc_decode_response(message)
                    events_received += 1
                    full, definite = extract_stream_text(decoded.get("data"))
                    latest_text = full or latest_text
                    definite_text = definite or definite_text
                    final_received = final_received or bool(decoded.get("is_final"))
                    display = definite_text or latest_text
                    if display and display != last_printed:
                        print(f"  流式结果：{display}", flush=True)
                        last_printed = display

                if not is_last:
                    target_delay = chunk_ms / 1000 * realtime_factor
                    remaining = target_delay - (time.monotonic() - chunk_started)
                    if remaining > 0:
                        time.sleep(remaining)

            deadline = time.monotonic() + min(timeout, 15)
            while not final_received and time.monotonic() < deadline:
                try:
                    message = websocket.recv(
                        timeout=min(1.0, max(0.01, deadline - time.monotonic()))
                    )
                except TimeoutError:
                    continue
                if not isinstance(message, bytes):
                    continue
                decoded = volc_decode_response(message)
                events_received += 1
                full, definite = extract_stream_text(decoded.get("data"))
                latest_text = full or latest_text
                definite_text = definite or definite_text
                final_received = final_received or bool(decoded.get("is_final"))
                display = definite_text or latest_text
                if display and display != last_printed:
                    print(f"  流式结果：{display}", flush=True)
                    last_printed = display
    except ApiError:
        raise
    except Exception as error:
        response = getattr(error, "response", None)
        status = getattr(response, "status_code", None)
        if status == 404 and urlsplit(ws_url).hostname == "one.gloscai.com":
            raise ApiError(
                "GLOSC 网关未发布 SeedASR WebSocket 路由（HTTP 404）："
                "请让网关开放 /api/v3/plan/sauc/bigmodel_nostream，"
                "或通过 --asr-ws-url 指定网关提供的实际流式 ASR 地址",
                status=status,
                code="glosc_asr_route_not_found",
            ) from error
        if isinstance(status, int):
            raise ApiError(
                f"ASR WebSocket 握手失败：HTTP {status}", status=status
            ) from error
        raise ApiError(f"ASR WebSocket 请求失败：{error}") from error

    transcript = (latest_text or definite_text).strip()
    if not transcript:
        raise ApiError("ASR 流结束后没有得到非空转写文本")
    return {
        "ok": True,
        "model": model,
        "resource_id": resource_id,
        "transport": "GLOSC binary WebSocket streaming",
        "endpoint": ws_url,
        "elapsed_seconds": round(time.monotonic() - started, 3),
        "input_file": str(input_file.resolve()),
        "wav_bytes": len(wav_data),
        "chunk_ms": chunk_ms,
        "chunks_sent": (len(wav_data) + bytes_per_chunk - 1) // bytes_per_chunk,
        "events_received": events_received,
        "final_received": final_received,
        "text": transcript,
    }


def create_local_asr_fixture(output_dir: Path, text: str) -> Path:
    """Create a PCM WAV fixture with macOS system speech."""
    say = shutil.which("say")
    afconvert = shutil.which("afconvert")
    if not say or not afconvert:
        raise ApiError(
            "TTS 未生成音频，且本机没有 say/afconvert；"
            "请用 --asr-file 指定独立的 ASR 测试文件"
        )

    aiff_file = output_dir / "asr-fixture.aiff"
    wav_file = output_dir / "asr-fixture.wav"
    try:
        subprocess.run(
            [say, "-o", str(aiff_file), text],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        subprocess.run(
            [afconvert, str(aiff_file), str(wav_file), "-f", "WAVE", "-d", "LEI16"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except subprocess.CalledProcessError as error:
        detail = error.stderr.decode("utf-8", errors="replace").strip()
        raise ApiError(f"生成本地 ASR 测试音频失败：{detail or error}") from error
    finally:
        try:
            aiff_file.unlink()
        except FileNotFoundError:
            pass

    if not wav_file.is_file() or wav_file.stat().st_size == 0:
        raise ApiError("生成本地 ASR 测试音频失败：输出文件为空")
    return wav_file


def failure_result(model: str, error: BaseException) -> Dict[str, Any]:
    result: Dict[str, Any] = {"ok": False, "model": model, "error": str(error)}
    if isinstance(error, ApiError):
        if error.status is not None:
            result["http_status"] = error.status
        if error.code:
            result["code"] = error.code
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="测试字节 TTS/ASR 模型是否可调用")
    parser.add_argument("--env-file", type=Path, default=Path(".env"))
    parser.add_argument("--base-url", default=None)
    parser.add_argument("--tts-model", default=DEFAULT_TTS_MODEL)
    parser.add_argument("--asr-model", default=DEFAULT_ASR_MODEL)
    parser.add_argument("--asr-resource-id", default=None)
    parser.add_argument("--asr-ws-url", default=None)
    parser.add_argument("--asr-chunk-ms", type=int, default=200)
    parser.add_argument(
        "--asr-realtime-factor",
        type=float,
        default=1.0,
        help="音频分块发送间隔倍率；1.0 表示按真实时长发送",
    )
    parser.add_argument("--voice", default=DEFAULT_VOICE)
    parser.add_argument("--text", default=DEFAULT_TEXT)
    parser.add_argument("--asr-file", type=Path, help="独立测试 ASR 的音频文件")
    parser.add_argument("--output-dir", type=Path, default=Path("output/audio-test"))
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--skip-tts", action="store_true")
    parser.add_argument("--skip-asr", action="store_true")
    parser.add_argument("--models-only", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    load_dotenv(args.env_file)

    token = os.getenv("GLOSC_TOKEN") or os.getenv("TOKEN")
    if not token:
        print("缺少 GLOSC_TOKEN（或 TOKEN）环境变量。", file=sys.stderr)
        return 2
    if args.timeout <= 0:
        print("--timeout 必须大于 0。", file=sys.stderr)
        return 2
    if args.asr_chunk_ms <= 0:
        print("--asr-chunk-ms 必须大于 0。", file=sys.stderr)
        return 2
    if args.asr_realtime_factor < 0:
        print("--asr-realtime-factor 不能小于 0。", file=sys.stderr)
        return 2

    base_url = (args.base_url or os.getenv("BASE_URL") or DEFAULT_BASE_URL).rstrip("/")
    if urlsplit(base_url).scheme not in {"http", "https"}:
        print("BASE_URL 必须使用 http 或 https。", file=sys.stderr)
        return 2

    args.output_dir.mkdir(parents=True, exist_ok=True)
    report: Dict[str, Any] = {
        "tested_at": datetime.now(timezone.utc).isoformat(),
        "base_url": base_url,
        "models": {},
    }
    wanted = {args.tts_model, args.asr_model}
    asr_resource_id = (
        args.asr_resource_id
        or os.getenv("GLOSC_ASR_RESOURCE_ID")
        or os.getenv("VOLC_ASR_RESOURCE_ID")
        or DEFAULT_ASR_RESOURCE_ID
    )
    asr_ws_url = (
        args.asr_ws_url
        or os.getenv("GLOSC_ASR_WS_URL")
        or os.getenv("VOLC_ASR_WS_URL")
        or DEFAULT_ASR_WS_URL
    )
    if urlsplit(asr_ws_url).scheme not in {"ws", "wss"}:
        print("ASR WebSocket URL 必须使用 ws 或 wss。", file=sys.stderr)
        return 2

    print("[1/3] 查询模型目录……", flush=True)
    if token:
        try:
            report["models"] = list_models(base_url, token, wanted, args.timeout)
            found = report["models"]["found"]
            missing = report["models"]["missing"]
            print("  找到：" + (", ".join(found) if found else "无"), flush=True)
            print("  缺少：" + (", ".join(missing) if missing else "无"), flush=True)
        except ApiError as error:
            report["models"] = failure_result("model-list", error)
            print(f"  失败：{error}", flush=True)
    else:
        report["models"] = {"ok": True, "skipped": True, "reason": "没有网关 Token"}
        print("  已跳过：没有网关 Token", flush=True)

    if not args.models_only and not args.skip_tts:
        print("[2/3] 调用 TTS……", flush=True)
        tts_output = args.output_dir / "tts-output.mp3"
        try:
            report["tts"] = test_tts(
                base_url,
                token,
                args.tts_model,
                args.voice,
                args.text,
                tts_output,
                args.timeout,
            )
            print(f"  成功：{tts_output}（{report['tts']['bytes']} bytes）", flush=True)
        except ApiError as error:
            report["tts"] = failure_result(args.tts_model, error)
            print(f"  失败：{error}", flush=True)
    else:
        tts_output = args.output_dir / "tts-output.mp3"

    if not args.models_only and not args.skip_asr:
        print("[3/3] 调用 ASR……", flush=True)
        asr_input = args.asr_file
        if asr_input is None and report.get("tts", {}).get("ok"):
            asr_input = tts_output
        if asr_input is None:
            try:
                asr_input = create_local_asr_fixture(args.output_dir, args.text)
                report["asr_fixture"] = {
                    "source": "macOS system speech",
                    "file": str(asr_input.resolve()),
                    "bytes": asr_input.stat().st_size,
                }
                print(f"  TTS 无输出，改用本地测试音频：{asr_input}", flush=True)
            except ApiError as error:
                report["asr"] = failure_result(args.asr_model, error)
                print(f"  未执行：{error}", flush=True)
        if asr_input is not None:
            try:
                report["asr"] = test_asr_streaming(
                    asr_ws_url,
                    token,
                    asr_resource_id,
                    args.asr_model,
                    asr_input,
                    args.timeout,
                    args.asr_chunk_ms,
                    args.asr_realtime_factor,
                )
                print(f"  成功：{report['asr']['text']}", flush=True)
            except ApiError as error:
                report["asr"] = failure_result(args.asr_model, error)
                print(f"  失败：{error}", flush=True)

    report_file = args.output_dir / "report.json"
    report_file.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"报告：{report_file}", flush=True)

    required_keys = []
    if args.models_only:
        required_keys.append("models")
    else:
        if not args.skip_tts:
            required_keys.append("tts")
        if not args.skip_asr:
            required_keys.append("asr")
    tested = [report.get(key, {}) for key in required_keys]
    return 0 if tested and all(item.get("ok") for item in tested) else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("已中止。", file=sys.stderr)
        sys.exit(130)
