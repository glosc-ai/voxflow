import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_section.dart';
import '../../../widgets/app_status_banner.dart';
import '../../../widgets/mobile_design.dart';
import '../providers/privacy_notice_provider.dart';

class PrivacyNoticeGate extends ConsumerWidget {
  const PrivacyNoticeGate({required this.child, super.key});

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
    final l10n = context.l10n;
    if (Theme.of(context).platform == TargetPlatform.android) {
      return _buildMobile(context, ref, l10n);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < AppBreakpoints.compact ||
            constraints.maxHeight < 760 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.3;
        final action = FilledButton.icon(
          key: const Key('privacyNoticeAcceptButton'),
          onPressed: () => _acknowledge(context, ref),
          icon: const Icon(Icons.check),
          label: Text(
            l10n.text(zh: '我已了解并继续', en: 'I understand and want to continue'),
          ),
        );
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: AppTheme.responsiveAppBarHeight(
              context,
              largeTextMaxLines: 2,
            ),
            title: Text(
              l10n.text(zh: '数据与隐私说明', en: 'Data and privacy'),
              maxLines: 2,
            ),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                padding: AppLayout.pagePadding(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.large),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.privacy_tip_outlined,
                                size: 28,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.text(
                                        zh: '开始使用前，请确认数据处理方式',
                                        en: 'Review how your data is handled',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      l10n.text(
                                        zh: 'VoxFlow 只会将内容发送到你配置的服务，并在本机保存必要的任务记录。',
                                        en: 'VoxFlow sends content only to the service you configure and keeps necessary task records on this device.',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppStatusBanner(
                        kind: AppStatusKind.warning,
                        title: l10n.text(
                          zh: 'API Key 安全存储',
                          en: 'Protected API key storage',
                        ),
                        message: l10n.text(
                          zh: 'API Key 在 Windows 上使用当前用户作用域的 DPAPI 加密并存入当前用户注册表；该保护不防御已控制同一 Windows 用户的进程。在 Android 上使用当前应用安装的 Keystore 加密，且 Android 应用数据备份已禁用。密钥不会写入普通应用设置或诊断日志。即使使用安全存储，也建议仅使用可随时撤销、设置了低额度上限的测试密钥。',
                          en: 'The API key is encrypted with user-scoped DPAPI and stored in the current user registry on Windows; this does not protect against processes that already control the same Windows account. On Android it is encrypted with Keystore for the current app installation, and Android app-data backup is disabled. The key is never written to ordinary app preferences or diagnostic logs. Even with protected storage, use only a revocable test key with a low quota limit.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppSection(
                        title: l10n.text(zh: '数据范围', en: 'Data scope'),
                        description: l10n.text(
                          zh: '以下信息帮助你判断当前配置是否符合自己的隐私要求。',
                          en: 'Use this information to decide whether the current configuration meets your privacy requirements.',
                        ),
                        leading: const Icon(Icons.shield_outlined),
                        child: Column(
                          children: [
                            _NoticeItem(
                              icon: Icons.cloud_upload_outlined,
                              title: l10n.text(
                                zh: '数据外发',
                                en: 'Data sent externally',
                              ),
                              description: l10n.text(
                                zh: '你提交的文本和音频会发送到你配置的 API 服务商，VoxFlow 不会替你选择其他服务商。',
                                en: 'Submitted text and audio are sent to the API provider you configure. VoxFlow does not choose another provider for you.',
                              ),
                            ),
                            const Divider(height: AppSpacing.xl),
                            _NoticeItem(
                              icon: Icons.folder_outlined,
                              title: l10n.text(
                                zh: '本地历史与音频',
                                en: 'Local history and audio',
                              ),
                              description: l10n.text(
                                zh: '历史文本和受管音频保存在本机。删除历史记录时，应用会尝试删除对应的受管音频；文件删除失败时会提示，用户导入的原始文件不受影响。',
                                en: 'History text and managed audio stay on this device. When deleting a history item, the app attempts to delete its managed audio and warns if file deletion fails. Original imported files are not affected.',
                              ),
                            ),
                            const Divider(height: AppSpacing.xl),
                            _NoticeItem(
                              icon: Icons.description_outlined,
                              title: l10n.text(
                                zh: '诊断日志',
                                en: 'Diagnostic logs',
                              ),
                              description: l10n.text(
                                zh: '日志会脱敏 API Key 和认证头，也不会主动记录输入正文；但仍可能包含请求时间、接口路径、模型和服务端返回的错误原因，而错误原因可能回显部分输入内容。',
                                en: 'Logs redact API keys and authorization headers and do not intentionally record input content. They may still include request times, endpoint paths, models, and server-provided error reasons, which can echo part of the input.',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Align(alignment: Alignment.centerRight, child: action),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: compact
              ? SafeArea(
                  top: false,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: action,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildMobile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final colors = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          key: const Key('mobilePrivacyNoticeScrollView'),
          padding: EdgeInsets.fromLTRB(16, 10, 16, 112 + safeBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MobileViewHeader(
                eyebrow: l10n.text(
                  zh: 'Privacy · 本地数据',
                  en: 'Privacy · Local data',
                ),
                title: l10n.text(zh: '数据与隐私说明', en: 'Data and privacy'),
              ),
              MobileSurfaceCard(
                radius: AppRadii.mobileHero,
                padding: const EdgeInsets.all(AppSpacing.lg),
                color: colors.primaryContainer,
                borderColor: colors.primary.withValues(alpha: 0.18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      size: 28,
                      color: colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.text(
                              zh: '开始使用前，请确认数据处理方式',
                              en: 'Review how your data is handled',
                            ),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.text(
                              zh: 'VoxFlow 只会将内容发送到你配置的服务，并在本机保存必要的任务记录。',
                              en: 'VoxFlow sends content only to the service you configure and keeps necessary task records on this device.',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppStatusBanner(
                kind: AppStatusKind.warning,
                title: l10n.text(
                  zh: 'API Key 安全存储',
                  en: 'Protected API key storage',
                ),
                message: l10n.text(
                  zh: 'API Key 在 Windows 上使用当前用户作用域的 DPAPI 加密并存入当前用户注册表；该保护不防御已控制同一 Windows 用户的进程。在 Android 上使用当前应用安装的 Keystore 加密，且 Android 应用数据备份已禁用。密钥不会写入普通应用设置或诊断日志。即使使用安全存储，也建议仅使用可随时撤销、设置了低额度上限的测试密钥。',
                  en: 'The API key is encrypted with user-scoped DPAPI and stored in the current user registry on Windows; this does not protect against processes that already control the same Windows account. On Android it is encrypted with Keystore for the current app installation, and Android app-data backup is disabled. The key is never written to ordinary app preferences or diagnostic logs. Even with protected storage, use only a revocable test key with a low quota limit.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              MobileSurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.text(zh: '数据范围', en: 'Data scope'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l10n.text(
                        zh: '请确认当前配置符合你的隐私要求。',
                        en: 'Confirm that the current configuration meets your privacy requirements.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _NoticeItem(
                      icon: Icons.cloud_upload_outlined,
                      title: l10n.text(zh: '数据外发', en: 'Data sent externally'),
                      description: l10n.text(
                        zh: '你提交的文本和音频会发送到你配置的 API 服务商，VoxFlow 不会替你选择其他服务商。',
                        en: 'Submitted text and audio are sent to the API provider you configure. VoxFlow does not choose another provider for you.',
                      ),
                    ),
                    const Divider(height: AppSpacing.xl),
                    _NoticeItem(
                      icon: Icons.folder_outlined,
                      title: l10n.text(
                        zh: '本地历史与音频',
                        en: 'Local history and audio',
                      ),
                      description: l10n.text(
                        zh: '历史文本和受管音频保存在本机。删除历史记录时，应用会尝试删除对应的受管音频；文件删除失败时会提示，用户导入的原始文件不受影响。',
                        en: 'History text and managed audio stay on this device. When deleting a history item, the app attempts to delete its managed audio and warns if file deletion fails. Original imported files are not affected.',
                      ),
                    ),
                    const Divider(height: AppSpacing.xl),
                    _NoticeItem(
                      icon: Icons.description_outlined,
                      title: l10n.text(zh: '诊断日志', en: 'Diagnostic logs'),
                      description: l10n.text(
                        zh: '日志会脱敏 API Key 和认证头，也不会主动记录输入正文；但仍可能包含请求时间、接口路径、模型和服务端返回的错误原因，而错误原因可能回显部分输入内容。',
                        en: 'Logs redact API keys and authorization headers and do not intentionally record input content. They may still include request times, endpoint paths, models, and server-provided error reasons, which can echo part of the input.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: MobileGlassSurface(
          radius: AppRadii.mobileCard,
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: FilledButton(
            key: const Key('privacyNoticeAcceptButton'),
            onPressed: () => _acknowledge(context, ref),
            child: Text(
              l10n.text(zh: '我已了解并继续', en: 'I understand and want to continue'),
              maxLines: 2,
              textAlign: TextAlign.center,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.appError(error))));
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
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(icon, color: colors.onPrimaryContainer, size: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
