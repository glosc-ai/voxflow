import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_status_banner.dart';
import '../models/history_record.dart';
import '../providers/history_provider.dart';

enum _HistoryFilter { all, stt, tts }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.pageFocusNode});

  final FocusNode? pageFocusNode;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _activeQuery = '';
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode(debugLabel: 'historySearch');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final playback = ref.watch(historyPlaybackProvider);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final usesLargeText = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final cachedRecords = history.valueOrNull;
    final useDesktopLayout =
        Theme.of(context).platform == TargetPlatform.windows &&
            MediaQuery.sizeOf(context).width >= 760;
    final loadErrorMessage = history.hasError
        ? history.error is AppException
            ? l10n.appError(history.error! as AppException)
            : l10n.text(
                zh: '无法加载历史记录。',
                en: 'History could not be loaded.',
              )
        : null;
    ref.listen<String?>(
      historyPlaybackProvider.select((value) => value.errorMessageFor(locale)),
      (previous, next) {
        if (next != null && next != previous) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next)),
          );
        }
      },
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focusSearch,
      },
      child: Focus(
        key: const Key('historyPageFocus'),
        focusNode: widget.pageFocusNode,
        autofocus: widget.pageFocusNode == null,
        skipTraversal: true,
        child: useDesktopLayout
            ? _buildDesktopPage(
                history: history,
                cachedRecords: cachedRecords,
                loadErrorMessage: loadErrorMessage,
                playback: playback,
              )
            : Scaffold(
                appBar: AppBar(
                  toolbarHeight: AppTheme.responsiveAppBarHeight(
                    context,
                    largeTextMaxLines: 1,
                  ),
                  title: Text(
                    l10n.text(zh: '历史记录', en: 'History'),
                    maxLines: 1,
                  ),
                  actions: [
                    IconButton(
                      tooltip: l10n.text(zh: '刷新', en: 'Refresh'),
                      onPressed: ref.read(historyProvider.notifier).load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                body: FocusTraversalGroup(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Padding(
                        padding: AppLayout.pagePadding(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              usesLargeText
                                  ? l10n.text(
                                      zh: '查找并管理本机历史记录。',
                                      en: 'Find and manage local history.',
                                    )
                                  : l10n.text(
                                      zh: '查找转录与语音合成记录，并管理保存在本机的关联音频。',
                                      en: 'Find transcripts and generated speech, and manage associated audio stored on this device.',
                                    ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              key: const Key('historySearchField'),
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              textInputAction: TextInputAction.search,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: _submitSearch,
                              decoration: InputDecoration(
                                labelText: l10n.text(
                                  zh: '搜索历史记录',
                                  en: 'Search history',
                                ),
                                hintText: l10n.text(
                                  zh: '搜索转录或合成文字',
                                  en: 'Search transcripts or generated text',
                                ),
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: l10n.text(
                                          zh: '清空搜索',
                                          en: 'Clear search',
                                        ),
                                        onPressed: _clearSearch,
                                        icon: const Icon(Icons.clear),
                                      ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Expanded(
                              child: cachedRecords != null
                                  ? _HistoryResults(
                                      records: cachedRecords,
                                      isRefreshing: history.isLoading,
                                      loadErrorMessage: loadErrorMessage,
                                      onRetry: ref
                                          .read(historyProvider.notifier)
                                          .load,
                                      query: _activeQuery,
                                      playback: playback,
                                      onClearSearch: _clearSearch,
                                      onPlay: (record) => ref
                                          .read(
                                              historyPlaybackProvider.notifier)
                                          .toggle(record),
                                      onCopy: (record) => _copy(record.text),
                                      onDelete: _delete,
                                    )
                                  : history.isLoading
                                      ? _LoadingState(
                                          isSearch: _activeQuery.isNotEmpty,
                                        )
                                      : _ErrorState(
                                          message: loadErrorMessage ??
                                              l10n.text(
                                                zh: '无法加载历史记录。',
                                                en: 'History could not be loaded.',
                                              ),
                                          onRetry: ref
                                              .read(historyProvider.notifier)
                                              .load,
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

  Widget _buildDesktopPage({
    required AsyncValue<List<HistoryRecord>> history,
    required List<HistoryRecord>? cachedRecords,
    required String? loadErrorMessage,
    required HistoryPlaybackState playback,
  }) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final filteredRecords = cachedRecords
        ?.where(
          (record) => switch (_filter) {
            _HistoryFilter.all => true,
            _HistoryFilter.stt => record.type == HistoryType.stt,
            _HistoryFilter.tts => record.type == HistoryType.tts,
          },
        )
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FocusTraversalGroup(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: AppLayout.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stackHeader = constraints.maxWidth < 560 ||
                          MediaQuery.textScalerOf(context).scale(1) >= 1.6;
                      final title = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.text(
                              zh: 'LIBRARY · 本地存档',
                              en: 'LIBRARY · LOCAL ARCHIVE',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.text(zh: '历史记录', en: 'History'),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.6,
                                ),
                          ),
                        ],
                      );
                      final refreshButton = IconButton(
                        tooltip: l10n.text(zh: '刷新', en: 'Refresh'),
                        onPressed: ref.read(historyProvider.notifier).load,
                        icon: const Icon(Icons.refresh),
                      );
                      if (stackHeader) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: AppSpacing.sm),
                            refreshButton,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: title),
                          refreshButton,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stackControls = constraints.maxWidth < 680 ||
                          MediaQuery.textScalerOf(context).scale(1) >= 1.6;
                      final searchField = TextField(
                        key: const Key('historySearchField'),
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: _submitSearch,
                        decoration: InputDecoration(
                          labelText: l10n.text(
                            zh: '搜索历史记录',
                            en: 'Search history',
                          ),
                          hintText: l10n.text(
                            zh: '搜索转录或合成文字',
                            en: 'Search transcripts or generated text',
                          ),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: l10n.text(
                                    zh: '清空搜索',
                                    en: 'Clear search',
                                  ),
                                  onPressed: _clearSearch,
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      );
                      final filters = _DesktopHistoryFilters(
                        value: _filter,
                        onChanged: (filter) => setState(() => _filter = filter),
                      );
                      if (stackControls) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            searchField,
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: filters,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: AppSpacing.md),
                          filters,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: filteredRecords != null
                        ? _HistoryResults(
                            records: filteredRecords,
                            isRefreshing: history.isLoading,
                            loadErrorMessage: loadErrorMessage,
                            onRetry: ref.read(historyProvider.notifier).load,
                            query: _activeQuery,
                            playback: playback,
                            onClearSearch: _clearSearch,
                            onPlay: (record) => ref
                                .read(historyPlaybackProvider.notifier)
                                .toggle(record),
                            onCopy: (record) => _copy(record.text),
                            onDelete: _delete,
                            desktop: true,
                            hasTypeFilter: _filter != _HistoryFilter.all,
                            onClearTypeFilter: () => setState(
                              () => _filter = _HistoryFilter.all,
                            ),
                          )
                        : history.isLoading
                            ? _LoadingState(
                                isSearch: _activeQuery.isNotEmpty,
                              )
                            : _ErrorState(
                                message: loadErrorMessage ??
                                    l10n.text(
                                      zh: '无法加载历史记录。',
                                      en: 'History could not be loaded.',
                                    ),
                                onRetry:
                                    ref.read(historyProvider.notifier).load,
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  void _submitSearch(String query) {
    final normalizedQuery = query.trim();
    setState(() => _activeQuery = normalizedQuery);
    ref.read(historyProvider.notifier).load(query: normalizedQuery);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _activeQuery = '');
    ref.read(historyProvider.notifier).load(query: '');
    _searchFocusNode.requestFocus();
  }

  Future<void> _copy(String text) async {
    final l10n = context.l10n;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.text(
              zh: '文字已复制。',
              en: 'Text copied.',
            )),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.text(
              zh: '无法复制文字，请重试。',
              en: 'Text could not be copied. Try again.',
            )),
          ),
        );
      }
    }
  }

  Future<void> _delete(HistoryRecord record) async {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: colors.error),
        title: Text(l10n.text(
          zh: '删除历史记录？',
          en: 'Delete history item?',
        )),
        content: Text(
          l10n.text(
            zh: '将从历史记录中移除此项目。若音频位于声流管理目录，也会同时删除关联音频。此操作无法撤销。',
            en: 'This item will be removed from history. Associated audio in the VoxFlow managed folder will also be deleted. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.text(zh: '取消', en: 'Cancel')),
          ),
          Semantics(
            button: true,
            label: l10n.text(
              zh: '确认删除历史记录，此操作无法撤销',
              en: 'Confirm deletion of this history item. This cannot be undone.',
            ),
            excludeSemantics: true,
            onTap: () => Navigator.pop(context, true),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.text(zh: '删除', en: 'Delete')),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      final playback = ref.read(historyPlaybackProvider);
      if (playback.recordId == record.id) {
        await ref.read(historyPlaybackProvider.notifier).stop();
      }
      final warning = await ref.read(historyProvider.notifier).delete(record);
      if (mounted) {
        final feedback = warning == null
            ? l10n.text(
                zh: '历史记录已删除。',
                en: 'History item deleted.',
              )
            : l10n.text(
                zh: warning,
                en: 'The history item was deleted, but its audio file could not be removed.',
              );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(feedback)),
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.appError(error))),
        );
      }
    }
  }
}

