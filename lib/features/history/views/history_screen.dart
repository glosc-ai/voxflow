import 'package:flutter/material.dart';

import '../../../widgets/feature_placeholder.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: '历史记录',
      icon: Icons.history,
      description: '查看、搜索和管理本机的转录与合成记录。',
    );
  }
}
