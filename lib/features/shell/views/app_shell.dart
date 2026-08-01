import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../history/views/history_screen.dart';
import '../../settings/views/settings_screen.dart';
import '../../stt/providers/stt_provider.dart';
import '../../stt/views/stt_screen.dart';
import '../../tts/views/tts_screen.dart';
import '../providers/navigation_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  static const _destinations = <_AppDestination>[
    _AppDestination(
      icon: Icons.graphic_eq_outlined,
      selectedIcon: Icons.graphic_eq,
    ),
    _AppDestination(
      icon: Icons.record_voice_over_outlined,
      selectedIcon: Icons.record_voice_over,
    ),
    _AppDestination(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
    ),
    _AppDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final List<FocusNode> _pageFocusNodes;
  late final List<Widget> _screens;
  bool _navigationInProgress = false;

  @override
  void initState() {
    super.initState();
    _pageFocusNodes = List.generate(
      AppShell._destinations.length,
      (index) => FocusNode(debugLabel: 'appPage:$index'),
    );
    _screens = [
      SttScreen(pageFocusNode: _pageFocusNodes[0]),
      TtsScreen(pageFocusNode: _pageFocusNodes[1]),
      HistoryScreen(pageFocusNode: _pageFocusNodes[2]),
      SettingsScreen(pageFocusNode: _pageFocusNodes[3]),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestPageFocus(ref.read(navigationIndexProvider));
      }
    });
  }

  @override
  void dispose() {
    for (final node in _pageFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(int index) {
    unawaited(_selectAfterRecordingCheck(index));
  }

  Future<void> _selectAfterRecordingCheck(int index) async {
    if (index < 0 || index >= _pageFocusNodes.length) {
      return;
    }
    final currentIndex = ref.read(navigationIndexProvider);
    if (currentIndex == 0 &&
        index != 0 &&
        ref.read(sttProvider).hasActiveRecordingSession) {
      if (_navigationInProgress) {
        return;
      }
      _navigationInProgress = true;
      try {
        final confirmed = await _confirmLeaveRecording();
        if (!mounted || confirmed != true) {
          return;
        }
        final stopped = await ref.read(sttProvider.notifier).cancelRecording();
        if (!mounted || !stopped) {
          return;
        }
      } finally {
        _navigationInProgress = false;
      }
    }
    ref.read(navigationIndexProvider.notifier).state = index;
    if (currentIndex == index) {
      _schedulePageFocus(index);
    }
  }

  Future<bool?> _confirmLeaveRecording() {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.text(
            zh: '停止录音并离开？',
            en: 'Stop recording and leave?',
          ),
        ),
        content: Text(
          l10n.text(
            zh: '当前录音尚未转录。离开将停止并放弃此录音。',
            en: 'This recording has not been transcribed. Leaving will stop and discard it.',
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.text(zh: '取消', en: 'Cancel')),
          ),
          FilledButton(
            key: const Key('leaveRecordingConfirmButton'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.text(
                zh: '停止并离开',
                en: 'Stop and leave',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _schedulePageFocus(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(navigationIndexProvider) != index) {
        return;
      }
      _requestPageFocus(index);
    });
  }

  void _requestPageFocus(int index) {
    if (index < 0 || index >= _pageFocusNodes.length) {
      return;
    }
    FocusScope.of(context).requestFocus(_pageFocusNodes[index]);
  }

  Widget _pageStack(int selectedIndex) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: IndexedStack(
        index: selectedIndex,
        children: [
          for (var index = 0; index < _screens.length; index++)
            ExcludeFocus(
              excluding: index != selectedIndex,
              child: _screens[index],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(navigationIndexProvider, (previous, next) {
      if (previous != next) {
        _schedulePageFocus(next);
      }
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            _select(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            _select(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            _select(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
            _select(3),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selectedIndex = ref.watch(navigationIndexProvider);
          final isAndroid =
              Theme.of(context).platform == TargetPlatform.android;
          final isExtended = constraints.maxWidth >= AppBreakpoints.expanded &&
              MediaQuery.textScalerOf(context).scale(1) < 1.6;
          if (!isAndroid) {
            return _DesktopShell(
              selectedIndex: selectedIndex,
              extended: isExtended,
              onSelected: _select,
              pageStack: _pageStack(selectedIndex),
            );
          }
          return _CompactShell(
            selectedIndex: selectedIndex,
            onSelected: _select,
            pageStack: _pageStack(selectedIndex),
          );
        },
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
    required this.pageStack,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;
  final Widget pageStack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            groupAlignment: -0.72,
            leading: _BrandHeader(extended: extended),
            destinations: [
              for (var index = 0;
                  index < AppShell._destinations.length;
                  index++)
                NavigationRailDestination(
                  icon: Tooltip(
                    message:
                        '${_destinationLabel(context, index)} · Ctrl+${index + 1}',
                    child: Icon(AppShell._destinations[index].icon),
                  ),
                  selectedIcon:
                      Icon(AppShell._destinations[index].selectedIcon),
                  label: Text(_destinationLabel(context, index)),
                ),
            ],
          ),
          VerticalDivider(width: 1, color: colors.outlineVariant),
          Expanded(child: pageStack),
        ],
      ),
    );
  }
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({
    required this.selectedIndex,
    required this.onSelected,
    required this.pageStack,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget pageStack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: pageStack,
      bottomNavigationBar: DecoratedBox(
        key: const Key('appBottomNavigation'),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: Row(
              children: [
                for (var index = 0;
                    index < AppShell._destinations.length;
                    index++)
                  Expanded(
                    child: _BottomNavigationItem(
                      key: ValueKey('bottomNavigationDestination:$index'),
                      destination: AppShell._destinations[index],
                      label: _destinationLabel(context, index),
                      compactLabel: _compactDestinationLabel(context, index),
                      selected: selectedIndex == index,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationItem extends StatefulWidget {
  const _BottomNavigationItem({
    super.key,
    required this.destination,
    required this.label,
    required this.compactLabel,
    required this.selected,
    required this.onTap,
  });

  final _AppDestination destination;
  final String label;
  final String compactLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_BottomNavigationItem> createState() => _BottomNavigationItemState();
}

class _BottomNavigationItemState extends State<_BottomNavigationItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantics = context.semanticColors;
    final foreground =
        widget.selected ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: widget.label,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: Material(
              color: colors.surface.withValues(alpha: 0),
              child: InkWell(
                onTap: widget.onTap,
                onFocusChange: (focused) {
                  if (_focused != focused) {
                    setState(() => _focused = focused);
                  }
                },
                borderRadius: BorderRadius.circular(AppRadii.medium),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 64,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? semantics.surfaceSelected
                        : colors.surface.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    border: _focused
                        ? Border.all(color: semantics.focus, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconTheme(
                        data: IconThemeData(color: foreground, size: 24),
                        child: Icon(
                          widget.selected
                              ? widget.destination.selectedIcon
                              : widget.destination.icon,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        widget.compactLabel,
                        maxLines: 2,
                        softWrap: true,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: foreground,
                              fontWeight: widget.selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
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
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final brandName = context.l10n.text(
      zh: '声流 VoxFlow',
      en: 'VoxFlow',
    );
    return Semantics(
      label: brandName,
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xl,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  Icons.multitrack_audio,
                  color: colors.onPrimaryContainer,
                  size: 24,
                ),
              ),
            ),
            if (extended) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(brandName, style: Theme.of(context).textTheme.titleSmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination({required this.icon, required this.selectedIcon});

  final IconData icon;
  final IconData selectedIcon;
}

String _destinationLabel(BuildContext context, int index) {
  final l10n = context.l10n;
  return switch (index) {
    0 => l10n.text(zh: '语音转文字', en: 'Speech to text'),
    1 => l10n.text(zh: '文字转语音', en: 'Text to speech'),
    2 => l10n.text(zh: '历史记录', en: 'History'),
    _ => l10n.text(zh: '设置', en: 'Settings'),
  };
}

String _compactDestinationLabel(BuildContext context, int index) {
  final l10n = context.l10n;
  return switch (index) {
    0 => l10n.text(zh: '转录', en: 'STT'),
    1 => l10n.text(zh: '合成', en: 'TTS'),
    2 => l10n.text(zh: '历史', en: 'History'),
    _ => l10n.text(zh: '设置', en: 'Settings'),
  };
}
