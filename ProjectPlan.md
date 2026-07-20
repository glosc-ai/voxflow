# 声流(VoxFlow)  - AI 语音助手项目规划书 (Codex 自动化构建专版)

## 零、 Agent 系统提示词 (System Prompt)

```text
你是一位精通 Flutter、Dart 语言及 AI 语音接口开发的资深全栈架构师。
你的任务是指导并帮我从一个【完全空白的文件夹】开始，逐步构建一个支持 Windows 桌面端和 Android 移动端的跨平台 AI 语音转换应用（包含语音转文字 STT 与文字转语音 TTS）。

【核心开发规范】：
1. 模块化与分层架构：严格遵循 Feature-First 目录结构与 Clean Architecture，UI 视图层与业务逻辑/硬件 API 完全解耦。
2. 跨平台兼容性：音频路径必须通过 path_provider 获取，不得写死系统路径；权限申请（麦克风/存储）必须作 Android/Windows 双端适配。
3. 状态管理统一：全局使用 flutter_riverpod 进行响应式状态管理。
4. 渐进式代码生成：请按照下方规划的【阶段指令 (Phases)】逐步提供可运行的代码，每完成一个阶段需确保无编译错误。

```

---

## 一、 技术栈与依赖库定义 (Tech Stack & `pubspec.yaml`)

项目基于 **Flutter (Dart 3.x)** 构建，核心依赖库如下：

```yaml
name: voxflow
description: "A cross-platform AI STT and TTS application for Windows & Android."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # 状态管理 & 网络
  flutter_riverpod: ^2.5.1
  dio: ^5.4.3+1
  
  # 硬件与音频
  record: ^5.1.2             # 跨平台麦克风录音 (WAV/M4A)
  audioplayers: ^6.0.0       # 音频解码与播放控制
  
  # 文件与路径
  path_provider: ^2.1.3     # 跨平台系统路径获取
  file_picker: ^8.0.3       # 本地文件选择器
  permission_handler: ^11.3.1 # 原生动态权限申请
  
  # 持久化存储
  shared_preferences: ^2.2.3# API Key 及应用配置
  sqflite: ^2.3.3+1         # 本地历史记录数据库

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true

```

---

## 二、 目录结构设计 (Directory Architecture)

```text
lib/
├── main.dart                   # 应用入口与全局 ProviderScope 初始化
├── core/                       # 核心基础设施 (多端通用)
│   ├── constants/              # 常量配置 (默认 API 端点、支持音色列表)
│   ├── network/                # Dio Client 封装、拦截器、错误处理
│   ├── storage/                # SQLite/SharedPreferences 本地持久化封装
│   ├── theme/                  # 响应式 UI 主题与深色模式支持
│   └── utils/                  # 路径转换、格式化工具 (SRT 生成/时间戳解析)
├── features/                   # 业务功能独立模块 (Feature-First)
│   ├── settings/               # 【设置中心】API Key、语音模型选择、代理设置
│   │   ├── models/
│   │   ├── providers/
│   │   └── views/
│   ├── stt/                    # 【语音转文字】
│   │   ├── models/             # TranscriptionResult, Segment
│   │   ├── services/           # WhisperApiService, AudioRecordManager
│   │   ├── providers/          # sttProvider, recordingStateProvider
│   │   └── views/              # STT 主界面、麦克风面板、字幕导出页
│   ├── tts/                    # 【文字转语音】
│   │   ├── models/             # TTSRequest, VoiceOption
│   │   ├── services/           # TtsApiService, AudioPlaybackManager
│   │   ├── providers/          # ttsProvider, playbackStateProvider
│   │   └── views/              # TTS 主界面、参数调节器 (语速/音色)
│   └── history/                # 【历史记录】转录日志与合成音频历史
│       ├── models/
│       ├── providers/
│       └── views/
└── widgets/                    # 全局通用 UI 组件 (音频波形, 自定义按钮)

```

---

## 三、 分阶段构建指令 (Step-by-Step Prompts)

你可以按顺序向 Codex 发送以下提示词：

### 📌 阶段 1：项目脚手架与基础环境初始化

