# DESIGN.md — VoxFlow UI Design Specification
---

## 1. 核心设计哲学 (Design Philosophy)

- **Style:** Clean Modern Tech / Open Design Specification
- **Core Values:** 高清晰度视觉层次、充裕的留白、沉浸式卡片悬浮感、轻量化毛玻璃与质感微边框。
- **Platform Synergy:** 
  - **Windows (Desktop):** 侧边悬浮 NavigationRail，充裕的列式排版与快捷键视效反馈。
  - **Android (Mobile):** 底部悬浮 App Shell，触控友好的大点击热区，极佳的单手操作体验。

---

## 2. 设计令牌 (Design Tokens)

### 2.1 调色板 (Color Palette)

#### Light Theme (日间模式)
- **Background (Canvas):** `#F8F9FA` (冷微灰底色，非纯白)
- **Surface (Card/Container):** `#FFFFFF` (纯白悬浮卡片)
- **Primary / Brand:** `#5D5FEF` (科技蓝紫)
- **Primary Hover/Active:** `#4F46E5`
- **Secondary / Accent:** `#10B981` (实时录音/成功/API连接指示)
- **Danger / Warning:** `#EF4444` (终止/删除/错误)
- **Text Primary:** `#0F172A` (高对比度深蓝灰)
- **Text Secondary:** `#64748B` (次要说明文字)
- **Border / Divider:** `#E2E8F0` (1px 超细高质感边框)

#### Dark Theme (夜间模式)
- **Background (Canvas):** `#121316` (极深冷灰)
- **Surface (Card/Container):** `#1E1F23` (悬浮卡片底色)
- **Primary / Brand:** `#6366F1`
- **Secondary / Accent:** `#34D399`
- **Danger / Warning:** `#F87171`
- **Text Primary:** `#F8FAFC`
- **Text Secondary:** `#94A3B8`
- **Border / Divider:** `#2E3038`

### 2.2 形状与圆角 (Radius Specification)
- **Small (Tag, ChoiceChip, Badge):** `8px`
- **Medium (Input, Button, Small Card):** `12px` ~ `14px`
- **Large (Standard Card, Dialog, Sheet):** `18px` ~ `20px`
- **X-Large (Recorder Container, Player Bar):** `24px` ~ `32px`

### 2.3 深度与阴影 (Depth & Elevation)
摒弃 Material 2/3 的高高度投影（High Elevation Drop Shadow），统一改用 **超软高模糊浅阴影 + 1px Border**：
```dart
BoxShadow(
  color: Colors.black.withOpacity(0.04),
  blurRadius: 16,
  offset: const Offset(0, 4),
)

```

---

## 3. 布局与响应式 Shell 规范

### 3.1 App Shell

* 不使用贴边的传统原生 AppBar / BottomNavigationBar。
* **Android:** 采用带高斯模糊（BackdropFilter `sigma: 10`）的悬浮式 Bottom Bar，距底部及两侧各保留 `16px` 外边距。
* **Windows:** 左侧悬浮 NavigationRail，宽 `240px`，顶部放置 Logo 与 API 连接状态指示器（带绿色 Glow 效果的微光点）。

---

## 4. 业务模块细化重构规范

### 4.1 语音转文字 (STT View)

1. **Hero Recorder Section (录音核心区):**
* 居中放置一个 `120x120px` 的多层圆角录音面板。
* 录音状态下，展示动态波纹扩散（Pulsing Aura Effect）与毫秒级实时计时器。


2. **Result View (转录结果区):**
* 不使用单个纯文本框，支持 Segment 时间轴轨道的 Timeline 卡片展示。
* 顶部提供微型浮动 ToolBar（格式切换 TXT/SRT、一键复制）。



### 4.2 文字转语音 (TTS View)

1. **Text Input (文本输入):**
* 融入背景无缝连接的 Large TextArea，右下角附带渐变底色字数统计指示器。


2. **Voice Selector (音色选择器):**
* 摒弃 Dropdown 菜单，改为横向滑动的 Voice Cards，显示音色名称、性别和应用场景标签（如 `Alloy · 场景/通用`）。


3. **Floating Audio Player (底端播放器):**
* 音频生成后，从底部平滑弹出 Glassmorphism 样式播放条，内置波形指示与 `0.25x - 4.0x` 语速微调 Pill 按钮。



### 4.3 历史记录 (History View)

* 采用 **Masonry Waterfall / Card List**。
* 每条记录用 Tag 标记类别（`STT` 靛蓝 / `TTS` 薄荷绿）。
* 操作按钮（播放、复制、删除）移至悬浮/hover 显示的 Action Bar 中。

---

## 5. Agent 代码重构约束 (Codex Rules)

1. **结构分离:** 必须将所有 Design Tokens 提取至 `lib/core/theme/`（如 `app_colors.dart`、`app_typography.dart`、`app_shadows.dart`）。
2. **禁止原生粗糙组件:** 严禁直接使用原生 `ElevatedButton` 或无样式的 `TextField`，所有组件必须基于 `AppCard` 或自定义包覆容器。
3. **动画规范:** 状态切换（如按钮 hover、录音展开）必须附加 `Duration(milliseconds: 200)` 的 `AnimatedContainer` 或 `AnimatedSwitcher`。
