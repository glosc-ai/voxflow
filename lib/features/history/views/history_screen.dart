import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../models/history_record.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final playback = ref.watch(historyPlaybackProvider);
    ref.listen<String?>(
      historyPlaybackProvider.select((value) => value.errorMessage),
      (previous, next) {
        if (next != null && next != previous) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next)),
          );
        }
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: ref.read(historyProvider.notifier).load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: TextField(
                  key: const Key('historySearchField'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (query) =>
                      ref.read(historyProvider.notifier).load(query: query),
                  decoration: InputDecoration(
                    hintText: '搜索转录或合成文字',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: '清空搜索',
                      onPressed: () {
                        _searchController.clear();
                        ref.read(historyProvider.notifier).load(query: '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: history.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stackTrace) => _ErrorState(
                    message:
                        error is AppException ? error.message : '无法加载历史记录。',
                    onRetry: ref.read(historyProvider.notifier).load,
                  ),
                  data: (records) {
                    if (records.isEmpty) {
                      return _EmptyState(
                        isSearch: _searchController.text.trim().isNotEmpty,
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                      itemCount: records.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return _HistoryCard(
                          record: record,
                          isPlaying: playback.recordId == record.id &&
                              playback.isPlaying,
                          onPlay: () => ref
                              .read(historyPlaybackProvider.notifier)
                              .toggle(record),
                          onCopy: () => _copy(record.text),
                          onDelete: () => _delete(record),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文字已复制。')),
      );
    }
  }

  Future<void> _delete(HistoryRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除历史记录？'),
        content: const Text('将同时清理声流管理目录中的关联音频，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warning ?? '历史记录已删除。')),
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Icon(
                record.type == HistoryType.stt
                    ? Icons.graphic_eq
                    : Icons.record_voice_over,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        record.type.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      Text(
                        _dateTime(record.createdAt.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    record.text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: onPlay,
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(isPlaying ? '暂停' : '播放'),
                      ),
                      TextButton.icon(
                        onPressed: onCopy,
                        icon: const Icon(Icons.copy),
                        label: const Text('复制'),
                      ),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isSearch});

  final bool isSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_toggle_off, size: 64),
          const SizedBox(height: 16),
          Text(isSearch ? '未找到匹配的历史记录' : '暂无历史记录'),
        ],
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

String _dateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
