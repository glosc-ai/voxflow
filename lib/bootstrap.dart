import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_spacing.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/services/api_key_store.dart';
import 'features/settings/services/settings_repository.dart';
import 'l10n/app_localizations.dart';
import 'widgets/app_empty_state.dart';

class VoxFlowBootstrap extends StatefulWidget {
  const VoxFlowBootstrap({super.key});

  @override
  State<VoxFlowBootstrap> createState() => _VoxFlowBootstrapState();
}

class _VoxFlowBootstrapState extends State<VoxFlowBootstrap> {
  static const _windowChannel = MethodChannel('ai.glosc.voxflow/window');

  late Future<_BootstrapDependencies> _dependencies;
  bool _windowReadyNotified = false;
  bool _recoveringCredential = false;
  bool _credentialRecoveryFailed = false;

  @override
  void initState() {
    super.initState();
    _dependencies = _initializeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapDependencies>(
      future: _dependencies,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _notifyWindowReady();
          return ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(
                snapshot.data!.preferences,
              ),
              apiKeyStoreProvider.overrideWithValue(snapshot.data!.apiKeyStore),
              settingsRepositoryProvider.overrideWithValue(
                snapshot.data!.settingsRepository,
              ),
            ],
            child: const VoxFlowApp(),
          );
        }
        return MaterialApp(
          onGenerateTitle: (context) =>
              context.l10n.text(zh: '声流 VoxFlow', en: 'VoxFlow'),
          debugShowCheckedModeBanner: false,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback:
              AppLocalizations.localeListResolutionCallback,
          localizationsDelegates: AppLocalizations.delegates,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          home: Builder(
            builder: (context) {
              final l10n = context.l10n;
              return Scaffold(
                body: SafeArea(
                  child: snapshot.hasError
                      ? AppEmptyState(
                          icon: Icons.settings_backup_restore_outlined,
                          title: l10n.text(
                            zh: '无法读取本机设置',
                            en: 'Local settings could not be loaded',
                          ),
                          message: _credentialRecoveryFailed
                              ? l10n.text(
                                  zh: '仍无法恢复安全凭据。请使用系统应用设置清除 VoxFlow 的存储数据。',
                                  en: 'Secure credential recovery still failed. Clear VoxFlow storage from the system app settings.',
                                )
                              : l10n.text(
                                  zh: '请先重试；若安全凭据已损坏，可仅清除 API 凭据后重新启动。',
                                  en: 'Retry first. If the secure credential is corrupt, clear only the API credential and restart.',
                                ),
                          action: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              OutlinedButton.icon(
                                key: const Key('bootstrapRetryButton'),
                                onPressed: _recoveringCredential
                                    ? null
                                    : () => setState(
                                        () => _dependencies =
                                            _initializeDependencies(),
                                      ),
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.text(zh: '重试', en: 'Retry')),
                              ),
                              FilledButton.icon(
                                key: const Key(
                                  'bootstrapClearCredentialButton',
                                ),
                                onPressed: _recoveringCredential
                                    ? null
                                    : () => _confirmCredentialRecovery(context),
                                icon: _recoveringCredential
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.key_off_outlined),
                                label: Text(
                                  _recoveringCredential
                                      ? l10n.text(zh: '正在清除…', en: 'Clearing…')
                                      : l10n.text(
                                          zh: '清除 API 凭据',
                                          en: 'Clear API credential',
                                        ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Semantics(
                            liveRegion: true,
                            label: l10n.text(
                              zh: '正在启动声流 VoxFlow',
                              en: 'Starting VoxFlow',
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.dialog,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    child: Icon(
                                      Icons.multitrack_audio,
                                      size: 32,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  l10n.text(zh: '声流 VoxFlow', en: 'VoxFlow'),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<_BootstrapDependencies> _initializeDependencies() async {
    final preferences = await SharedPreferences.getInstance();
    const apiKeyStore = MethodChannelApiKeyStore();
    final repository = SettingsRepository(preferences, apiKeyStore);
    await repository.initialize();
    return _BootstrapDependencies(
      preferences: preferences,
      apiKeyStore: apiKeyStore,
      settingsRepository: repository,
    );
  }

  Future<void> _confirmCredentialRecovery(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.text(zh: '清除 API 凭据？', en: 'Clear the API credential?'),
        ),
        content: Text(
          l10n.text(
            zh: '这会删除安全存储中的 API Key。历史记录、音频、日志和其他设置不会被删除；进入应用后仍可在设置中清空全部数据。',
            en: 'This deletes the API key from secure storage. History, audio, logs, and other settings are kept; you can still clear all data from Settings after the app opens.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.text(zh: '取消', en: 'Cancel')),
          ),
          FilledButton(
            key: const Key('bootstrapClearCredentialConfirmButton'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.text(zh: '清除并重试', en: 'Clear and retry')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _recoveringCredential = true;
      _credentialRecoveryFailed = false;
    });
    var failed = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences);
      await repository.clearCredentialForRecovery();
    } catch (_) {
      failed = true;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _recoveringCredential = false;
      _credentialRecoveryFailed = failed;
      // Recovery commits a fail-closed marker before touching the credential,
      // so retrying is safe even when the platform deletion reported failure.
      _dependencies = _initializeDependencies();
    });
  }

  void _notifyWindowReady() {
    if (_windowReadyNotified) {
      return;
    }
    _windowReadyNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _windowChannel.invokeMethod<void>('redraw');
      } on MissingPluginException {
        // The native redraw bridge only exists in the Windows runner.
      }
    });
  }
}

class _BootstrapDependencies {
  const _BootstrapDependencies({
    required this.preferences,
    required this.apiKeyStore,
    required this.settingsRepository,
  });

  final SharedPreferences preferences;
  final ApiKeyStore apiKeyStore;
  final SettingsRepository settingsRepository;
}
