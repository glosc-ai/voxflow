import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/windows_window_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../history/views/history_screen.dart';
import '../../settings/views/settings_screen.dart';
import '../../settings/models/settings_state.dart';
import '../../settings/providers/settings_provider.dart';
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
  late final Future<String?> _windowVersion;
  bool _navigationInProgress = false;
  Brightness? _reportedWindowBrightness;

  @override
  void initState() {
    super.initState();
    _windowVersion = WindowsWindowService.version();
    unawaited(WindowsWindowService.enableFrameless());
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_reportedWindowBrightness != brightness) {
      _reportedWindowBrightness = brightness;
      unawaited(WindowsWindowService.setBrightness(brightness));
    }
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

  bool _bareNavigationShortcutIsSafe() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null ||
        _pageFocusNodes.contains(FocusManager.instance.primaryFocus)) {
      return true;
    }

    bool blocksBareShortcut(Widget widget) =>
        widget is EditableText ||
        widget is DropdownButton<dynamic> ||
        widget is DropdownButtonFormField<dynamic> ||
        widget is PopupMenuButton<dynamic> ||
        widget is MenuAnchor;

    var blocked = blocksBareShortcut(focusContext.widget);
    focusContext.visitAncestorElements((element) {
      blocked = blocked || blocksBareShortcut(element.widget);
      return !blocked;
    });
    return !blocked;
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

    final useDesktopShortcuts =
        Theme.of(context).platform != TargetPlatform.android;
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
        if (useDesktopShortcuts) ...{
          _SafeNavigationActivator(
            LogicalKeyboardKey.digit1,
            _bareNavigationShortcutIsSafe,
          ): () => _select(0),
          _SafeNavigationActivator(
            LogicalKeyboardKey.digit2,
            _bareNavigationShortcutIsSafe,
          ): () => _select(1),
          _SafeNavigationActivator(
            LogicalKeyboardKey.digit3,
            _bareNavigationShortcutIsSafe,
          ): () => _select(2),
          _SafeNavigationActivator(
            LogicalKeyboardKey.digit4,
            _bareNavigationShortcutIsSafe,
          ): () => _select(3),
        },
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selectedIndex = ref.watch(navigationIndexProvider);
          final isAndroid =
              Theme.of(context).platform == TargetPlatform.android;
          final isExtended =
              constraints.maxWidth > AppBreakpoints.desktopRailCompact &&
                  MediaQuery.textScalerOf(context).scale(1) < 1.6;
          if (!isAndroid) {
            return _DesktopShell(
              selectedIndex: selectedIndex,
              extended: isExtended,
              onSelected: _select,
              pageStack: _pageStack(selectedIndex),
              windowVersion: _windowVersion,
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

class _SafeNavigationActivator extends ShortcutActivator {
  const _SafeNavigationActivator(this.key, this.isSafe);

  final LogicalKeyboardKey key;
  final bool Function() isSafe;

  SingleActivator get _activator => SingleActivator(key);

  @override
  Iterable<LogicalKeyboardKey>? get triggers => _activator.triggers;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    return _activator.accepts(event, state) && isSafe();
  }

  @override
  String debugDescribeKeys() => _activator.debugDescribeKeys();
}

class _DesktopShell extends ConsumerWidget {
  const _DesktopShell({
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
    required this.pageStack,
    required this.windowVersion,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;
  final Widget pageStack;
  final Future<String?> windowVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final connection = _connectionPresentation(context, settings);
    return Scaffold(
      key: const Key('desktopShell'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: _DesktopTitleBar(
                selectedIndex: selectedIndex,
                connection: connection,
                version: windowVersion,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: extended ? 240 : 76,
                    child: _DesktopNavigation(
                      selectedIndex: selectedIndex,
                      extended: extended,
                      connection: connection,
                      onSelected: onSelected,
                      onToggleTheme: () => _toggleTheme(context, ref),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: ClipRect(child: pageStack)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTheme(BuildContext context, WidgetRef ref) async {
    final next = Theme.of(context).brightness == Brightness.dark
        ? AppThemePreference.light
        : AppThemePreference.dark;
    try {
      await ref.read(settingsProvider.notifier).setThemePreference(next);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.text(
                zh: '无法切换主题，请重试。',
                en: 'The theme could not be changed. Try again.',
              ),
            ),
          ),
        );
      }
    }
  }
}

class _DesktopTitleBar extends StatelessWidget {
  const _DesktopTitleBar({
    required this.selectedIndex,
    required this.connection,
    required this.version,
  });

  final int selectedIndex;
  final _ConnectionPresentation connection;
  final Future<String?> version;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _GlassSurface(
      key: const Key('desktopTitleBar'),
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(16),
      ),
      floating: false,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => unawaited(WindowsWindowService.startDrag()),
              onDoubleTap: () =>
                  unawaited(WindowsWindowService.maximizeOrRestore()),
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xl),
                child: Row(
                  children: [
                    _StatusDot(color: connection.color),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'VoxFlow',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            TextSpan(
                              text:
                                  ' · ${_destinationLabel(context, selectedIndex)}',
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          FutureBuilder<String?>(
            future: version,
            builder: (context, snapshot) {
              final value = snapshot.data;
              return Text(
                value == null ? 'Windows' : 'v$value · Windows',
                key: const Key('desktopVersionLabel'),
                style: AppTypography.numeric(
                  Theme.of(context).textTheme.labelMedium,
                ).copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 10.5,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          _WindowButton(
            key: const Key('windowMinimizeButton'),
            tooltip: context.l10n.text(zh: '最小化', en: 'Minimize'),
            icon: Icons.remove_rounded,
            onPressed: () => unawaited(WindowsWindowService.minimize()),
          ),
          _WindowButton(
            key: const Key('windowMaximizeButton'),
            tooltip: context.l10n.text(
              zh: '最大化或还原',
              en: 'Maximize or restore',
            ),
            icon: Icons.crop_square_rounded,
            onPressed: () =>
                unawaited(WindowsWindowService.maximizeOrRestore()),
          ),
          _WindowButton(
            key: const Key('windowCloseButton'),
            tooltip: context.l10n.text(zh: '关闭', en: 'Close'),
            icon: Icons.close_rounded,
            danger: true,
            onPressed: () => unawaited(WindowsWindowService.close()),
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.danger = false,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantics = context.semanticColors;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 32)),
        maximumSize: const WidgetStatePropertyAll(Size(44, 32)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (danger && states.contains(WidgetState.hovered)) {
            return colors.error;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return colors.onSurface.withValues(alpha: 0.05);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (danger && states.contains(WidgetState.hovered)) {
            return colors.onError;
          }
          return states.contains(WidgetState.hovered)
              ? colors.onSurface
              : colors.onSurfaceVariant;
        }),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? BorderSide(color: semantics.focus, width: 2)
              : BorderSide.none,
        ),
      ),
      icon: Icon(icon, size: 16),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selectedIndex,
    required this.extended,
    required this.connection,
    required this.onSelected,
    required this.onToggleTheme,
  });

  final int selectedIndex;
  final bool extended;
  final _ConnectionPresentation connection;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      key: const Key('desktopNavigation'),
      borderRadius: BorderRadius.circular(AppRadii.desktopCard),
      floating: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          extended ? 14 : 10,
          20,
          extended ? 14 : 10,
          14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DesktopBrand(extended: extended),
            const SizedBox(height: 18),
            _DesktopApiStatus(
              extended: extended,
              presentation: connection,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (var index = 0; index < 3; index++) ...[
              _DesktopNavigationItem(
                key: ValueKey('desktopNavigationDestination:$index'),
                destination: AppShell._destinations[index],
                label: _destinationLabel(context, index),
                shortcut: '${index + 1}',
                selected: selectedIndex == index,
                extended: extended,
                onTap: () => onSelected(index),
              ),
              if (index < 2) const SizedBox(height: AppSpacing.xxs),
            ],
            const Spacer(),
            _DesktopNavigationItem(
              key: const Key('desktopThemeToggle'),
              destination: _AppDestination(
                icon: Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                selectedIcon: Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              label: Theme.of(context).brightness == Brightness.dark
                  ? context.l10n.text(zh: '浅色模式', en: 'Light mode')
                  : context.l10n.text(zh: '深色模式', en: 'Dark mode'),
              selected: false,
              extended: extended,
              onTap: onToggleTheme,
            ),
            const SizedBox(height: AppSpacing.xxs),
            _DesktopNavigationItem(
              key: const ValueKey('desktopNavigationDestination:3'),
              destination: AppShell._destinations[3],
              label: _destinationLabel(context, 3),
              shortcut: '4',
              selected: selectedIndex == 3,
              extended: extended,
              onTap: () => onSelected(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopBrand extends StatelessWidget {
  const _DesktopBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mark = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.34),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: 34,
        child: Icon(
          Icons.graphic_eq_rounded,
          color: colors.onPrimary,
          size: 22,
        ),
      ),
    );
    if (!extended) {
      return Center(child: mark);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VoxFlow',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  'VOICE STUDIO',
                  maxLines: 1,
                  style: AppTypography.numeric(
                    Theme.of(context).textTheme.labelMedium,
                  ).copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                    letterSpacing: 0.6,
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

class _DesktopApiStatus extends StatelessWidget {
  const _DesktopApiStatus({
    required this.extended,
    required this.presentation,
  });

  final bool extended;
  final _ConnectionPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = AnimatedContainer(
      key: const Key('apiConnectionStatus'),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: extended ? AppSpacing.sm : 0,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.desktopControl),
      ),
      child: Row(
        mainAxisAlignment:
            extended ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          _StatusDot(color: presentation.color),
          if (extended) ...[
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                presentation.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                    ),
              ),
            ),
            Text(
              presentation.meta,
              style: AppTypography.numeric(
                Theme.of(context).textTheme.labelMedium,
              ).copyWith(color: colors.onSurfaceVariant, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: extended ? 4 : 0),
      child: Tooltip(message: presentation.label, child: content),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8),
        ],
      ),
    );
  }
}

class _DesktopNavigationItem extends StatefulWidget {
  const _DesktopNavigationItem({
    required this.destination,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
    this.shortcut,
    super.key,
  });

  final _AppDestination destination;
  final String label;
  final String? shortcut;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  State<_DesktopNavigationItem> createState() => _DesktopNavigationItemState();
}

class _DesktopNavigationItemState extends State<_DesktopNavigationItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantics = context.semanticColors;
    final foreground =
        widget.selected ? colors.primary : colors.onSurfaceVariant;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final item = Semantics(
      key: widget.selected
          ? ValueKey(
              'desktopSelectedNavigationDestination:${widget.shortcut}',
            )
          : null,
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          borderRadius: BorderRadius.circular(AppRadii.desktopControl),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.ease,
            constraints: const BoxConstraints(minHeight: 42),
            transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
            padding: EdgeInsets.symmetric(
              horizontal: widget.extended ? AppSpacing.sm : 0,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? semantics.surfaceSelected
                  : (_hovered
                      ? colors.onSurface.withValues(alpha: 0.05)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(AppRadii.desktopControl),
              border: _focused
                  ? Border.all(color: semantics.focus, width: 2)
                  : null,
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.08),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: widget.extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  widget.selected
                      ? widget.destination.selectedIcon
                      : widget.destination.icon,
                  color: foreground,
                  size: 19,
                ),
                if (widget.extended) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: foreground,
                            fontSize: 14.5,
                            fontWeight: widget.selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                    ),
                  ),
                  if (widget.shortcut != null)
                    _ShortcutBadge(
                      label: widget.shortcut!,
                      selected: widget.selected,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return widget.extended
        ? item
        : Tooltip(
            message: widget.shortcut == null
                ? widget.label
                : '${widget.label} · Ctrl+${widget.shortcut}',
            child: item,
          );
  }
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: selected ? Colors.transparent : colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(
          color: selected
              ? colors.primary.withValues(alpha: 0.35)
              : colors.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.numeric(
          Theme.of(context).textTheme.labelMedium,
        ).copyWith(
          color: selected ? colors.primary : colors.onSurfaceVariant,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.borderRadius,
    required this.floating,
    required this.child,
    super.key,
  });

  final BorderRadius borderRadius;
  final bool floating;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effects = context.surfaceEffects;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return AnimatedContainer(
      duration: duration,
      curve: Curves.ease,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          floating ? effects.floatingShadow : effects.cardShadow,
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.ease,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: effects.glassOpacity),
              borderRadius: borderRadius,
              border: Border.all(color: colors.outlineVariant),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ConnectionPresentation {
  const _ConnectionPresentation({
    required this.color,
    required this.label,
    required this.meta,
  });

  final Color color;
  final String label;
  final String meta;
}