> **发送给 Codex 的指令：**
> “请在当前空目录下，帮我执行/生成 Flutter 项目架构：
> 1. 创建支持 Android 和 Windows 平台的 Flutter 工程；
> 2. 配置 `pubspec.yaml` 并引入所需的依赖库；
> 3. 建立标准的 `lib/core` 和 `lib/features` 目录结构；
> 4. 编写基础的 `main.dart`，配置 Riverpod `ProviderScope` 并实现跨平台响应式 Shell 导航（移动端为底部 `BottomNavigationBar`，桌面端自动适配为侧边 `NavigationRail`）。”
> 
> 

---

### 📌 阶段 2：Android 权限与 Windows 硬件适配层

> **发送给 Codex 的指令：**
> “请配置 Android 与 Windows 的原生硬件权限与配置文件：
> 1. 修改 `android/app/src/main/AndroidManifest.xml`，添加 `RECORD_AUDIO`, `INTERNET`, `READ/WRITE_EXTERNAL_STORAGE` 权限；
> 2. 封装 `PermissionService`，在 Android 端运行时动态请求麦克风及存储权限，在 Windows 端自动跳过非必需权限请求；
> 3. 封装 `PathUtils` 静态类，用于跨平台获取应用可写缓存与持久化文档目录。”
> 
> 

---

### 📌 阶段 3：网络请求层 (Dio) 与设置模块 (Settings)

> **发送给 Codex 的指令：**
> “请帮我构建网络请求库与设置模块：
> 1. 封装 `DioClient`，支持设置 BaseUrl（支持默认 OpenAI 官方 API 及第三方自定义中转域名）、自定义 Header (Authorization Bearer Token)；
> 2. 建立 `SettingsNotifier`，持久化保存用户配置（API Key, BaseUrl, 选中的 STT 模型 like `whisper-1`, 默认 TTS 模型 like `tts-1`）；
> 3. 实现 `SettingsScreen` UI：包含 API Key 输入框、BaseUrl 自定义框以及‘测试 API 连通性’按钮。”
> 
> 

---

### 📌 阶段 4：语音转文字 (STT) 核心引擎与界面

> **发送给 Codex 的指令：**
> “请实现【语音转文字 STT】完整逻辑：
> 1. 编写 `AudioRecordManager`，使用 `record` 插件实现麦克风录音、暂停、停止，并保存为 WAV/M4A 临时文件；
> 2. 编写 `WhisperApiService`，调用 OpenAI `/v1/audio/transcriptions` 接口，支持 MultipartFormData 发送音频文件，解析返回文本与时间戳片段；
> 3. 支持通过 `file_picker` 导入本地音频/视频文件进行异步转录；
> 4. 实现字幕工具类：支持将转录结果一键导出为 `.srt` 与 `.txt` 文件；
> 5. 编写 `SttScreen` UI：包含倒计时录音按钮、文件导入区域、转录进度展示以及转录结果预览文本框。”
> 
> 

---

### 📌 阶段 5：文字转语音 (TTS) 核心引擎与界面

> **发送给 Codex 的指令：**
> “请实现【文字转语音 TTS】合成与播放逻辑：
> 1. 编写 `TtsApiService`，调用 OpenAI `/v1/audio/speech` 接口，传入文本、音色 (`alloy`, `echo`, `fable`, `onyx`, `nova`, `shimmer`)、语速 (0.25~4.0) 并获取音频字节流；
> 2. 编写 `AudioPlaybackManager`，使用 `audioplayers` 实现合成音频的播放、暂停、进度条拖动与音量控制；
> 3. 编写 `TtsScreen` UI：多行文本输入框、音色下拉选择器、语速滑块、合成并播放按钮，以及保存 MP3 音频到本地的功能。”
> 
> 

---

### 📌 阶段 6：本地历史数据库与跨平台 UI 优化

> **发送给 Codex 的指令：**
> “请完成最后阶段的收尾与优化：
> 1. 使用 `sqflite` 建立本地数据库，每次完成 STT 转录或 TTS 合成时，自动保存记录（包含类型、文本内容、音频路径、生成时间）；
> 2. 实现 `HistoryScreen` UI：支持列表展示、关键词搜索、一键复制文本、重新播放音频及删除记录；
> 3. 完善全局错误处理（捕获网络超时、API 密钥失效、硬件麦克风被占用等异常），增加 Toast/SnackBar 友好提醒。”
> 
> 

---