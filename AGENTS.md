# **AGENTS.md**

## **1\. Project Overview**

VoxFlow (声流) is a cross-platform, AI-powered Speech-to-Text (STT) and Text-to-Speech (TTS) productivity application built using **Flutter (Dart 3.x)**.

* **Target Platforms**: Windows Desktop & Android Mobile.  
* **AI Backend**: OpenAI API / Custom proxy endpoint (Whisper for STT, OpenAI TTS for speech synthesis).  
* **Architecture**: Feature-First & Clean Architecture.

## **2\. Tech Stack & Dependencies**

AI Agents must only use the packages specified in pubspec.yaml:

* **State Management**: flutter\_riverpod (v2.x) \- strictly use Riverpod for all asynchronous and global state management.  
* **Networking**: dio (v5.x) \- HTTP client with base configuration, custom interceptors, and proxy support.  
* **Audio Recording**: record (v5.x) \- Handles mic input & codec recording.  
* **Audio Playback**: audioplayers (v6.x) \- Decodes and plays processed audio.  
* **Storage**: sqflite (SQLite) for history logs, shared\_preferences for key-value application settings (API Keys, URLs).  
* **Files & Path**: path\_provider (system-safe directories) & file\_picker (importing local media).  
* **Permissions**: permission\_handler (for native Android execution).

## **3\. Directory Layout & Routing**

Always respect the Feature-First architecture when creating or modifying files:

lib/  
├── main.dart                 \# App initialization, ProviderScope, EntryPoint  
├── core/                     \# Shared cross-platform infrastructure  
│   ├── constants/            \# Supported models, Default URLs, Voices list  
│   ├── network/              \# Dio client config, custom error interceptors  
│   ├── storage/              \# SQLite database & SharedPreferences helpers  
│   ├── theme/                \# Global theme, dark mode adapters  
│   └── utils/                \# SRT/TXT exporters, time/audio formatters  
└── features/                 \# Modular domain features  
    ├── settings/             \# Settings state, API connectivity test, preferences  
    ├── stt/                  \# Microphone management, Whisper requests, transcription editor  
    ├── tts/                  \# Text inputs, character limits, TTS players  
    └── history/              \# Local SQLite operations & search screens

## **4\. Development & Build Commands**

Ensure your generated code is fully compatible with the following build routines:

### **Install Dependencies**

flutter pub get

### **Run Project (Dual-Platform)**

* **Windows**:  
  flutter run \-d windows

* **Android**:  
  flutter run \-d android

### **Build Distribution Binaries**

* **Windows (.exe)**:  
  flutter build windows

* **Android (.apk)**:  
  flutter build apk \--split-per-abi

## **5\. Coding Standards & Rigid Guardrails (MUST OBEY)**

### **🚨 HARDWARE & PATH SAFEGUARDS**

1. **No Hardcoded System Paths**:  
   * NEVER write absolute paths like C:\\\\ or /sdcard/.  
   * ALWAYS resolve runtime files using path\_provider:  
     final tempDir \= await getTemporaryDirectory();  
     final audioPath \= '${tempDir.path}/recorded\_audio.wav';

2. **Platform-Aware Runtime Permissions**:  
   * ALWAYS check the host platform before requesting system permissions.  
   * Use permission\_handler to request runtime mic/storage permissions **only on Android**.  
   * **On Windows**, bypass runtime permission prompts gracefully, as the system handles native application permissions implicitly.

### **🔌 STATE MANAGEMENT & NETWORK**

1. **Riverpod over setState**:  
   * Avoid setState in complex pages.  
   * Manage the recorder state (RecordingState), network requests, and players using Riverpod StateNotifierProvider or code-generated Notifiers.  
2. **Secure Credentials**:  
   * Never output API Keys or User Credentials in standard print() or debugPrint() logs.  
   * Read keys dynamically from the initialized secure store or settingsProvider.  
3. **Graceful Error Recovery**:  
   * All networking and I/O tasks must be wrapped in try-catch blocks.  
   * Map low-level HTTP errors to a user-friendly UI component or standard SnackBars instead of crashing.

## **6\. Commit Style Preference**

When proposing or executing repository commits:

* Use structured commit messages: \<type\>(\<scope\>): \<short description\>  
* Types: feat, fix, docs, style, refactor, perf, chore.  
* Example: feat(stt): integrate whisper API call with file upload

## Agent skills

### Issue tracker

Issues and PRDs are tracked in GitHub Issues for `glosc-ai/voxflow`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

This repository uses a single-context domain documentation layout with `CONTEXT.md` at the root and ADRs under `docs/adr/`. See `docs/agents/domain.md`.
