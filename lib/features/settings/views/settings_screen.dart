import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logging/diagnostic_log_exporter.dart';
import '../models/settings_state.dart';
import '../providers/settings_provider.dart';
import '../widgets/masked_text_editing_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final MaskedTextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late String _sttModel;
  late String _ttsModel;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _apiKeyController = MaskedTextEditingController(text: settings.apiKey);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _sttModel = settings.sttModel;
    _ttsModel = settings.ttsModel;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final sttModels = _modelOptions(
      settings.availableSttModels,
      current: _sttModel,
      fallback: AppConstants.defaultSttModel,
    );
    final ttsModels = _modelOptions(
      settings.availableTtsModels,
      current: _ttsModel,
      fallback: AppConstants.defaultTtsModel,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'OpenAI 兼容 API',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '密钥保存在本机设置中，不会写入应用日志。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const Key('baseUrlField'),
                        controller: _baseUrlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'API Root',
                          hintText: AppConstants.defaultBaseUrl,
                          prefixIcon: Icon(Icons.link),
                        ),
                        validator: (value) {
                          try {
                            SettingsState.normalizeBaseUrl(value ?? '');
                            return null;
                          } on AppException catch (error) {
                            return error.message;
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      ExcludeSemantics(
                        child: TextFormField(
                          key: const Key('apiKeyField'),
                          controller: _apiKeyController,
                          keyboardType: TextInputType.visiblePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          enableInteractiveSelection: !_obscureApiKey,
                          decoration: InputDecoration(
                            labelText: 'API Key',
                            prefixIcon: const Icon(Icons.key),
                            suffixIcon: IconButton(
                              tooltip: _obscureApiKey ? '显示密钥' : '隐藏密钥',
                              onPressed: () => setState(() {
                                _obscureApiKey = !_obscureApiKey;
                                _apiKeyController.masked = _obscureApiKey;
                              }),
                              icon: Icon(
                                _obscureApiKey
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? '请填写 API Key'
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: const Key('sttModelField'),
                        initialValue: _sttModel,
                        decoration: const InputDecoration(
                          labelText: '语音转文字模型',
                        ),
                        items: sttModels
                            .map(
                              (model) => DropdownMenuItem(
                                value: model,
                                child: Text(model),
                              ),
                            )
                            .toList(),
                        onChanged: settings.isBusy
                            ? null
                            : (value) => _sttModel = value ?? _sttModel,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: const Key('ttsModelField'),
                        initialValue: _ttsModel,
                        decoration: const InputDecoration(
                          labelText: '文字转语音模型',
                        ),
                        items: ttsModels
                            .map(
                              (model) => DropdownMenuItem(
                                value: model,
                                child: Text(model),
                              ),
                            )
                            .toList(),
                        onChanged: settings.isBusy
                            ? null
                            : (value) => _ttsModel = value ?? _ttsModel,
                      ),
                      if (settings.lastConnectionSucceeded != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              settings.lastConnectionSucceeded!
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: settings.lastConnectionSucceeded!
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(settings.message ?? '')),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('fetchModelsButton'),
                            onPressed: settings.isBusy ? null : _fetchModels,
                            icon: const Icon(Icons.download),
                            label: const Text('获取模型'),
                          ),
                          OutlinedButton.icon(
                            onPressed: settings.isBusy
                                ? null
                                : () => _submit(testConnection: true),
                            icon: settings.isBusy
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.network_check),
                            label: const Text('测试 API 连通性'),
                          ),
                          FilledButton.icon(
                            onPressed: settings.isBusy
                                ? null
                                : () => _submit(testConnection: false),
                            icon: const Icon(Icons.save),
                            label: const Text('保存设置'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 20),
                      Text(
                        '诊断日志',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '记录接口路径、状态码、模型和脱敏后的服务端错误原因；'
                        '不会记录 API Key、认证头、音频或输入文本。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('viewLogsButton'),
                            onPressed: _showLogs,
                            icon: const Icon(Icons.article_outlined),
                            label: const Text('查看日志'),
                          ),
                          OutlinedButton.icon(
                            key: const Key('exportLogsButton'),
                            onPressed: _exportLogs,
                            icon: const Icon(Icons.save_alt),
                            label: const Text('导出日志'),
                          ),
                        ],
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

  Future<void> _showLogs() async {
    try {
      final contents = await ref.read(appLoggerProvider).readAll();
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('VoxFlow 诊断日志'),
          content: SizedBox(
            width: 760,
            height: 420,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  contents.trim().isEmpty ? '暂无诊断日志。' : contents,
                  key: const Key('diagnosticLogContents'),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } on AppException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _exportLogs() async {
    try {
      final exported = await DiagnosticLogExporter(
        ref.read(appLoggerProvider),
      ).export();
      if (exported && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('诊断日志已导出。')),
        );
      }
    } on AppException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _fetchModels() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    try {
      final catalog = await ref.read(settingsProvider.notifier).fetchModels(
            apiKey: _apiKeyController.text,
            baseUrl: _baseUrlController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已获取 ${catalog.stt.length} 个语音转文字模型、'
              '${catalog.tts.length} 个文字转语音模型。',
            ),
          ),
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

  Future<void> _submit({required bool testConnection}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    try {
      final notifier = ref.read(settingsProvider.notifier);
      final message = testConnection
          ? await notifier.testConnection(
              apiKey: _apiKeyController.text,
              baseUrl: _baseUrlController.text,
              sttModel: _sttModel,
              ttsModel: _ttsModel,
            )
          : await notifier.save(
              apiKey: _apiKeyController.text,
              baseUrl: _baseUrlController.text,
              sttModel: _sttModel,
              ttsModel: _ttsModel,
            );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
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

List<String> _modelOptions(
  Iterable<String> fetched, {
  required String current,
  required String fallback,
}) {
  final models = <String>{fallback, current.trim(), ...fetched}
    ..removeWhere((model) => model.isEmpty);
  return models.toList();
}
