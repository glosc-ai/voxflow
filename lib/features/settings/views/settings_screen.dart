import 'package:flutter/material.dart';

import '../../../widgets/feature_placeholder.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: '设置',
      icon: Icons.settings,
      description: '配置 OpenAI API 密钥、接口地址与默认模型。',
    );
  }
}
