import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/app_theme_choice.dart';
import '../services/chat_api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/status_pill.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _model = TextEditingController();
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _systemPrompt = TextEditingController();
  final TextEditingController _maxTokens = TextEditingController();

  AppState? _state;
  bool _ready = false;
  bool _obscureKey = true;
  double _temperature = 0.7;
  double _topP = 1.0;
  bool _useTopP = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _state = AppScope.of(context);
    final settings = _state!.settings;
    _url.text = settings.baseUrl;
    _model.text = settings.model;
    _apiKey.text = settings.apiKey;
    _systemPrompt.text = settings.systemPrompt;
    _temperature = settings.temperature;
    _maxTokens.text = settings.maxOutputTokens?.toString() ?? '';
    _topP = settings.topP ?? 1.0;
    _useTopP = settings.topP != null;
    _ready = true;
  }

  @override
  void dispose() {
    _url.dispose();
    _model.dispose();
    _apiKey.dispose();
    _systemPrompt.dispose();
    _maxTokens.dispose();
    super.dispose();
  }

  void _apply({
    String? baseUrl,
    String? model,
    String? apiKey,
    String? systemPrompt,
    double? temperature,
    int? maxOutputTokens,
    bool clearMaxOutputTokens = false,
    double? topP,
    bool clearTopP = false,
    AppThemeChoice? theme,
  }) {
    final state = _state;
    if (state == null) return;
    state.updateSettings(
      state.settings.copyWith(
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        temperature: temperature,
        maxOutputTokens: maxOutputTokens,
        clearMaxOutputTokens: clearMaxOutputTokens,
        topP: topP,
        clearTopP: clearTopP,
        theme: theme,
      ),
    );
  }

  void _submitUrl(String value) {
    final normalized = AppSettings.normalizeBaseUrl(value);
    _url.text = normalized;
    _url.selection = TextSelection.collapsed(offset: normalized.length);
    _apply(baseUrl: normalized);
    _state?.refreshStatus();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.palette.surface,
        title: const Text('Delete all chats?'),
        content: const Text(
          'Every conversation on this device will be removed. '
          'This cannot be undone.',
          style: TextStyle(fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) _state?.clearAllConversations();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final palette = context.palette;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, size: 21),
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const _SectionLabel('Connection'),
          _Card(
            child: Column(
              children: [
                _Field(
                  label: 'Server URL',
                  controller: _url,
                  hint: AppSettings.defaultBaseUrl,
                  helper:
                      'OpenAI-compatible base URL. On a physical phone, '
                      '127.0.0.1 is the phone — use your computer\'s LAN IP '
                      'or run adb reverse.',
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onChanged: (value) => _apply(baseUrl: value),
                  onSubmitted: _submitUrl,
                ),
                const SizedBox(height: 16),
                _Field(
                  label: 'Model',
                  controller: _model,
                  hint: 'Server default',
                  helper: 'Leave empty to let the server pick a model.',
                  autocorrect: false,
                  onChanged: (value) => _apply(model: value),
                ),
                if (state != null) ...[
                  const SizedBox(height: 10),
                  _ModelPicker(
                    state: state,
                    selected: _model.text.trim(),
                    onSelect: (id) {
                      _model.text = id;
                      _apply(model: id);
                      setState(() {});
                    },
                  ),
                ],
                const SizedBox(height: 16),
                _Field(
                  label: 'API key',
                  controller: _apiKey,
                  hint: 'Optional',
                  helper: 'Sent as a Bearer token. Stored only on this device.',
                  obscureText: _obscureKey,
                  autocorrect: false,
                  onChanged: (value) => _apply(apiKey: value),
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    tooltip: _obscureKey ? 'Show key' : 'Hide key',
                    icon: Icon(
                      _obscureKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: palette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state != null)
            ListenableBuilder(
              listenable: state,
              builder: (context, _) {
                final error = state.secretStorageError;
                if (error == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: theme.colorScheme.error,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 10),
          if (state != null)
            ListenableBuilder(
              listenable: state,
              builder: (context, _) {
                final status = state.status;
                final checking = status.health == ServerHealth.checking;
                return Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      StatusDot(status: status, size: 8),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              statusHeadline(status, state.modelLabel),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (status.endpoint != null) ...[
                              const SizedBox(height: 4),
                              SelectableText(
                                'GET ${status.endpoint}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: palette.muted,
                                ),
                              ),
                            ],
                            if (status.message != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                status.message!,
                                maxLines: 3,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: palette.muted,
                                ),
                              ),
                            ],
                            if (status.hint != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                status.hint!,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: checking
                            ? null
                            : () => state.refreshStatus(),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(checking ? 'Testing…' : 'Test'),
                      ),
                    ],
                  ),
                );
              },
            ),
          const _SectionLabel('Behaviour'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(
                  label: 'System prompt',
                  controller: _systemPrompt,
                  hint: 'You are a helpful assistant.',
                  helper: 'Prepended to every conversation.',
                  maxLines: 4,
                  onChanged: (value) => _apply(systemPrompt: value),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'Temperature',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _temperature.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _temperature,
                  min: 0,
                  max: 1.5,
                  divisions: 30,
                  label: _temperature.toStringAsFixed(2),
                  onChanged: (value) {
                    setState(() => _temperature = value);
                    _apply(temperature: value);
                  },
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Maximum output tokens',
                  controller: _maxTokens,
                  hint: 'Server default',
                  helper:
                      'Optional. Leave empty to use the server default (1–32768).',
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    if (value.trim().isEmpty) {
                      _apply(clearMaxOutputTokens: true);
                    } else if (parsed != null &&
                        parsed >= 1 &&
                        parsed <= 32768) {
                      _apply(maxOutputTokens: parsed);
                    }
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Top-p sampling',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Optional nucleus sampling (0.00–1.00).',
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                  value: _useTopP,
                  onChanged: (enabled) {
                    setState(() => _useTopP = enabled);
                    if (enabled) {
                      _apply(topP: _topP);
                    } else {
                      _apply(clearTopP: true);
                    }
                  },
                ),
                if (_useTopP) ...[
                  Row(
                    children: [
                      Text(
                        'Top-p',
                        style: TextStyle(fontSize: 12, color: palette.muted),
                      ),
                      const Spacer(),
                      Text(
                        _topP.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _topP,
                    min: 0,
                    max: 1,
                    divisions: 100,
                    label: _topP.toStringAsFixed(2),
                    onChanged: (value) {
                      setState(() => _topP = value);
                      _apply(topP: value);
                    },
                  ),
                ],
              ],
            ),
          ),
          const _SectionLabel('Appearance'),
          _ThemePicker(
            selected: state?.settings.theme ?? AppThemeChoice.system,
            onSelected: (choice) => _apply(theme: choice),
          ),
          const _SectionLabel('Data'),
          _Card(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clear chat history',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Removes every conversation from this device.',
                        style: TextStyle(fontSize: 11.5, color: palette.muted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _confirmClear,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Text(
                  'Clearport 1.0.0',
                  style: TextStyle(fontSize: 11.5, color: palette.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  'A UI for your local AI server.',
                  style: TextStyle(fontSize: 11.5, color: palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 9),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      // A transparent Material keeps list tiles inside the card able to paint
      // their ink; without it Flutter asserts that splashes would be hidden by
      // the card's background.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.maxLines = 1,
    this.obscureText = false,
    this.autocorrect = true,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final int maxLines;
  final bool obscureText;
  final bool autocorrect;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          obscureText: obscureText,
          autocorrect: autocorrect,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: maxLines > 1
              ? TextInputAction.newline
              : TextInputAction.done,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              helper!,
              style: TextStyle(fontSize: 11, height: 1.4, color: palette.muted),
            ),
          ),
      ],
    );
  }
}

