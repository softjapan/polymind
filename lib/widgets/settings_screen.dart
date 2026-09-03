import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polymind/constants.dart';
import 'package:polymind/model/provider_config.dart';
import 'package:polymind/model/chatmodel.dart';
import 'package:polymind/repository/llm_repository.dart';
import 'package:polymind/repository/openai_repository.dart';
import 'package:polymind/repository/ollama_repository.dart';
import 'package:polymind/repository/gemini_repository.dart';
import 'package:polymind/repository/claude_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late LlmProvider _provider;
  late TextEditingController _endpointController;
  late TextEditingController _modelController;
  late TextEditingController _imageModelController;
  late TextEditingController _apiKeyController;
  late double _temperature;
  bool _fetchingModels = false;

  bool get _supportsImageGeneration =>
      _provider == LlmProvider.openai || _provider == LlmProvider.other;
  bool get _requiresApiKey => _provider != LlmProvider.ollama;

  @override
  void initState() {
    super.initState();
    final config =
        ref.read(chatProvider).config ?? ProviderConfig.defaultOpenAi;
    _provider = config.provider;
    _endpointController = TextEditingController(text: config.endpoint);
    _modelController = TextEditingController(text: config.model);
    _imageModelController =
        TextEditingController(text: config.imageModel ?? '');
    _apiKeyController = TextEditingController(text: config.apiKey ?? '');
    _temperature = config.temperature;
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _modelController.dispose();
    _imageModelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _onProviderChanged(LlmProvider? provider) {
    if (provider == null) return;
    setState(() {
      _provider = provider;
      final defaults = switch (provider) {
        LlmProvider.openai => ProviderConfig.defaultOpenAi,
        LlmProvider.ollama => ProviderConfig.defaultOllama,
        LlmProvider.gemini => ProviderConfig.defaultGemini,
        LlmProvider.claude => ProviderConfig.defaultClaude,
        LlmProvider.other => ProviderConfig.defaultOther,
      };
      _endpointController.text = defaults.endpoint;
      _modelController.text = defaults.model;
      _imageModelController.text = defaults.imageModel ?? '';
      if (provider == LlmProvider.ollama) _apiKeyController.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final config = ProviderConfig(
      provider: _provider,
      endpoint: _endpointController.text.trim(),
      model: _modelController.text.trim(),
      imageModel: _imageModelController.text.trim().isNotEmpty
          ? _imageModelController.text.trim()
          : null,
      apiKey: _apiKeyController.text.trim().isNotEmpty
          ? _apiKeyController.text.trim()
          : null,
      temperature: _temperature,
    );

    await ref.read(chatProvider).updateConfig(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.of(context).pop();
    }
  }

  LlmRepository _buildTempRepository(ProviderConfig config) {
    switch (config.provider) {
      case LlmProvider.openai:
        return OpenAiRepository(config);
      case LlmProvider.ollama:
        return OllamaRepository(config);
      case LlmProvider.gemini:
        return GeminiRepository(config);
      case LlmProvider.claude:
        return ClaudeRepository(config);
      case LlmProvider.other:
        return OpenAiRepository(config);
    }
  }

  Future<void> _fetchModels() async {
    if (_requiresApiKey && _apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an API key first')),
      );
      return;
    }
    if (_endpointController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an endpoint first')),
      );
      return;
    }

    setState(() => _fetchingModels = true);
    try {
      final config = ProviderConfig(
        provider: _provider,
        endpoint: _endpointController.text.trim(),
        model: _modelController.text.trim(),
        apiKey: _apiKeyController.text.trim().isNotEmpty
            ? _apiKeyController.text.trim()
            : null,
      );
      final repo = _buildTempRepository(config);
      final models = await repo.listModels();

      if (!mounted) return;
      if (models.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No models found')),
        );
        return;
      }

      final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _ModelPickerSheet(models: models),
      );
      if (selected != null) {
        setState(() => _modelController.text = selected);
      }
    } catch (e) {
      debugPrint('listModels error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to fetch models. Check endpoint and API key.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supportsImageGeneration = _supportsImageGeneration;
    final requiresApiKey = _requiresApiKey;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Provider Section ---
              _SectionHeader(title: 'Provider'),
              const SizedBox(height: 8),
              DropdownButtonFormField<LlmProvider>(
                value: _provider,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.cloud_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: LlmProvider.openai,
                    child: Text('OpenAI'),
                  ),
                  DropdownMenuItem(
                    value: LlmProvider.ollama,
                    child: Text('Ollama (Local)'),
                  ),
                  DropdownMenuItem(
                    value: LlmProvider.gemini,
                    child: Text('Gemini'),
                  ),
                  DropdownMenuItem(
                    value: LlmProvider.claude,
                    child: Text('Claude'),
                  ),
                  DropdownMenuItem(
                    value: LlmProvider.other,
                    child: Text('Other (OpenAI-compatible)'),
                  ),
                ],
                onChanged: _onProviderChanged,
              ),
              const SizedBox(height: 6),
              Text(
                switch (_provider) {
                  LlmProvider.openai =>
                    'Connects to OpenAI-compatible API endpoints.',
                  LlmProvider.ollama => 'Connects to a local Ollama instance.',
                  LlmProvider.gemini => 'Connects to the Google Gemini API.',
                  LlmProvider.claude => 'Connects to the Anthropic Claude API.',
                  LlmProvider.other =>
                    'Connects to any other OpenAI API-compatible endpoint '
                        '(self-hosted or third-party gateways).',
                },
                style: TextStyle(fontSize: 12, color: context.colors.darkGray),
              ),

              const SizedBox(height: 24),

              // --- Connection Section ---
              _SectionHeader(title: 'Connection'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _endpointController,
                decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (requiresApiKey &&
                      !v.trim().toLowerCase().startsWith('https://')) {
                    return 'Endpoint must use HTTPS';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: 'Model',
                  prefixIcon: const Icon(Icons.smart_toy_outlined),
                  suffixIcon: _fetchingModels
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Fetch model list',
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: _fetchModels,
                        ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 20),
              _SectionHeader(title: 'Generation'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Temperature',
                    style: TextStyle(fontSize: 14, color: context.colors.black),
                  ),
                  const Spacer(),
                  Text(
                    _temperature.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.darkGray,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _temperature,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) => setState(() => _temperature = v),
              ),
              Text(
                'Lower is more focused and deterministic; higher is more '
                'creative and varied.',
                style: TextStyle(fontSize: 12, color: context.colors.darkGray),
              ),

              if (supportsImageGeneration) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageModelController,
                  decoration: const InputDecoration(
                    labelText: 'Image Model',
                    prefixIcon: Icon(Icons.image_outlined),
                    hintText: 'Optional',
                  ),
                ),
              ],

              if (requiresApiKey) ...[
                const SizedBox(height: 24),

                // --- Authentication Section ---
                _SectionHeader(title: 'Authentication'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                  validator: (v) {
                    if (requiresApiKey && (v == null || v.trim().isEmpty)) {
                      return 'This provider requires an API key';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Stored securely on device. Never sent to third parties.',
                  style: TextStyle(fontSize: 12, color: context.colors.darkGray),
                ),
              ],

              const SizedBox(height: 32),

              // Save
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelPickerSheet extends StatefulWidget {
  const _ModelPickerSheet({required this.models});

  final List<String> models;

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.models
        .where((m) => m.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Search models',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, index) {
                  final model = filtered[index];
                  return ListTile(
                    title: Text(model),
                    onTap: () => Navigator.of(context).pop(model),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.colors.darkGray,
        letterSpacing: 0.5,
      ),
    );
  }
}
