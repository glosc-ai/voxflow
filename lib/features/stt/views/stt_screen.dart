import 'package:flutter/material.dart';

import '../../../widgets/feature_placeholder.dart';

class SttScreen extends StatelessWidget {
  const SttScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: '语音转文字',
      icon: Icons.graphic_eq,
      description: '录制或导入音频，让 AI 生成可编辑文字与字幕。',
    );
  }
}