/// A grid of theme swatches. Scales past three options, unlike a segmented
/// button, and previews each palette before the user commits to it.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.selected, required this.onSelected});

  final AppThemeChoice selected;
  final ValueChanged<AppThemeChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth > 430 ? 3 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final choice in AppThemeChoice.values)
              SizedBox(
                width: width,
                child: _ThemeTile(
                  choice: choice,
                  selected: choice == selected,
                  onTap: () => onSelected(choice),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final AppThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final preview = choice == AppThemeChoice.system
        ? AppPalette.dark
        : AppPalette.forChoice(choice);

    return Semantics(
      button: true,
      selected: selected,
      label: '${choice.label} theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _Swatch(color: preview.bg, border: palette.border),
                  const SizedBox(width: 5),
                  _Swatch(color: preview.accent),
                  const SizedBox(width: 5),
                  _Swatch(color: preview.secondary),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_rounded, size: 15, color: palette.accent),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                choice.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                choice.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.border});

  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border ?? color, width: 1),
      ),
    );
  }
}

/// Lists the models the server reports, so the ID does not have to be typed.
///
/// Manual entry stays available: some servers expose no model list at all, and
/// a proxy may accept an alias that is not advertised.
class _ModelPicker extends StatelessWidget {
  const _ModelPicker({
    required this.state,
    required this.selected,
    required this.onSelect,
  });

  final AppState state;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final status = state.status;
        final checking = status.health == ServerHealth.checking;
        final models = status.models;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Available on the server',
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
                const Spacer(),
                TextButton(
                  onPressed: checking ? null : () => state.refreshStatus(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: checking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Check', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
            if (models.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  checking
                      ? 'Asking the server…'
                      : status.health == ServerHealth.offline
                      ? 'No server reachable. Type the model ID above, or start '
                            'your server and check again.'
                      : 'The server reported no models. Type the ID above.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: palette.muted,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in models)
                    ChoiceChip(
                      label: Text(id, style: const TextStyle(fontSize: 12)),
                      selected: id == selected,
                      onSelected: (_) => onSelect(id),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: palette.surface,
                      selectedColor: palette.accent.withValues(alpha: 0.18),
                      side: BorderSide(
                        color: id == selected ? palette.accent : palette.border,
                      ),
                      labelStyle: TextStyle(
                        color: id == selected
                            ? palette.accent
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
