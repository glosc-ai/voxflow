import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logging/diagnostic_log_exporter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_section.dart';
import '../../../widgets/app_status_banner.dart';
import '../models/settings_state.dart';
import '../providers/settings_provider.dart';
import '../widgets/masked_text_editing_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.pageFocusNode});

  final FocusNode? pageFocusNode;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final MaskedTextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final FocusNode _apiKeyFocusNode;
  String? _sttModel;
  String? _ttsModel;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _apiKeyController = MaskedTextEditingController(text: settings.apiKey);
    _baseUrlController = TextEditingController(text: settings.baseUrl);
    _apiKeyFocusNode = FocusNode(debugLabel: 'API Key');
    _apiKeyFocusNode.addListener(_handleApiKeyFocusChange);
    _sttModel = settings.sttModel;
    _ttsModel = settings.ttsModel;
  }

  @override
  void dispose() {
    _apiKeyFocusNode.removeListener(_handleApiKeyFocusChange);
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final isFetchingModels =
        settings.activeOperation == SettingsOperation.fetchingModels;
    final isTestingConnection =
        settings.activeOperation == SettingsOperation.testingConnection;
    final isSaving = settings.activeOperation == SettingsOperation.saving;
    final sttModels = _modelOptions(
      settings.availableSttModels,
      current: _sttModel,
      fallback: AppConstants.defaultSttModel,
      fetchedFromService: settings.hasFetchedModels,
    );
    final ttsModels = _modelOptions(
      settings.availableTtsModels,
      current: _ttsModel,
      fallback: AppConstants.defaultTtsModel,
      fetchedFromService: settings.hasFetchedModels,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!settings.isBusy) {
            _submit(testConnection: false);
          }
        },
      },
      child: Focus(
        key: const Key('settingsPageFocus'),
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
              l10n.text(zh: '设置', en: 'Settings'),
              maxLines: 1,
            ),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                padding: AppLayout.pagePadding(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.text(
                            zh: '连接、模型与本机诊断',
                            en: 'Connection, models, and local diagnostics',
                          ),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppStatusBanner(
                          kind: AppStatusKind.warning,
                          title: l10n.text(
                            zh: '使用受限密钥',
                            en: 'Use a restricted key',
                          ),
                          message: l10n.text(
                            zh: 'API Key 以明文保存在本机。请使用可撤销、低额度的专用密钥；应用日志不会记录密钥。',
                            en: 'The API key is stored as plain text on this device. Use a revocable, low-limit key. App logs never record the key.',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppSection(
                          title: l10n.text(
                            zh: 'API 连接',
                            en: 'API connection',
                          ),
                          description: l10n.text(
                            zh: '配置 OpenAI 兼容服务，并在保存前验证连接。',
                            en: 'Configure an OpenAI-compatible service and verify it before saving.',
                          ),
                          leading: const Icon(Icons.link),
                          trailing: OutlinedButton.icon(
                            key: const Key('fetchModelsButton'),
                            onPressed: settings.isBusy ? null : _fetchModels,
                            icon: isFetchingModels
                                ? SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary,
                                    ),
                                  )
                                : const Icon(Icons.download_outlined),
                            label: Text(
                              isFetchingModels
                                  ? l10n.text(
                                      zh: '正在获取…',
                                      en: 'Fetching…',
                                    )
                                  : l10n.text(
                                      zh: '获取模型',
                                      en: 'Fetch models',
                                    ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                key: const Key('baseUrlField'),
                                controller: _baseUrlController,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.next,
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
                                    return l10n.appError(error);
                                  }
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Semantics(
                                key: const Key('apiKeySemantics'),
                                textField: true,
                                readOnly: false,
                                focusable: true,
                                focused: _apiKeyFocusNode.hasFocus,
                                obscured: _obscureApiKey,
                                label: _obscureApiKey
                                    ? l10n.text(
                                        zh: 'API Key，内容已隐藏',
                                        en: 'API key, content hidden',
                                      )
                                    : l10n.text(
                                        zh: 'API Key，内容可见',
                                        en: 'API key, content visible',
                                      ),
                                value: _obscureApiKey
                                    ? (_apiKeyController.text.isEmpty
                                        ? l10n.text(
                                            zh: '未填写',
                                            en: 'Not entered',
                                          )
                                        : l10n.text(
                                            zh: '已填写',
                                            en: 'Entered',
                                          ))
                                    : _apiKeyController.text,
                                onTap: _apiKeyFocusNode.requestFocus,
                                customSemanticsActions: {
                                  CustomSemanticsAction(
                                    label: _obscureApiKey
                                        ? l10n.text(
                                            zh: '显示密钥',
                                            en: 'Show API key',
                                          )
                                        : l10n.text(
                                            zh: '隐藏密钥',
                                            en: 'Hide API key',
                                          ),
                                  ): _toggleApiKeyVisibility,
                                },
                                onSetText: (value) {
                                  setState(() {
                                    _apiKeyController.value = TextEditingValue(
                                      text: value,
                                      selection: TextSelection.collapsed(
                                        offset: value.length,
                                      ),
                                    );
                                  });
                                },
                                child: ExcludeSemantics(
                                  child: TextFormField(
                                    key: const Key('apiKeyField'),
                                    controller: _apiKeyController,
                                    focusNode: _apiKeyFocusNode,
                                    keyboardType: TextInputType.visiblePassword,
                                    textInputAction: TextInputAction.next,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    enableInteractiveSelection: !_obscureApiKey,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      labelText: 'API Key',
                                      prefixIcon: const Icon(Icons.key),
                                      suffixIcon: IconButton(
                                        tooltip: _obscureApiKey
                                            ? l10n.text(
                                                zh: '显示密钥',
                                                en: 'Show API key',
                                              )
                                            : l10n.text(
                                                zh: '隐藏密钥',
                                                en: 'Hide API key',
                                              ),
                                        onPressed: _toggleApiKeyVisibility,
                                        icon: Icon(
                                          _obscureApiKey
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                        ),
                                      ),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? l10n.text(
                                                zh: '请填写 API Key',
                                                en: 'Enter an API key',
                                              )
                                            : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: settings.isBusy
                                      ? null
                                      : () => _submit(testConnection: true),
                                  icon: isTestingConnection
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.network_check),
                                  label: Text(
                                    isTestingConnection
                                        ? l10n.text(
                                            zh: '正在检查…',
                                            en: 'Checking…',
                                          )
                                        : l10n.text(
                                            zh: '测试 API 连通性',
                                            en: 'Test API connection',
                                          ),
                                  ),
                                ),
                              ),
                              if (settings.lastConnectionSucceeded != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                AppStatusBanner(
                                  kind: settings.lastConnectionSucceeded!
                                      ? AppStatusKind.success
                                      : AppStatusKind.error,
                                  title: settings.lastConnectionSucceeded!
                                      ? l10n.text(
                                          zh: '连接可用',
                                          en: 'Connection available',
                                        )
                                      : l10n.text(
                                          zh: '连接失败',
                                          en: 'Connection failed',
                                        ),
                                  message: settings.messageFor(
                                        Localizations.localeOf(context),
                                      ) ??
                                      '',
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppSection(
                          title: l10n.text(zh: '模型', en: 'Models'),
                          description: l10n.text(
                            zh: '先获取服务支持的模型，再选择用于转录和语音合成的默认模型。',
                            en: 'Fetch supported models, then choose defaults for transcription and speech synthesis.',
                          ),
                          leading: const Icon(Icons.tune),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                key: const Key('sttModelField'),
                                initialValue: sttModels.contains(_sttModel)
                                    ? _sttModel
                                    : null,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: l10n.text(
                                    zh: '语音转文字模型',
                                    en: 'Speech-to-text model',
                                  ),
                                ),
                                disabledHint: settings.hasFetchedModels &&
                                        sttModels.isEmpty
                                    ? Text(l10n.text(
                                        zh: '服务未提供兼容的语音转文字模型',
                                        en: 'No compatible speech-to-text model',
                                      ))
                                    : null,
                                items: sttModels
                                    .map(
                                      (model) => DropdownMenuItem(
                                        value: model,
                                        child: Text(
                                          model,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: settings.isBusy || sttModels.isEmpty
                                    ? null
                                    : (value) => _sttModel = value,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              DropdownButtonFormField<String>(
                                key: const Key('ttsModelField'),
                                initialValue: ttsModels.contains(_ttsModel)
                                    ? _ttsModel
                                    : null,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: l10n.text(
                                    zh: '文字转语音模型',
                                    en: 'Text-to-speech model',
                                  ),
                                ),
                                disabledHint: settings.hasFetchedModels &&
                                        ttsModels.isEmpty
                                    ? Text(l10n.text(
                                        zh: '服务未提供兼容的文字转语音模型',
                                        en: 'No compatible text-to-speech model',
                                      ))
                                    : null,
                                items: ttsModels
                                    .map(
                                      (model) => DropdownMenuItem(
                                        value: model,
                                        child: Text(
                                          model,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: settings.isBusy || ttsModels.isEmpty
                                    ? null
                                    : (value) => _ttsModel = value,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppSection(
                          title: l10n.text(
                            zh: '外观与语言',
                            en: 'Appearance and language',
                          ),
                          description: l10n.text(
                            zh: '主题和语言会立即切换并保存在本机。',
                            en: 'Theme and language changes apply immediately and are stored on this device.',
                          ),
                          leading: const Icon(Icons.contrast),
                          child: Column(
                            children: [
                              DropdownButtonFormField<AppThemePreference>(
                                key: ValueKey(
                                  'themeMode:${settings.themePreference.name}',
                                ),
                                initialValue: settings.themePreference,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: l10n.text(
                                    zh: '主题模式',
                                    en: 'Theme',
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.brightness_6_outlined,
                                  ),
                                ),
                                items: [
                                  for (final preference
                                      in AppThemePreference.values)
                                    DropdownMenuItem(
                                      value: preference,
                                      child: Text(
                                        _themePreferenceLabel(
                                          l10n,
                                          preference,
                                        ),
                                      ),
                                    ),
                                ],
                                onChanged: (preference) {
                                  if (preference != null) {
                                    _setThemePreference(preference);
                                  }
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              DropdownButtonFormField<AppLocalePreference>(
                                key: ValueKey(
                                  'localePreference:'
                                  '${settings.localePreference.name}',
                                ),
                                initialValue: settings.localePreference,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: l10n.text(
                                    zh: '语言',
                                    en: 'Language',
                                  ),
                                  prefixIcon: const Icon(Icons.language),
                                ),
                                items: [
                                  for (final preference
                                      in AppLocalePreference.values)
                                    DropdownMenuItem(
                                      value: preference,
                                      child: Text(
                                        _localePreferenceLabel(
                                          l10n,
                                          preference,
                                        ),
                                      ),
                                    ),
                                ],
                                onChanged: (preference) {
                                  if (preference != null) {
                                    _setLocalePreference(preference);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppSection(
                          title: l10n.text(
                            zh: '诊断日志',
                            en: 'Diagnostic logs',
                          ),
                          description: l10n.text(
                            zh: '记录接口路径、状态码、模型和脱敏后的错误原因；不会记录 API Key、认证头、音频或输入文本。',
                            en: 'Records endpoint paths, status codes, models, and redacted error reasons. API keys, authorization headers, audio, and input text are never logged.',
                          ),
                          leading: const Icon(Icons.monitor_heart_outlined),
                          child: Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            alignment: WrapAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                key: const Key('viewLogsButton'),
                                onPressed: _showLogs,
                                icon: const Icon(Icons.article_outlined),
                                label: Text(l10n.text(
                                  zh: '查看日志',
                                  en: 'View logs',
                                )),
                              ),
                              OutlinedButton.icon(
                                key: const Key('exportLogsButton'),
                                onPressed: _exportLogs,
                                icon: const Icon(Icons.save_alt),
                                label: Text(l10n.text(
                                  zh: '导出日志',
                                  en: 'Export logs',
                                )),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final expandAction = Theme.of(context).platform ==
                                    TargetPlatform.android ||
                                MediaQuery.textScalerOf(context).scale(1) >=
                                    1.6 ||
                                constraints.maxWidth < 420;
                            return Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: expandAction ? double.infinity : null,
                                child: FilledButton.icon(
                                  key: const Key('settingsSaveButton'),
                                  onPressed: settings.isBusy
                                      ? null
                                      : () => _submit(testConnection: false),
                                  icon: SizedBox.square(
                                    key: const Key('settingsSaveIconSlot'),
                                    dimension: 24,
                                    child: Center(
                                      child: isSaving
                                          ? SizedBox.square(
                                              dimension: 16,
                                              child: CircularProgressIndicator(
                                                key: const Key(
                                                  'settingsSavingIndicator',
                                                ),
                                                strokeWidth: 2,
                                                color: colors.onSurface,
                                              ),
                                            )
                                          : const Icon(Icons.save_outlined),
                                    ),
                                  ),
                                  label: IndexedStack(
                                    key: const Key('settingsSaveLabelStack'),
                                    index: isSaving ? 1 : 0,
                                    alignment: Alignment.center,
                                    children: [
                                      Text(l10n.text(
                                        zh: '保存设置',
                                        en: 'Save settings',
                                      )),
                                      Text(l10n.text(
                                        zh: '正在保存…',
                                        en: 'Saving…',
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
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

  void _handleApiKeyFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleApiKeyVisibility() {
    setState(() {
      _obscureApiKey = !_obscureApiKey;
      _apiKeyController.masked = _obscureApiKey;
    });
  }

  Future<void> _showLogs() async {
    try {
      final contents = await ref.read(appLoggerProvider).readAll();
      if (!mounted) {
        return;
      }
      final l10n = context.l10n;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.text(
            zh: 'VoxFlow 诊断日志',
            en: 'VoxFlow diagnostic logs',
          )),
          content: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 760,
              maxHeight: 420,
              minHeight: 240,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.semanticColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SelectableText(
                  contents.trim().isEmpty
                      ? l10n.text(
                          zh: '暂无诊断日志。',
                          en: 'No diagnostic logs yet.',
                        )
                      : contents,
                  key: const Key('diagnosticLogContents'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.text(zh: '关闭', en: 'Close')),
            ),
          ],
        ),
      );
    } on AppException catch (error) {
      _showException(error);
    }
  }

  Future<void> _exportLogs() async {
    try {
      final exported = await DiagnosticLogExporter(
        ref.read(appLoggerProvider),
      ).export(
        dialogTitle: context.l10n.text(
          zh: '导出 VoxFlow 诊断日志',
          en: 'Export VoxFlow diagnostic logs',
        ),
      );
      if (exported && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.text(
              zh: '诊断日志已导出。',
              en: 'Diagnostic logs exported.',
            )),
          ),
        );
      }
    } on AppException catch (error) {
      _showException(error);
    }
  }

  Future<void> _setThemePreference(
    AppThemePreference preference,
  ) async {
    try {
      await ref.read(settingsProvider.notifier).setThemePreference(preference);
    } on AppException catch (error) {
      _showException(error);
    }
  }

  Future<void> _setLocalePreference(
    AppLocalePreference preference,
  ) async {
    try {
      await ref.read(settingsProvider.notifier).setLocalePreference(preference);
    } on AppException catch (error) {
      _showException(error);
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

  void _showException(AppException error) {
    if (!mounted) {
      return;
    }
    _showError(context.l10n.appError(error));
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
        setState(() {
          _sttModel = _selectionAfterFetch(catalog.stt, _sttModel);
          _ttsModel = _selectionAfterFetch(catalog.tts, _ttsModel);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.text(
                zh: '已获取 ${catalog.stt.length} 个语音转文字模型、'
                    '${catalog.tts.length} 个文字转语音模型。',
                en: 'Fetched ${catalog.stt.length} speech-to-text '
                    '${catalog.stt.length == 1 ? 'model' : 'models'} and '
                    '${catalog.tts.length} text-to-speech '
                    '${catalog.tts.length == 1 ? 'model' : 'models'}.',
              ),
            ),
          ),
        );
      }
    } on AppException catch (error) {
      _showException(error);
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
              sttModel: _sttModel ?? '',
              ttsModel: _ttsModel ?? '',
            )
          : await notifier.save(
              apiKey: _apiKeyController.text,
              baseUrl: _baseUrlController.text,
              sttModel: _sttModel ?? '',
              ttsModel: _ttsModel ?? '',
            );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.resolve(Localizations.localeOf(context)),
            ),
          ),
        );
      }
    } on AppException catch (error) {
      _showException(error);
    }
  }
}

List<String> _modelOptions(
  Iterable<String> fetched, {
  required String? current,
  required String fallback,
  required bool fetchedFromService,
}) {
  final fetchedModels = fetched
      .map((model) => model.trim())
      .where((model) => model.isNotEmpty)
      .toSet();
  if (fetchedFromService) {
    return fetchedModels.toList();
  }
  final models = <String>{fallback, current?.trim() ?? ''}
    ..removeWhere((model) => model.isEmpty);
  return models.toList();
}

String? _selectionAfterFetch(Iterable<String> models, String? current) {
  final available = models.toList(growable: false);
  if (available.isEmpty) {
    return null;
  }
  final normalizedCurrent = current?.trim();
  return available.contains(normalizedCurrent)
      ? normalizedCurrent
      : available.first;
}

String _themePreferenceLabel(
  AppLocalizations l10n,
  AppThemePreference preference,
) {
  return switch (preference) {
    AppThemePreference.system => l10n.text(
        zh: '跟随系统',
        en: 'Follow system',
      ),
    AppThemePreference.light => l10n.text(zh: '浅色', en: 'Light'),
    AppThemePreference.dark => l10n.text(zh: '深色', en: 'Dark'),
  };
}

String _localePreferenceLabel(
  AppLocalizations l10n,
  AppLocalePreference preference,
) {
  return switch (preference) {
    AppLocalePreference.system => l10n.text(
        zh: '跟随系统',
        en: 'Follow system',
      ),
    AppLocalePreference.zhHans => l10n.text(
        zh: '简体中文',
        en: 'Simplified Chinese',
      ),
    AppLocalePreference.english => l10n.text(
        zh: 'English',
        en: 'English',
      ),
  };
}
