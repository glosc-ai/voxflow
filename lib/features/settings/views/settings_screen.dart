import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../models/settings_state.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late String _sttModel;
  late String _ttsModel;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
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
                        key: const Key('apiKeyField'),
                        controller: _apiKeyController,
                        obscureText: _obscureApiKey,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          prefixIcon: const Icon(Icons.key),
                          suffixIcon: IconButton(
                            tooltip: _obscureApiKey ? '显示密钥' : '隐藏密钥',
                            onPressed: () => setState(
                              () => _obscureApiKey = !_obscureApiKey,
                            ),
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
                      const SizedBox(height: 16),
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
                      DropdownButtonFormField<String>(
                        initialValue: _sttModel,
                        decoration: const InputDecoration(
                          labelText: '语音转文字模型',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: AppConstants.defaultSttModel,
                            child: Text(AppConstants.defaultSttModel),
                          ),
                        ],
                        onChanged: settings.isBusy
                            ? null
                            : (value) => _sttModel = value ?? _sttModel,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _ttsModel,
                        decoration: const InputDecoration(
                          labelText: '文字转语音模型',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: AppConstants.defaultTtsModel,
                            child: Text(AppConstants.defaultTtsModel),
                          ),
                        ],
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
