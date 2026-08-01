import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_status_banner.dart';
import '../models/history_record.dart';
import '../providers/history_provider.dart';

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
        child: Scaffold(
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                                onRetry:
                                    ref.read(historyProvider.notifier).load,
                                query: _activeQuery,
                                playback: playback,
                                onClearSearch: _clearSearch,
                                onPlay: (record) => ref
                                    .read(historyPlaybackProvider.notifier)
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
  const _EmptyState({required this.query, required this.onClearSearch});

  final String query;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isSearch = query.isNotEmpty;

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
                            isSearch
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
