import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chatgpt/constants.dart';
import 'package:flutter_chatgpt/model/provider_config.dart';
import 'package:flutter_chatgpt/model/chatmodel.dart';

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
      final defaults = provider == LlmProvider.openai
          ? ProviderConfig.defaultOpenAi
          : ProviderConfig.defaultOllama;
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
    );

    await ref.read(chatProvider).updateConfig(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpenAi = _provider == LlmProvider.openai;

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
                ],
                onChanged: _onProviderChanged,
              ),
              const SizedBox(height: 6),
              Text(
                isOpenAi
                    ? 'Connects to OpenAI-compatible API endpoints.'
                    : 'Connects to a local Ollama instance.',
                style: TextStyle(fontSize: 12, color: FcColors.darkGray),
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
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  prefixIcon: Icon(Icons.smart_toy_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),

              if (isOpenAi) ...[
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

              if (isOpenAi) ...[
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
                    if (isOpenAi && (v == null || v.trim().isEmpty)) {
                      return 'OpenAI requires an API key';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Stored securely on device. Never sent to third parties.',
                  style: TextStyle(fontSize: 12, color: FcColors.darkGray),
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
        color: FcColors.darkGray,
        letterSpacing: 0.5,
      ),
    );
  }
}
