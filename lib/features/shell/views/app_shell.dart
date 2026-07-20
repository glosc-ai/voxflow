import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../history/views/history_screen.dart';
import '../../settings/views/settings_screen.dart';
import '../../stt/views/stt_screen.dart';
import '../../tts/views/tts_screen.dart';
import '../providers/navigation_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.graphic_eq), label: '语音转文字'),
    NavigationDestination(icon: Icon(Icons.record_voice_over), label: '文字转语音'),
    NavigationDestination(icon: Icon(Icons.history), label: '历史记录'),
    NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
  ];

  static const screens = <Widget>[
    SttScreen(),
    TtsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationIndexProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= AppConstants.navigationBreakpoint;
        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 1040,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      ref.read(navigationIndexProvider.notifier).state = index,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Icon(Icons.multitrack_audio, size: 32),
                  ),
                  destinations: destinations
                      .map(
                        (item) => NavigationRailDestination(
                          icon: item.icon,
                          label: Text(item.label),
                        ),
                      )
                      .toList(growable: false),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(
                    index: selectedIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: IndexedStack(index: selectedIndex, children: screens),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: selectedIndex,
            onTap: (index) =>
                ref.read(navigationIndexProvider.notifier).state = index,
            items: destinations
                .map(
                  (item) => BottomNavigationBarItem(
                    icon: item.icon,
                    label: item.label,
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }
}
