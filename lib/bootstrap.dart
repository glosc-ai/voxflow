import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_spacing.dart';
import 'features/settings/providers/settings_provider.dart';
import 'l10n/app_localizations.dart';
import 'widgets/app_empty_state.dart';

class VoxFlowBootstrap extends StatefulWidget {
  const VoxFlowBootstrap({super.key});

  @override
  State<VoxFlowBootstrap> createState() => _VoxFlowBootstrapState();
}

class _VoxFlowBootstrapState extends State<VoxFlowBootstrap> {
  static const _windowChannel = MethodChannel('ai.glosc.voxflow/window');

  late Future<SharedPreferences> _preferences;
  bool _windowReadyNotified = false;

  @override
  void initState() {
    super.initState();
    _preferences = SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _preferences,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _notifyWindowReady();
          return ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(snapshot.data!),
            ],
            child: const VoxFlowApp(),
          );
        }
        return MaterialApp(
          onGenerateTitle: (context) => context.l10n.text(
            zh: '声流 VoxFlow',
            en: 'VoxFlow',
          ),
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
                          message: l10n.text(
                            zh: '请重试。现有设置不会被修改。',
                            en: 'Try again. Existing settings will not be changed.',
                          ),
                          action: OutlinedButton.icon(
                            onPressed: () => setState(
                              () => _preferences =
                                  SharedPreferences.getInstance(),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.text(zh: '重试', en: 'Retry')),
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.dialog,
                                    ),
                                  ),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.md),
                                    child: Icon(
                                      Icons.multitrack_audio,
                                      size: 32,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  l10n.text(
                                    zh: '声流 VoxFlow',
                                    en: 'VoxFlow',
                                  ),
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