_ConnectionPresentation _connectionPresentation(
  BuildContext context,
  SettingsState settings,
) {
  final colors = Theme.of(context).colorScheme;
  final semantics = context.semanticColors;
  if (settings.activeOperation == SettingsOperation.testingConnection) {
    return _ConnectionPresentation(
      color: colors.primary,
      label: context.l10n.text(zh: '正在检测 API', en: 'Testing API'),
      meta: '…',
    );
  }
  if (settings.lastConnectionSucceeded == true) {
    return _ConnectionPresentation(
      color: semantics.success,
      label: context.l10n.text(zh: 'API 已连接', en: 'API connected'),
      meta: 'OK',
    );
  }
  if (settings.lastConnectionSucceeded == false) {
    return _ConnectionPresentation(
      color: colors.error,
      label: context.l10n.text(zh: 'API 连接失败', en: 'API unavailable'),
      meta: 'ERR',
    );
  }
  if (settings.hasApiKey) {
    return _ConnectionPresentation(
      color: colors.onSurfaceVariant,
      label: context.l10n.text(zh: 'API 已配置', en: 'API configured'),
      meta: 'SET',
    );
  }
  return _ConnectionPresentation(
    color: colors.onSurfaceVariant,
    label: context.l10n.text(zh: 'API 尚未配置', en: 'API not configured'),
    meta: '--',
  );
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