class _HistoryResults extends StatelessWidget {
  const _HistoryResults({
    required this.records,
    required this.isRefreshing,
    required this.loadErrorMessage,
    required this.onRetry,
    required this.query,
    required this.playback,
    required this.onClearSearch,
    required this.onPlay,
    required this.onCopy,
    required this.onDelete,
    this.desktop = false,
    this.hasTypeFilter = false,
    this.onClearTypeFilter,
  });

  final List<HistoryRecord> records;
  final bool isRefreshing;
  final String? loadErrorMessage;
  final VoidCallback onRetry;
  final String query;
  final HistoryPlaybackState playback;
  final VoidCallback onClearSearch;
  final ValueChanged<HistoryRecord> onPlay;
  final ValueChanged<HistoryRecord> onCopy;
  final ValueChanged<HistoryRecord> onDelete;
  final bool desktop;
  final bool hasTypeFilter;
  final VoidCallback? onClearTypeFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = records.length;
    final resultLabel = query.isEmpty
        ? l10n.text(
            zh: '共 $count 条记录',
            en: '$count history ${count == 1 ? 'item' : 'items'}',
          )
        : l10n.text(
            zh: '“$query”的搜索结果：$count 条',
            en: '$count ${count == 1 ? 'result' : 'results'} for “$query”',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loadErrorMessage != null) ...[
          AppStatusBanner(
            kind: AppStatusKind.error,
            title: l10n.text(
              zh: '历史记录未更新',
              en: 'History was not updated',
            ),
            message: loadErrorMessage!,
            messageKey: const Key('historyRefreshErrorMessage'),
            action: OutlinedButton.icon(
              key: const Key('historyRefreshRetryButton'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.text(zh: '重试', en: 'Retry')),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ] else if (isRefreshing) ...[
          Semantics(
            liveRegion: true,
            label: l10n.text(
              zh: '正在更新历史记录',
              en: 'Updating history',
            ),
            child: const LinearProgressIndicator(
              key: Key('historyRefreshProgress'),
              minHeight: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Semantics(
          liveRegion: true,
          label: resultLabel,
          child: Row(
            children: [
              Icon(
                query.isEmpty ? Icons.history : Icons.filter_alt_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  resultLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: records.isEmpty
              ? _EmptyState(
                  query: query,
                  onClearSearch: onClearSearch,
                  hasTypeFilter: hasTypeFilter,
                  onClearTypeFilter: onClearTypeFilter,
                )
              : desktop
                  ? _DesktopHistoryGrid(
                      records: records,
                      playback: playback,
                      onPlay: onPlay,
                      onCopy: onCopy,
                      onDelete: onDelete,
                    )
                  : _HistoryList(
                      records: records,
                      playback: playback,
                      onPlay: onPlay,
                      onCopy: onCopy,
                      onDelete: onDelete,
                    ),
        ),
      ],
    );
  }
}

class _DesktopHistoryFilters extends StatelessWidget {
  const _DesktopHistoryFilters({
    required this.value,
    required this.onChanged,
  });

  final _HistoryFilter value;
  final ValueChanged<_HistoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _DesktopFilterChip(
          key: const Key('historyFilterAll'),
          label: l10n.text(zh: '全部', en: 'All'),
          selected: value == _HistoryFilter.all,
          onPressed: () => onChanged(_HistoryFilter.all),
        ),
        _DesktopFilterChip(
          key: const Key('historyFilterStt'),
          label: l10n.text(zh: 'STT 转写', en: 'STT transcripts'),
          selected: value == _HistoryFilter.stt,
          onPressed: () => onChanged(_HistoryFilter.stt),
        ),
        _DesktopFilterChip(
          key: const Key('historyFilterTts'),
          label: l10n.text(zh: 'TTS 配音', en: 'TTS speech'),
          selected: value == _HistoryFilter.tts,
          onPressed: () => onChanged(_HistoryFilter.tts),
        ),
      ],
    );
  }
}

class _DesktopFilterChip extends StatefulWidget {
  const _DesktopFilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_DesktopFilterChip> createState() => _DesktopFilterChipState();
}

class _DesktopFilterChipState extends State<_DesktopFilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final foreground = widget.selected
        ? colors.surface
        : (_hovered ? colors.onSurface : colors.onSurfaceVariant);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: ExcludeSemantics(
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: duration,
            decoration: BoxDecoration(
              color: widget.selected ? colors.onSurface : colors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color:
                    widget.selected ? colors.onSurface : colors.outlineVariant,
              ),
              boxShadow: _hovered && !widget.selected
                  ? [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.07),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: widget.onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
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

class _DesktopHistoryGrid extends StatelessWidget {
  const _DesktopHistoryGrid({
    required this.records,
    required this.playback,
    required this.onPlay,
    required this.onCopy,
    required this.onDelete,
  });

  final List<HistoryRecord> records;
  final HistoryPlaybackState playback;
  final ValueChanged<HistoryRecord> onPlay;
  final ValueChanged<HistoryRecord> onCopy;
  final ValueChanged<HistoryRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final singleColumn = textScale >= 1.3 || constraints.maxWidth < 680;
        final entries = records.indexed.toList(growable: false);

        Widget card((int, HistoryRecord) entry) {
          final (index, record) = entry;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: FocusTraversalOrder(
              order: NumericFocusOrder(index.toDouble()),
              child: _DesktopHistoryCard(
                record: record,
                semanticOrder: index.toDouble(),
                isPlaying: playback.recordId == record.id && playback.isPlaying,
                onPlay: () => onPlay(record),
                onCopy: () => onCopy(record),
                onDelete: () => onDelete(record),
              ),
            ),
          );
        }

        final content = singleColumn
            ? Column(children: entries.map(card).toList(growable: false))
            : _DesktopMasonryColumns(entries: entries, itemBuilder: card);

        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Scrollbar(
            child: SingleChildScrollView(
              primary: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class _DesktopMasonryColumns extends StatelessWidget {
  const _DesktopMasonryColumns({
    required this.entries,
    required this.itemBuilder,
  });

  final List<(int, HistoryRecord)> entries;
  final Widget Function((int, HistoryRecord)) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final left = <(int, HistoryRecord)>[];
    final right = <(int, HistoryRecord)>[];
    var leftWeight = 0.0;
    var rightWeight = 0.0;
    for (final entry in entries) {
      final weight = 132 + entry.$2.text.runes.length.clamp(0, 220) * 0.48;
      if (leftWeight <= rightWeight) {
        left.add(entry);
        leftWeight += weight;
      } else {
        right.add(entry);
        rightWeight += weight;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: left.map(itemBuilder).toList(growable: false),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            children: right.map(itemBuilder).toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _DesktopHistoryCard extends StatefulWidget {
  const _DesktopHistoryCard({
    required this.record,
    required this.semanticOrder,
    required this.isPlaying,
    required this.onPlay,
    required this.onCopy,
    required this.onDelete,
  });

  final HistoryRecord record;
  final double semanticOrder;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  State<_DesktopHistoryCard> createState() => _DesktopHistoryCardState();
}

class _DesktopHistoryCardState extends State<_DesktopHistoryCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantics = context.semanticColors;
    final l10n = context.l10n;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
    final typeLabel = widget.record.type == HistoryType.stt ? 'STT' : 'TTS';
    final typeColor = widget.record.type == HistoryType.stt
        ? colors.primary
        : semantics.success;
    final typeBackground = widget.record.type == HistoryType.stt
        ? colors.primaryContainer
        : semantics.successContainer;
    final formattedDate = _dateTime(context, widget.record.createdAt.toLocal());
    final showActions = _hovered || _focused || textScale >= 1.3;
    final semanticText = widget.record.text.length > 180
        ? '${widget.record.text.substring(0, 180)}…'
        : widget.record.text;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      sortKey: OrdinalSortKey(widget.semanticOrder),
      label: l10n.text(
        zh: '$typeLabel 记录，$formattedDate。$semanticText',
        en: '$typeLabel item, $formattedDate. $semanticText',
      ),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (focused) {
          if (_focused != focused) {
            setState(() => _focused = focused);
          }
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(
                    alpha: _hovered ? 0.10 : 0.045,
                  ),
                  blurRadius: _hovered ? 28 : 16,
                  offset: Offset(0, _hovered ? 8 : 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 17, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ExcludeSemantics(
                        child: Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: typeBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs,
                                ),
                                child: Text(
                                  typeLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                    color: typeColor,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    fontFamily: 'Cascadia Code',
                                    fontFamilyFallback: const [
                                      'JetBrains Mono',
                                      'Consolas',
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (widget.isPlaying) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.graphic_eq,
                                size: 16,
                                color: colors.primary,
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                l10n.text(zh: '正在播放', en: 'Playing'),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                            const Spacer(),
                            const SizedBox(width: 104),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ExcludeSemantics(
                        child: Text(
                          widget.record.text,
                          maxLines: textScale >= 1.3 ? null : 5,
                          overflow: textScale >= 1.3
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.6,
                                  ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Divider(color: colors.outlineVariant),
                      const SizedBox(height: AppSpacing.xs),
                      ExcludeSemantics(
                        child: Text(
                          formattedDate,
                          textAlign: TextAlign.end,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFamily: 'Cascadia Code',
                            fontFamilyFallback: const [
                              'JetBrains Mono',
                              'Consolas',
                            ],
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  top: AppSpacing.sm,
                  end: AppSpacing.sm,
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: showActions ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !showActions,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: 0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _DesktopHistoryAction(
                              tooltip: widget.isPlaying
                                  ? l10n.text(zh: '暂停', en: 'Pause')
                                  : l10n.text(zh: '播放', en: 'Play'),
                              icon: widget.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              onPressed: widget.onPlay,
                            ),
                            _DesktopHistoryAction(
                              tooltip: l10n.text(zh: '复制', en: 'Copy'),
                              icon: Icons.copy_outlined,
                              onPressed: widget.onCopy,
                            ),
                            Semantics(
                              button: true,
                              label: l10n.text(
                                zh: '删除此条历史记录，需要确认',
                                en: 'Delete this history item. Confirmation required.',
                              ),
                              excludeSemantics: true,
                              child: _DesktopHistoryAction(
                                tooltip: l10n.text(zh: '删除', en: 'Delete'),
                                icon: Icons.delete_outline,
                                foregroundColor: colors.error,
                                onPressed: widget.onDelete,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _DesktopHistoryAction extends StatelessWidget {
  const _DesktopHistoryAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.foregroundColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: foregroundColor,
      icon: Icon(icon, size: 17),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.records,
    required this.playback,
    required this.onPlay,
    required this.onCopy,
    required this.onDelete,
  });

  final List<HistoryRecord> records;
  final HistoryPlaybackState playback;
  final ValueChanged<HistoryRecord> onPlay;
  final ValueChanged<HistoryRecord> onCopy;
  final ValueChanged<HistoryRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.large),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: records.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: colors.outlineVariant,
          ),
          itemBuilder: (context, index) {
            final record = records[index];
            return _HistoryListItem(
              record: record,
              isPlaying: playback.recordId == record.id && playback.isPlaying,
              onPlay: () => onPlay(record),
              onCopy: () => onCopy(record),
              onDelete: () => onDelete(record),
            );
          },
        ),
      ),
    );
  }
}

class _HistoryListItem extends StatelessWidget {
  const _HistoryListItem({
    required this.record,
    required this.isPlaying,
    required this.onPlay,
    required this.onCopy,
    required this.onDelete,
  });

  final HistoryRecord record;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final icon = record.type == HistoryType.stt
        ? Icons.graphic_eq
        : Icons.record_voice_over;
    final typeLabel = _historyTypeLabel(context, record.type);
    final formattedDate = _dateTime(context, record.createdAt.toLocal());
    final semanticText = record.text.length > 160
        ? '${record.text.substring(0, 160)}…'
        : record.text;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackMetadata = textScale >= 1.3 || constraints.maxWidth < 560;
        final wrapActions = textScale >= 1.3 || constraints.maxWidth < 600;
        final unlimitedSummary = textScale >= 1.3;

        return Semantics(
          container: true,
          explicitChildNodes: true,
          label: context.l10n.text(
            zh: '$typeLabel 记录，$formattedDate。$semanticText',
            en: '$typeLabel item, $formattedDate. $semanticText',
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: SizedBox.square(
                      dimension: AppSpacing.xxxl,
                      child: Icon(
                        icon,
                        size: 20,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: stackMetadata
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _RecordTypeLine(
                                    label: typeLabel,
                                    isPlaying: isPlaying,
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    formattedDate,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _RecordTypeLine(
                                      label: typeLabel,
                                      isPlaying: isPlaying,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Text(
                                    formattedDate,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ExcludeSemantics(
                        child: Text(
                          record.text,
                          maxLines: unlimitedSummary ? null : 2,
                          overflow: unlimitedSummary
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _RecordActions(
                        isPlaying: isPlaying,
                        wrap: wrapActions,
                        onPlay: onPlay,
                        onCopy: onCopy,
                        onDelete: onDelete,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecordTypeLine extends StatelessWidget {
  const _RecordTypeLine({required this.label, required this.isPlaying});

  final String label;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (isPlaying)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.volume_up_outlined,
                    size: 16,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    context.l10n.text(zh: '正在播放', en: 'Playing'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordActions extends StatelessWidget {
  const _RecordActions({
    required this.isPlaying,
    required this.wrap,
    required this.onPlay,
    required this.onCopy,
    required this.onDelete,
  });

  final bool isPlaying;
  final bool wrap;
  final VoidCallback onPlay;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final minimumHeight = isAndroid ? AppSpacing.huge : AppSpacing.xxxl;
    final actionStyle = TextButton.styleFrom(
      minimumSize: Size(AppSpacing.xxxl, minimumHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );

    final playButton = TextButton.icon(
      style: actionStyle,
      onPressed: onPlay,
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      label: Text(
        isPlaying
            ? context.l10n.text(zh: '暂停', en: 'Pause')
            : context.l10n.text(zh: '播放', en: 'Play'),
      ),
    );
    final copyButton = TextButton.icon(
      style: actionStyle,
      onPressed: onCopy,
      icon: const Icon(Icons.copy_outlined),
      label: Text(context.l10n.text(zh: '复制', en: 'Copy')),
    );
    final deleteButton = Semantics(
      button: true,
      label: context.l10n.text(
        zh: '删除此条历史记录，需要确认',
        en: 'Delete this history item. Confirmation required.',
      ),
      excludeSemantics: true,
      onTap: onDelete,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: colors.error,
          minimumSize: Size(AppSpacing.xxxl, minimumHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
        label: Text(context.l10n.text(zh: '删除', en: 'Delete')),
      ),
    );

    if (wrap) {
      return Wrap(
        spacing: AppSpacing.xxs,
        runSpacing: AppSpacing.xxs,
        children: [playButton, copyButton, deleteButton],
      );
    }

    return Row(
      children: [
        playButton,
        const SizedBox(width: AppSpacing.xxs),
        copyButton,
        const Spacer(),
        deleteButton,
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.query,
    required this.onClearSearch,
    this.hasTypeFilter = false,
    this.onClearTypeFilter,
  });

  final String query;
  final VoidCallback onClearSearch;
  final bool hasTypeFilter;
  final VoidCallback? onClearTypeFilter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isSearch = query.isNotEmpty;
    final isFiltered = !isSearch && hasTypeFilter;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.large),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Icon(
                            isSearch || isFiltered
                                ? Icons.search_off
                                : Icons.history_toggle_off,
                            size: 32,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        isSearch
                            ? context.l10n.text(
                                zh: '未找到匹配的历史记录',
                                en: 'No matching history',
                              )
                            : isFiltered
                                ? context.l10n.text(
                                    zh: '此类型暂无记录',
                                    en: 'No items of this type',
                                  )
                                : context.l10n.text(
                                    zh: '暂无历史记录',
                                    en: 'No history yet',
                                  ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        isSearch
                            ? context.l10n.text(
                                zh: '没有找到包含“$query”的记录。请检查关键词或清除搜索。',
                                en: 'No items contain “$query”. Check the search term or clear the search.',
                              )
                            : isFiltered
                                ? context.l10n.text(
                                    zh: '当前筛选条件下没有记录，请切换类型查看其他本地存档。',
                                    en: 'There are no records for this filter. Choose another type to view local items.',
                                  )
                                : context.l10n.text(
                                    zh: '还没有历史记录。完成一次转录或语音合成后会显示在这里。',
                                    en: 'Completed transcripts and generated speech will appear here.',
                                  ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                      if (isSearch) ...[
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: onClearSearch,
                          icon: const Icon(Icons.clear),
                          label: Text(context.l10n.text(
                            zh: '清空搜索',
                            en: 'Clear search',
                          )),
                        ),
                      ] else if (isFiltered && onClearTypeFilter != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: onClearTypeFilter,
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: Text(context.l10n.text(
                            zh: '显示全部',
                            en: 'Show all',
                          )),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.isSearch});

  final bool isSearch;

  @override
  Widget build(BuildContext context) {
    final message = isSearch
        ? context.l10n.text(
            zh: '正在搜索历史记录…',
            en: 'Searching history…',
          )
        : context.l10n.text(
            zh: '正在加载历史记录…',
            en: 'Loading history…',
          );
    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: AppSpacing.xl,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = context.l10n.text(
      zh: '历史记录加载失败',
      en: 'History could not be loaded',
    );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Semantics(
            key: const Key('historyFullErrorState'),
            liveRegion: true,
            container: true,
            label: context.l10n.text(
              zh: '$title。$message',
              en: '$title. $message',
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  border:
                      Border.all(color: colors.error.withValues(alpha: 0.28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: colors.error,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: colors.onErrorContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  message,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: colors.onErrorContainer,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.error,
                            side: BorderSide(color: colors.error),
                          ),
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: Text(context.l10n.text(
                            zh: '重试',
                            en: 'Retry',
                          )),
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

String _historyTypeLabel(BuildContext context, HistoryType type) {
  return type == HistoryType.stt
      ? context.l10n.text(zh: '语音转文字', en: 'Speech to text')
      : context.l10n.text(zh: '文字转语音', en: 'Text to speech');
}

String _dateTime(BuildContext context, DateTime value) {
  final material = MaterialLocalizations.of(context);
  final date = material.formatCompactDate(value);
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '$date $time';
}
