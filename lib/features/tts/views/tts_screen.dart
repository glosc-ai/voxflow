import 'package:flutter/material.dart';

import '../../../widgets/feature_placeholder.dart';

class TtsScreen extends StatelessWidget {
  const TtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: '文字转语音',
      icon: Icons.record_voice_over,
      description: '输入文字、选择音色与语速，生成并播放 MP3。',
    );
  }
}
