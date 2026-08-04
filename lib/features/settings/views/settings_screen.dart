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
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_section.dart';
import '../../../widgets/app_status_banner.dart';
import '../../../widgets/mobile_design.dart';
import '../models/settings_state.dart';
import '../providers/settings_provider.dart';
import '../widgets/masked_text_editing_controller.dart';
import '../widgets/speech_model_selector.dart';

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
  bool _sttModelDirty = false;
  bool _ttsModelDirty = false;
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
    ref.listen<String>(
      settingsProvider.select((value) => value.sttModel),
      (previous, next) {
        if (!_sttModelDirty && _sttModel != next && mounted) {
          setState(() => _sttModel = next);
        }
      },
    );
    ref.listen<String>(
      settingsProvider.select((value) => value.ttsModel),
      (previous, next) {
        if (!_ttsModelDirty && _ttsModel != next && mounted) {
          setState(() => _ttsModel = next);
        }
      },
    );
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final isFetchingModels =
        settings.activeOperation == SettingsOperation.fetchingModels;
    final isTestingConnection =
        settings.activeOperation == SettingsOperation.testingConnection;
    final isSaving = settings.activeOperation == SettingsOperation.saving;
    final useDesktopLayout =
        Theme.of(context).platform == TargetPlatform.windows &&
            MediaQuery.sizeOf(context).width >= 760;
    final useMobileLayout =
        Theme.of(context).platform == TargetPlatform.android;
    final useLiveModelSelectors = useDesktopLayout || useMobileLayout;
    if (useLiveModelSelectors) {
      _sttModel = settings.sttModel;
      _ttsModel = settings.ttsModel;
      _sttModelDirty = false;
      _ttsModelDirty = false;
    }
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
        child: useDesktopLayout
            ? _buildDesktopPage(
                settings: settings,
                isFetchingModels: isFetchingModels,
                isTestingConnection: isTestingConnection,
                isSaving: isSaving,
              )
            : useMobileLayout
                ? _buildMobilePage(
                    settings: settings,
                    isFetchingModels: isFetchingModels,
                    isTestingConnection: isTestingConnection,
                    isSaving: isSaving,
                  )
                : Scaffold(
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
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
                                      onPressed:
                                          settings.isBusy ? null : _fetchModels,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        TextFormField(
                                          key: const Key('baseUrlField'),
                                          controller: _baseUrlController,
                                          keyboardType: TextInputType.url,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            labelText: 'API Root',
                                            hintText:
                                                AppConstants.defaultBaseUrl,
                                            prefixIcon: Icon(Icons.link),
                                          ),
                                          validator: (value) {
                                            try {
                                              SettingsState.normalizeBaseUrl(
                                                  value ?? '');
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
                                              _apiKeyController.value =
                                                  TextEditingValue(
                                                text: value,
                                                selection:
                                                    TextSelection.collapsed(
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
                                              keyboardType:
                                                  TextInputType.visiblePassword,
                                              textInputAction:
                                                  TextInputAction.next,
                                              enableSuggestions: false,
                                              autocorrect: false,
                                              enableInteractiveSelection:
                                                  !_obscureApiKey,
                                              onChanged: (_) => setState(() {}),
                                              decoration: InputDecoration(
                                                labelText: 'API Key',
                                                prefixIcon:
                                                    const Icon(Icons.key),
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
                                                  onPressed:
                                                      _toggleApiKeyVisibility,
                                                  icon: Icon(
                                                    _obscureApiKey
                                                        ? Icons.visibility
                                                        : Icons.visibility_off,
                                                  ),
                                                ),
                                              ),
                                              validator: (value) =>
                                                  value == null ||
                                                          value.trim().isEmpty
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
                                                : () => _submit(
                                                    testConnection: true),
                                            icon: isTestingConnection
                                                ? const SizedBox.square(
                                                    dimension: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.network_check),
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
                                        if (settings.lastConnectionSucceeded !=
                                            null) ...[
                                          const SizedBox(height: AppSpacing.md),
                                          AppStatusBanner(
                                            kind: settings
                                                    .lastConnectionSucceeded!
                                                ? AppStatusKind.success
                                                : AppStatusKind.error,
                                            title: settings
                                                    .lastConnectionSucceeded!
                                                ? l10n.text(
                                                    zh: '连接可用',
                                                    en: 'Connection available',
                                                  )
                                                : l10n.text(
                                                    zh: '连接失败',
                                                    en: 'Connection failed',
                                                  ),
                                            message: settings.messageFor(
                                                  Localizations.localeOf(
                                                      context),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        DropdownButtonFormField<String>(
                                          key: const Key('sttModelField'),
                                          initialValue:
                                              sttModels.contains(_sttModel)
                                                  ? _sttModel
                                                  : null,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: l10n.text(
                                              zh: '语音转文字模型',
                                              en: 'Speech-to-text model',
                                            ),
                                          ),
                                          disabledHint:
                                              settings.hasFetchedModels &&
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
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: settings.isBusy ||
                                                  sttModels.isEmpty
                                              ? null
                                              : (value) {
                                                  _sttModel = value;
                                                  _sttModelDirty = true;
                                                },
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        DropdownButtonFormField<String>(
                                          key: const Key('ttsModelField'),
                                          initialValue:
                                              ttsModels.contains(_ttsModel)
                                                  ? _ttsModel
                                                  : null,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: l10n.text(
                                              zh: '文字转语音模型',
                                              en: 'Text-to-speech model',
                                            ),
                                          ),
                                          disabledHint:
                                              settings.hasFetchedModels &&
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
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: settings.isBusy ||
                                                  ttsModels.isEmpty
                                              ? null
                                              : (value) {
                                                  _ttsModel = value;
                                                  _ttsModelDirty = true;
                                                },
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
                                        DropdownButtonFormField<
                                            AppThemePreference>(
                                          key: ValueKey(
                                            'themeMode:${settings.themePreference.name}',
                                          ),
                                          initialValue:
                                              settings.themePreference,
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
                                        DropdownButtonFormField<
                                            AppLocalePreference>(
                                          key: ValueKey(
                                            'localePreference:'
                                            '${settings.localePreference.name}',
                                          ),
                                          initialValue:
                                              settings.localePreference,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: l10n.text(
                                              zh: '语言',
                                              en: 'Language',
                                            ),
                                            prefixIcon:
                                                const Icon(Icons.language),
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
                                    leading: const Icon(
                                        Icons.monitor_heart_outlined),
                                    child: Wrap(
                                      spacing: AppSpacing.sm,
                                      runSpacing: AppSpacing.sm,
                                      alignment: WrapAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          key: const Key('viewLogsButton'),
                                          onPressed: _showLogs,
                                          icon: const Icon(
                                              Icons.article_outlined),
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
                                      final expandAction =
                                          Theme.of(context).platform ==
                                                  TargetPlatform.android ||
                                              MediaQuery.textScalerOf(context)
                                                      .scale(1) >=
                                                  1.6 ||
                                              constraints.maxWidth < 420;
                                      return Align(
                                        alignment: Alignment.centerRight,
                                        child: SizedBox(
                                          width: expandAction
                                              ? double.infinity
                                              : null,
                                          child: FilledButton.icon(
                                            key:
                                                const Key('settingsSaveButton'),
                                            onPressed: settings.isBusy
                                                ? null
                                                : () => _submit(
                                                    testConnection: false),
                                            icon: SizedBox.square(
                                              key: const Key(
                                                  'settingsSaveIconSlot'),
                                              dimension: 24,
                                              child: Center(
                                                child: isSaving
                                                    ? SizedBox.square(
                                                        dimension: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                          key: const Key(
                                                            'settingsSavingIndicator',
                                                          ),
                                                          strokeWidth: 2,
                                                          color:
                                                              colors.onSurface,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.save_outlined),
                                              ),
                                            ),
                                            label: IndexedStack(
                                              key: const Key(
                                                  'settingsSaveLabelStack'),
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

  Widget _buildMobilePage({
    required SettingsState settings,
    required bool isFetchingModels,
    required bool isTestingConnection,
    required bool isSaving,
  }) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final isResetting = settings.activeOperation == SettingsOperation.resetting;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: FocusTraversalGroup(
          child: SingleChildScrollView(
            key: const Key('mobileSettingsScrollView'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: MobileLayout.pagePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MobileViewHeader(
                    eyebrow: l10n.text(
                      zh: 'Preferences · 本地偏好',
                      en: 'Preferences · Local settings',
                    ),
                    title: l10n.text(zh: '设置', en: 'Settings'),
                  ),
                  _MobileSettingsCard(
                    children: [
                      _MobileSettingsRow(
                        name: l10n.text(zh: '外观', en: 'Appearance'),
                        description: l10n.text(
                          zh: '浅色、深色或跟随系统；切换后即时生效。',
                          en: 'Use light, dark, or the system appearance. Changes apply immediately.',
                        ),
                        controlFullWidth: true,
                        control: _MobileSegmentedControl<AppThemePreference>(
                          key: ValueKey(
                            'themeMode:${settings.themePreference.name}',
                          ),
                          value: settings.themePreference,
                          options: [
                            _MobileSegmentOption(
                              key: const ValueKey('mobileThemeOption:light'),
                              value: AppThemePreference.light,
                              label: l10n.text(zh: '浅色', en: 'Light'),
                            ),
                            _MobileSegmentOption(
                              key: const ValueKey('mobileThemeOption:dark'),
                              value: AppThemePreference.dark,
                              label: l10n.text(zh: '深色', en: 'Dark'),
                            ),
                            _MobileSegmentOption(
                              key: const ValueKey('mobileThemeOption:system'),
                              value: AppThemePreference.system,
                              label: l10n.text(
                                zh: '跟随系统',
                                en: 'Follow system',
                              ),
                            ),
                          ],
                          onChanged: _setThemePreference,
                        ),
                      ),
                      _MobileSettingsRow(
                        name: l10n.text(zh: '语言', en: 'Language'),
                        description: l10n.text(
                          zh: '支持简体中文、英文和跟随系统。',
                          en: 'Use Simplified Chinese, English, or the system language.',
                        ),
                        controlFullWidth: true,
                        control: _MobileSegmentedControl<AppLocalePreference>(
                          key: ValueKey(
                            'localePreference:'
                            '${settings.localePreference.name}',
                          ),
                          value: settings.localePreference,
                          options: [
                            const _MobileSegmentOption(
                              key: ValueKey('mobileLocaleOption:zhHans'),
                              value: AppLocalePreference.zhHans,
                              label: '简体中文',
                            ),
                            const _MobileSegmentOption(
                              key: ValueKey('mobileLocaleOption:english'),
                              value: AppLocalePreference.english,
                              label: 'English',
                            ),
                            _MobileSegmentOption(
                              key: const ValueKey(
                                'mobileLocaleOption:system',
                              ),
                              value: AppLocalePreference.system,
                              label: l10n.text(
                                zh: '跟随系统',
                                en: 'Follow system',
                              ),
                            ),
                          ],
                          onChanged: _setLocalePreference,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MobileSettingsCard(
                    children: [
                      _MobileSettingsRow(
                        name: l10n.text(
                          zh: '语音转文字模型',
                          en: 'Speech-to-text model',
                        ),
                        description: l10n.text(
                          zh: '与转文字页面顶部选择实时同步。',
                          en: 'Synchronized with the speech-to-text workspace.',
                        ),
                        control: SpeechModelSelector(
                          key: const Key('sttModelField'),
                          kind: SpeechModelKind.stt,
                          enabled: !settings.isBusy,
                        ),
                      ),
                      _MobileSettingsRow(
                        name: l10n.text(
                          zh: '文字转语音模型',
                          en: 'Text-to-speech model',
                        ),
                        description: l10n.text(
                          zh: '与转语音页面顶部选择实时同步。',
                          en: 'Synchronized with the text-to-speech workspace.',
                        ),
                        control: SpeechModelSelector(
                          key: const Key('ttsModelField'),
                          kind: SpeechModelKind.tts,
                          enabled: !settings.isBusy,
                        ),
                      ),
                      _MobileSettingsRow(
                        name: l10n.text(
                          zh: '在线模型目录',
                          en: 'Online model catalog',
                        ),
                        description: l10n.text(
                          zh: '从当前 API 服务读取兼容模型；需先填写有效凭证。',
                          en: 'Load compatible models from the current API service after entering valid credentials.',
                        ),
                        controlFullWidth: true,
                        control: OutlinedButton.icon(
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MobileSettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
                        child: AppStatusBanner(
                          kind: AppStatusKind.warning,
                          title: l10n.text(
                            zh: '使用受限测试密钥',
                            en: 'Use a restricted test key',
                          ),
                          message: l10n.text(
                            zh: 'API Key 以明文保存在本机。请使用可撤销、低额度的专用密钥；日志不会记录密钥。',
                            en: 'The API key is stored as plain text on this device. Use a revocable, low-limit key. Logs never record it.',
                          ),
                        ),
                      ),
                      _MobileSettingsRow(
                        name: 'Base URL',
                        description: l10n.text(
                          zh: '转写与合成服务的 HTTPS 地址，仅保存在本机。',
                          en: 'The HTTPS endpoint for speech services, stored only on this device.',
                        ),
                        controlFullWidth: true,
                        control: TextFormField(
                          key: const Key('baseUrlField'),
                          controller: _baseUrlController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          style: AppTypography.numeric(
                            Theme.of(context).textTheme.bodyMedium,
                          ),
                          decoration: const InputDecoration(
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
                      ),
                      _MobileSettingsRow(
                        name: 'API Key',
                        description: l10n.text(
                          zh: '服务访问凭证默认隐藏，仅保存在本机。',
                          en: 'The service credential is hidden by default and stored only on this device.',
                        ),
                        controlFullWidth: true,
                        control: _buildMobileApiKeyField(l10n),
                      ),
                      _MobileSettingsRow(
                        name: l10n.text(
                          zh: '连接检查',
                          en: 'Connection check',
                        ),
                        description: l10n.text(
                          zh: '验证当前表单；成功后同时保存设置。',
                          en: 'Verify the current form. A successful check also saves it.',
                        ),
                        controlFullWidth: true,
                        control: OutlinedButton.icon(
                          key: const Key('testConnectionButton'),
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
                      if (settings.lastConnectionSucceeded != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
                          child: AppStatusBanner(
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
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MobileSettingsCard(
                    children: [
                      _MobileSettingsRow(
                        name: l10n.text(
                          zh: '诊断日志',
                          en: 'Diagnostic logs',
                        ),
                        description: l10n.text(
                          zh: '记录接口路径、状态码、模型和脱敏错误，不记录密钥、音频或输入正文。',
                          en: 'Records endpoint paths, status codes, models, and redacted errors, never keys, audio, or input content.',
                        ),
                        controlFullWidth: true,
                        control: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
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
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MobileSettingsCard(
                    children: [
                      _MobileSettingsIntro(
                        name: l10n.text(zh: '手势', en: 'Gestures'),
                        description: l10n.text(
                          zh: '大点击热区，适合单手操作，也支持外接键盘遍历。',
                          en: 'Large touch targets for one-handed use, with external keyboard traversal.',
                        ),
                      ),
                      _MobileGestureRow(
                        label: l10n.text(
                          zh: '开始 / 停止录音',
                          en: 'Start / stop recording',
                        ),
                        gesture: l10n.text(
                          zh: '点按录音面板',
                          en: 'Tap recorder',
                        ),
                      ),
                      _MobileGestureRow(
                        label: l10n.text(
                          zh: '展开记录操作栏',
                          en: 'Expand history actions',
                        ),
                        gesture: l10n.text(
                          zh: '点按历史卡片',
                          en: 'Tap history card',
                        ),
                      ),
                      _MobileGestureRow(
                        label: l10n.text(
                          zh: '浏览全部音色',
                          en: 'Browse all voices',
                        ),
                        gesture: l10n.text(
                          zh: '横向滑动',
                          en: 'Swipe horizontally',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MobileSettingsCard(
                    children: [
                      _MobileSettingsRow(
                        name: l10n.text(
                          zh: '本地偏好',
                          en: 'Local preferences',
                        ),
                        description: l10n.text(
                          zh: '重置密钥、接口、模型、主题和语言；保留历史、关联音频、日志与隐私确认。',
                          en: 'Reset credentials, models, appearance, and language while keeping history, audio, logs, and privacy acknowledgement.',
                        ),
                        controlFullWidth: true,
                        control: OutlinedButton.icon(
                          key: const Key('resetLocalPreferencesButton'),
                          onPressed: settings.isBusy
                              ? null
                              : _confirmResetLocalPreferences,
                          icon: isResetting
                              ? SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.error,
                                  ),
                                )
                              : const Icon(Icons.restart_alt),
                          label: Text(
                            isResetting
                                ? l10n.text(
                                    zh: '正在重置…',
                                    en: 'Resetting…',
                                  )
                                : l10n.text(
                                    zh: '重置本地偏好',
                                    en: 'Reset local preferences',
                                  ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
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
                                  key: const Key('settingsSavingIndicator'),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPage({
    required SettingsState settings,
    required bool isFetchingModels,
    required bool isTestingConnection,
    required bool isSaving,
  }) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final isResetting = settings.activeOperation == SettingsOperation.resetting;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: AppLayout.pagePadding(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.text(
                      zh: 'PREFERENCES · 本地偏好',
                      en: 'PREFERENCES · LOCAL SETTINGS',
                    ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.text(zh: '设置', en: 'Settings'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.6,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _DesktopSettingsCard(
                    children: [
                      _DesktopSettingsRow(
                        name: l10n.text(zh: '外观', en: 'Appearance'),
                        description: l10n.text(
                          zh: '浅色、深色或跟随系统，即时生效并保存在本机。',
                          en: 'Use light, dark, or the system appearance. Changes apply immediately and stay on this device.',
                        ),
                        control: _DesktopSegmentedControl<AppThemePreference>(
                          key: ValueKey(
                            'themeMode:${settings.themePreference.name}',
                          ),
                          value: settings.themePreference,
                          options: [
                            _DesktopSegmentOption(
                              value: AppThemePreference.light,
                              label: l10n.text(zh: '浅色', en: 'Light'),
                            ),
                            _DesktopSegmentOption(
                              value: AppThemePreference.dark,
                              label: l10n.text(zh: '深色', en: 'Dark'),
                            ),
                            _DesktopSegmentOption(
                              value: AppThemePreference.system,
                              label: l10n.text(
                                zh: '跟随系统',
                                en: 'Follow system',
                              ),
                            ),
                          ],
                          onChanged: _setThemePreference,
                        ),
                      ),
                      _DesktopSettingsRow(
                        name: l10n.text(zh: '语言', en: 'Language'),
                        description: l10n.text(
                          zh: '切换界面语言；跟随系统时优先使用中文或英文。',
                          en: 'Choose the interface language, or follow the supported system preference.',
                        ),
                        control: _DesktopSegmentedControl<AppLocalePreference>(
                          key: ValueKey(
                            'localePreference:'
                            '${settings.localePreference.name}',
                          ),
                          value: settings.localePreference,
                          options: [
                            const _DesktopSegmentOption(
                              value: AppLocalePreference.zhHans,
                              label: '简体中文',
                            ),
                            const _DesktopSegmentOption(
                              value: AppLocalePreference.english,
                              label: 'English',
                            ),
                            _DesktopSegmentOption(
                              value: AppLocalePreference.system,
                              label: l10n.text(
                                zh: '跟随系统',
                                en: 'Follow system',
                              ),
                            ),
                          ],
                          onChanged: _setLocalePreference,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DesktopSettingsCard(
                    children: [
                      _DesktopSettingsRow(
                        name: l10n.text(
                          zh: '语音转文字模型',
                          en: 'Speech-to-text model',
                        ),
                        description: l10n.text(
                          zh: '与语音转文字页面实时同步。',
                          en: 'Synchronized with the speech-to-text page.',
                        ),
                        control: SpeechModelSelector(
                          key: const Key('sttModelField'),
                          kind: SpeechModelKind.stt,
                          enabled: !settings.isBusy,
                        ),
                      ),
                      _DesktopSettingsRow(
                        name: l10n.text(
                          zh: '文字转语音模型',
                          en: 'Text-to-speech model',
                        ),
                        description: l10n.text(
                          zh: '与文字转语音页面实时同步。',
                          en: 'Synchronized with the text-to-speech page.',
                        ),
                        control: SpeechModelSelector(
                          key: const Key('ttsModelField'),
                          kind: SpeechModelKind.tts,
                          enabled: !settings.isBusy,
                        ),
                      ),
                      _DesktopSettingsRow(
                        name: l10n.text(
                          zh: '在线模型目录',
                          en: 'Online model catalog',
                        ),
                        description: l10n.text(
                          zh: '从当前 API 服务读取兼容的语音模型。',
                          en: 'Load compatible speech models from the configured API service.',
                        ),
                        control: OutlinedButton.icon(
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
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DesktopSettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: AppStatusBanner(
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
                      ),
                      _DesktopSettingsRow(
                        name: 'Base URL',
                        description: l10n.text(
                          zh: '转写与合成服务的 HTTPS 接口地址，仅保存在本机。',
                          en: 'The HTTPS endpoint for transcription and speech synthesis, stored only on this device.',
                        ),
                        control: SizedBox(
                          width: 360,
                          child: TextFormField(
                            key: const Key('baseUrlField'),
                            controller: _baseUrlController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontFamily: 'Cascadia Code',
                              fontFamilyFallback: [
                                'JetBrains Mono',
                                'Consolas',
                              ],
                            ),
                            decoration: const InputDecoration(
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
                        ),
                      ),
                      _DesktopSettingsRow(
                        name: 'API Key',
                        description: l10n.text(
                          zh: '服务访问凭证默认隐藏，仅保存在本机。',
                          en: 'The service credential is hidden by default and stored only on this device.',
                        ),
                        control: _buildDesktopApiKeyField(l10n),
                      ),
                      _DesktopSettingsRow(
                        name: l10n.text(
                          zh: '连接检查',
                          en: 'Connection check',
                        ),
                        description: l10n.text(
                          zh: '使用当前表单验证服务连通性；成功后同时保存设置。',
                          en: 'Verify the current form against the service. A successful check also saves the settings.',
                        ),
                        control: OutlinedButton.icon(
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
                      if (settings.lastConnectionSucceeded != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          child: AppStatusBanner(
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
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DesktopSettingsCard(
                    children: [
                      _DesktopSettingsIntro(
                        name: l10n.text(zh: '快捷键', en: 'Keyboard shortcuts'),
                        description: l10n.text(
                          zh: '页面级快捷键全局生效；输入框或菜单聚焦时自动让位。',
                          en: 'Page shortcuts work across the app and yield while an input or menu has focus.',
                        ),
                      ),
                      _DesktopShortcutRow(
                        label: l10n.text(
                          zh: '开始 / 停止录音（STT 页面）',
                          en: 'Start / stop recording (STT page)',
                        ),
                        shortcuts: const ['SPACE'],
                      ),
                      _DesktopShortcutRow(
                        label: l10n.text(
                          zh: '切换页面',
                          en: 'Switch pages',
                        ),
                        shortcuts: const [
                          'CTRL+1',
                          'CTRL+2',
                          'CTRL+3',
                          'CTRL+4',
                        ],
                      ),
                      _DesktopShortcutRow(
                        label: l10n.text(
                          zh: '搜索历史记录',
                          en: 'Search history',
                        ),
                        shortcuts: const ['CTRL+F'],
                      ),
                      _DesktopShortcutRow(
                        label: l10n.text(
                          zh: '导入音频（STT 页面）',
                          en: 'Import audio (STT page)',
                        ),
                        shortcuts: const ['CTRL+O'],
                      ),
                      _DesktopShortcutRow(
                        label: l10n.text(
                          zh: '生成语音 / 保存设置',
                          en: 'Generate speech / save settings',
                        ),
                        shortcuts: const ['CTRL+ENTER'],
                      ),
                      _DesktopShortcutRow(
                        label: l10n.text(
                          zh: '关闭播放器',
                          en: 'Close player',
                        ),
                        shortcuts: const ['ESC'],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DesktopSettingsCard(
                    children: [
                      _DesktopSettingsRow(
                        name: l10n.text(
                          zh: '诊断日志',
                          en: 'Diagnostic logs',
                        ),
                        description: l10n.text(
                          zh: '记录接口路径、状态码、模型和脱敏错误；不会记录密钥、音频或输入正文。',
                          en: 'Records endpoint paths, status codes, models, and redacted errors, never keys, audio, or input content.',
                        ),
                        control: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
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
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DesktopSettingsCard(
                    children: [
                      _DesktopSettingsRow(
                        name: l10n.text(
                          zh: '本地偏好',
                          en: 'Local preferences',
                        ),
                        description: l10n.text(
                          zh: '重置 API 凭据、模型、主题与语言。历史记录、音频、日志和隐私确认不会被删除。',
                          en: 'Reset API credentials, models, theme, and language. History, audio, logs, and the privacy acknowledgement are kept.',
                        ),
                        control: OutlinedButton.icon(
                          key: const Key('resetLocalPreferencesButton'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.error,
                            side: BorderSide(color: colors.error),
                          ),
                          onPressed: settings.isBusy
                              ? null
                              : _confirmResetLocalPreferences,
                          icon: isResetting
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.restart_alt),
                          label: Text(
                            isResetting
                                ? l10n.text(
                                    zh: '正在重置…',
                                    en: 'Resetting…',
                                  )
                                : l10n.text(
                                    zh: '重置偏好',
                                    en: 'Reset preferences',
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final expandAction =
                          MediaQuery.textScalerOf(context).scale(1) >= 1.6 ||
                              constraints.maxWidth < 420;
                      return Align(
                        alignment: AlignmentDirectional.centerEnd,
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
    );
  }

  Widget _buildMobileApiKeyField(AppLocalizations l10n) {
    return Semantics(
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
              ? l10n.text(zh: '未填写', en: 'Not entered')
              : l10n.text(zh: '已填写', en: 'Entered'))
          : _apiKeyController.text,
      onTap: _apiKeyFocusNode.requestFocus,
      customSemanticsActions: {
        CustomSemanticsAction(
          label: _obscureApiKey
              ? l10n.text(zh: '显示密钥', en: 'Show API key')
              : l10n.text(zh: '隐藏密钥', en: 'Hide API key'),
        ): _toggleApiKeyVisibility,
      },
      onSetText: (value) {
        setState(() {
          _apiKeyController.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
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
          style: AppTypography.numeric(
            Theme.of(context).textTheme.bodyMedium,
          ),
          decoration: InputDecoration(
            hintText: 'sk-…',
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              tooltip: _obscureApiKey
                  ? l10n.text(zh: '显示密钥', en: 'Show API key')
                  : l10n.text(zh: '隐藏密钥', en: 'Hide API key'),
              onPressed: _toggleApiKeyVisibility,
              icon: Icon(
                _obscureApiKey ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? l10n.text(zh: '请填写 API Key', en: 'Enter an API key')
              : null,
        ),
      ),
    );
  }

  Widget _buildDesktopApiKeyField(AppLocalizations l10n) {
    return SizedBox(
      width: 360,
      child: Semantics(
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
                ? l10n.text(zh: '未填写', en: 'Not entered')
                : l10n.text(zh: '已填写', en: 'Entered'))
            : _apiKeyController.text,
        onTap: _apiKeyFocusNode.requestFocus,
        customSemanticsActions: {
          CustomSemanticsAction(
            label: _obscureApiKey
                ? l10n.text(zh: '显示密钥', en: 'Show API key')
                : l10n.text(zh: '隐藏密钥', en: 'Hide API key'),
          ): _toggleApiKeyVisibility,
        },
        onSetText: (value) {
          setState(() {
            _apiKeyController.value = TextEditingValue(
              text: value,
              selection: TextSelection.collapsed(offset: value.length),
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
            style: const TextStyle(
              fontFamily: 'Cascadia Code',
              fontFamilyFallback: ['JetBrains Mono', 'Consolas'],
            ),
            decoration: InputDecoration(
              hintText: 'sk-…',
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                tooltip: _obscureApiKey
                    ? l10n.text(zh: '显示密钥', en: 'Show API key')
                    : l10n.text(zh: '隐藏密钥', en: 'Hide API key'),
                onPressed: _toggleApiKeyVisibility,
                icon: Icon(
                  _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? l10n.text(zh: '请填写 API Key', en: 'Enter an API key')
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmResetLocalPreferences() async {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: Theme.of(context).platform == TargetPlatform.android,
        icon: Icon(Icons.restart_alt, color: colors.error),
        title: Text(l10n.text(
          zh: '重置本地偏好？',
          en: 'Reset local preferences?',
        )),
        content: Text(l10n.text(
          zh: '这会清除 API Key，并将 Base URL、语音模型、主题和语言恢复为默认值。历史记录、关联音频、诊断日志和隐私确认都会保留。',
          en: 'This clears the API key and restores the Base URL, speech models, theme, and language to their defaults. History, associated audio, diagnostic logs, and the privacy acknowledgement are kept.',
        )),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.text(zh: '取消', en: 'Cancel')),
          ),
          Semantics(
            button: true,
            label: l10n.text(
              zh: '确认重置本地偏好，历史记录和隐私确认会保留',
              en: 'Confirm reset of local preferences. History and the privacy acknowledgement will be kept.',
            ),
            excludeSemantics: true,
            child: FilledButton(
              key: const Key('resetLocalPreferencesConfirmButton'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.text(zh: '重置', en: 'Reset')),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final message =
          await ref.read(settingsProvider.notifier).resetLocalPreferences();
      if (!mounted) {
        return;
      }
      final reset = ref.read(settingsProvider);
      setState(() {
        _apiKeyController.text = reset.apiKey;
        _apiKeyController.masked = true;
        _baseUrlController.text = reset.baseUrl;
        _sttModel = reset.sttModel;
        _ttsModel = reset.ttsModel;
        _sttModelDirty = false;
        _ttsModelDirty = false;
        _obscureApiKey = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.resolve(Localizations.localeOf(context)),
          ),
        ),
      );
    } on AppException catch (error) {
      _showException(error);
    }
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
        builder: (context) {
          final mobile = Theme.of(context).platform == TargetPlatform.android;
          final screenHeight = MediaQuery.sizeOf(context).height;
          return AlertDialog(
            scrollable: mobile,
            title: Text(l10n.text(
              zh: 'VoxFlow 诊断日志',
              en: 'VoxFlow diagnostic logs',
            )),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: mobile ? 560 : 760,
                maxHeight: mobile ? screenHeight * 0.42 : 420,
                minHeight: mobile ? 120 : 240,
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
          );
        },
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
      final notifier = ref.read(settingsProvider.notifier);
      final platform = Theme.of(context).platform;
      final useLiveModelSelectors = platform == TargetPlatform.android ||
          (platform == TargetPlatform.windows &&
              MediaQuery.sizeOf(context).width >= 760);
      final catalog = await notifier.fetchModels(
        apiKey: _apiKeyController.text,
        baseUrl: _baseUrlController.text,
      );
      if (mounted) {
        final current = ref.read(settingsProvider);
        final nextStt = _selectionAfterFetch(
          catalog.stt,
          useLiveModelSelectors ? current.sttModel : _sttModel,
        );
        final nextTts = _selectionAfterFetch(
          catalog.tts,
          useLiveModelSelectors ? current.ttsModel : _ttsModel,
        );
        if (useLiveModelSelectors) {
          if (nextStt != null) {
            await notifier.setSttModel(nextStt);
          }
          if (nextTts != null) {
            await notifier.setTtsModel(nextTts);
          }
          if (!mounted) {
            return;
          }
        }
        setState(() {
          _sttModelDirty = !useLiveModelSelectors && nextStt != _sttModel;
          _ttsModelDirty = !useLiveModelSelectors && nextTts != _ttsModel;
          _sttModel = nextStt;
          _ttsModel = nextTts;
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
      final platform = Theme.of(context).platform;
      final useLiveModelSelectors = platform == TargetPlatform.android ||
          (platform == TargetPlatform.windows &&
              MediaQuery.sizeOf(context).width >= 760);
      final currentSettings = ref.read(settingsProvider);
      final sttModel =
          useLiveModelSelectors ? currentSettings.sttModel : (_sttModel ?? '');
      final ttsModel =
          useLiveModelSelectors ? currentSettings.ttsModel : (_ttsModel ?? '');
      final message = testConnection
          ? await notifier.testConnection(
              apiKey: _apiKeyController.text,
              baseUrl: _baseUrlController.text,
              sttModel: sttModel,
              ttsModel: ttsModel,
            )
          : await notifier.save(
              apiKey: _apiKeyController.text,
              baseUrl: _baseUrlController.text,
              sttModel: sttModel,
              ttsModel: ttsModel,
            );
      if (mounted) {
        _sttModelDirty = false;
        _ttsModelDirty = false;
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

class _MobileSettingsCard extends StatelessWidget {
  const _MobileSettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MobileSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                color: colors.outlineVariant,
                indent: 18,
                endIndent: 18,
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _MobileSettingsRow extends StatelessWidget {
  const _MobileSettingsRow({
    required this.name,
    required this.description,
    required this.control,
    this.controlFullWidth = false,
  });

  final String name;
  final String description;
  final Widget control;
  final bool controlFullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 14.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 10),
          if (controlFullWidth)
            SizedBox(width: double.infinity, child: control)
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: control,
            ),
        ],
      ),
    );
  }
}

class _MobileSettingsIntro extends StatelessWidget {
  const _MobileSettingsIntro({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 14.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _MobileGestureRow extends StatelessWidget {
  const _MobileGestureRow({required this.label, required this.gesture});

  final String label;
  final String gesture;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tag = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          gesture,
          style: AppTypography.numeric(
            Theme.of(context).textTheme.labelSmall,
          ).copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.4;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: AppSpacing.xs),
                tag,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: Text(label)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: tag),
            ],
          );
        },
      ),
    );
  }
}

class _MobileSegmentOption<T> {
  const _MobileSegmentOption({
    required this.value,
    required this.label,
    this.key,
  });

  final T value;
  final String label;
  final Key? key;
}

class _MobileSegmentedControl<T> extends StatelessWidget {
  const _MobileSegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<_MobileSegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: MobileMotion.duration(context),
      curve: Curves.ease,
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: context.semanticColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadii.mobileControl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Wrap(
        spacing: AppSpacing.xxs,
        runSpacing: AppSpacing.xxs,
        children: [
          for (final option in options)
            _MobileSegmentButton(
              key: option.key,
              label: option.label,
              selected: option.value == value,
              onPressed: () => onChanged(option.value),
            ),
        ],
      ),
    );
  }
}

class _MobileSegmentButton extends StatefulWidget {
  const _MobileSegmentButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_MobileSegmentButton> createState() => _MobileSegmentButtonState();
}

class _MobileSegmentButtonState extends State<_MobileSegmentButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: MobileMotion.duration(context),
          curve: Curves.ease,
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
          decoration: BoxDecoration(
            color: widget.selected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.mobileControl - 3),
            border: _focused
                ? Border.all(color: context.semanticColors.focus, width: 2)
                : null,
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              onFocusChange: (focused) {
                if (_focused != focused) {
                  setState(() => _focused = focused);
                }
              },
              borderRadius: BorderRadius.circular(AppRadii.mobileControl - 3),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: widget.selected
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
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

class _DesktopSettingsCard extends StatelessWidget {
  const _DesktopSettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  color: colors.outlineVariant,
                  indent: AppSpacing.lg,
                  endIndent: AppSpacing.lg,
                ),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _DesktopSettingsRow extends StatelessWidget {
  const _DesktopSettingsRow({
    required this.name,
    required this.description,
    required this.control,
  });

  final String name;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labelBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 680 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.6;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                labelBlock,
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: control,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: labelBlock),
              const SizedBox(width: AppSpacing.lg),
              control,
            ],
          );
        },
      ),
    );
  }
}

class _DesktopSettingsIntro extends StatelessWidget {
  const _DesktopSettingsIntro({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _DesktopShortcutRow extends StatelessWidget {
  const _DesktopShortcutRow({
    required this.label,
    required this.shortcuts,
  });

  final String label;
  final List<String> shortcuts;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final keys = Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final shortcut in shortcuts) _DesktopKeycap(label: shortcut),
            ],
          );
          if (constraints.maxWidth < 520 || textScale >= 1.6) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: AppSpacing.xs),
                keys,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: Text(label)),
              const SizedBox(width: AppSpacing.md),
              keys,
            ],
          );
        },
      ),
    );
  }
}

class _DesktopKeycap extends StatelessWidget {
  const _DesktopKeycap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.semanticColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'Cascadia Code',
                    fontFamilyFallback: const [
                      'JetBrains Mono',
                      'Consolas',
                    ],
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopSegmentOption<T> {
  const _DesktopSegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _DesktopSegmentedControl<T> extends StatelessWidget {
  const _DesktopSegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<_DesktopSegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.semanticColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Wrap(
          spacing: AppSpacing.xxs,
          runSpacing: AppSpacing.xxs,
          children: [
            for (final option in options)
              _DesktopSegmentButton(
                label: option.label,
                selected: option.value == value,
                onPressed: () => onChanged(option.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSegmentButton extends StatefulWidget {
  const _DesktopSegmentButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_DesktopSegmentButton> createState() => _DesktopSegmentButtonState();
}

class _DesktopSegmentButtonState extends State<_DesktopSegmentButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
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
              color: widget.selected ? colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: widget.selected || _hovered
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
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
