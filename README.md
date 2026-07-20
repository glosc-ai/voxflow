# 声流 VoxFlow

声流是一款面向 Windows 与 Android 的 Flutter 语音生产力应用，提供 OpenAI
兼容接口驱动的语音转文字（STT）、文字转语音（TTS）和本地历史记录。

## 功能

- 麦克风录音、暂停/继续，以及本地音频或视频文件转录
- Whisper `verbose_json` 片段解析和 TXT/SRT 导出
- `tts-1` 六种音色、0.25–4.0 倍语速、播放控制和 MP3 另存
- Windows/Android 本地 SQLite 历史、搜索、复制、重播和安全删除
- OpenAI 官方或 HTTPS 兼容代理的 API Root、密钥和模型设置
- 响应式 Material 3 界面：移动端底部导航、桌面端侧边导航

## 环境

- Flutter 3.x / Dart 3.x
- Windows 10/11 与 Visual Studio 2022 Windows 桌面工具链
- Android SDK 与 JDK 17

安装依赖：

```shell
flutter pub get
```

开发运行：

```shell
flutter run -d windows
flutter run -d android
```

构建发布产物：

```shell
flutter build windows
flutter build apk --split-per-abi
```

## API 配置

首次运行后打开“设置”，填写 API Key。默认 API Root 为
`https://api.openai.com/v1`，STT/TTS 模型分别为 `whisper-1` 与 `tts-1`。
自定义代理必须使用 HTTPS，并兼容 `/models`、`/audio/transcriptions` 和
`/audio/speech`。

API Key 按项目约束保存在本机 SharedPreferences 中，不具备操作系统密钥库级加密；
应用不会把密钥写入调试日志或错误提示。

转录文件限制为 25 MB，支持 MP3、MP4、MPEG、MPGA、M4A、WAV 和 WEBM。
录音与生成音频均保存在 `path_provider` 返回的应用目录中，不使用硬编码系统路径。

## 验证

```shell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

自动测试使用伪网络适配器与临时 SQLite 数据库，不消耗真实 API 额度。
