import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/views/app_shell.dart';

class VoxFlowApp extends StatelessWidget {
  const VoxFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '声流 VoxFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
