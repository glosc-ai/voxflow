import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../providers/privacy_notice_provider.dart';

class PrivacyNoticeGate extends ConsumerWidget {
  const PrivacyNoticeGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(privacyNoticeProvider)) {
      return child;
    }
    return const _PrivacyNoticeScreen();
  }
}

class _PrivacyNoticeScreen extends ConsumerWidget {
  const _PrivacyNoticeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据与隐私说明')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '开始使用前，请了解以下数据处理方式',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      const _NoticeItem(
                        icon: Icons.key,
                        title: 'API Key',
                        description:
                            'API Key 会以明文形式保存在本机应用设置中。请仅使用可撤销、低额度的受限测试密钥。',
                      ),
                      const _NoticeItem(
                        icon: Icons.cloud_upload_outlined,
                        title: '数据外发',
                        description:
                            '你提交的文本和音频会发送到你配置的 API 服务商，VoxFlow 不会替你选择其他服务商。',
                      ),
                      const _NoticeItem(
                        icon: Icons.folder_outlined,
                        title: '本地历史与音频',
                        description: '历史文本和受管音频保存在本机。删除历史记录时，对应的受管音频也会被删除。',
                      ),
                      const _NoticeItem(
                        icon: Icons.description_outlined,
                        title: '诊断日志',
                        description:
                            '日志会脱敏 API Key、认证头和输入正文，但仍可能包含请求时间、接口路径、模型和错误原因。',
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: const Key('privacyNoticeAcceptButton'),
                        onPressed: () => _acknowledge(context, ref),
                        icon: const Icon(Icons.check),
                        label: const Text('我已了解并继续'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _acknowledge(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(privacyNoticeProvider.notifier).acknowledge();
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }
}

class _NoticeItem extends StatelessWidget {
  const _NoticeItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
