import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/providers/settings_provider.dart';

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
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          home: Scaffold(
            body: Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 16),
                        const Text('无法读取本机设置。'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => setState(
                            () =>
                                _preferences = SharedPreferences.getInstance(),
                          ),
                          child: const Text('重试'),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.multitrack_audio, size: 56),
                        SizedBox(height: 16),
                        Text(AppConstants.appName),
                        SizedBox(height: 16),
                        SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ),
            ),
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
