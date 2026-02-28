import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_chatgpt/model/provider_config.dart';

/// flutter_secure_storage を使ったセキュア設定管理
class SecureSettings {
  SecureSettings([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _keyProvider = 'provider';
  static const _keyEndpoint = 'endpoint';
  static const _keyModel = 'model';
  static const _keyImageModel = 'imageModel';
  static const _keyApiKey = 'apiKey';

  /// 設定を保存
  Future<void> save(ProviderConfig config) async {
    await _storage.write(key: _keyProvider, value: config.provider.name);
    await _storage.write(key: _keyEndpoint, value: config.endpoint);
    await _storage.write(key: _keyModel, value: config.model);
    await _storage.write(
      key: _keyImageModel,
      value: config.imageModel ?? '',
    );
    await _storage.write(key: _keyApiKey, value: config.apiKey ?? '');
  }

  /// 設定を読み込み（未設定なら null）
  Future<ProviderConfig?> load() async {
    try {
      final providerName = await _storage.read(key: _keyProvider);
      if (providerName == null) return null;

      final provider = LlmProvider.values.firstWhere(
        (e) => e.name == providerName,
        orElse: () => LlmProvider.openai,
      );

      final endpoint = await _storage.read(key: _keyEndpoint) ?? '';
      final model = await _storage.read(key: _keyModel) ?? '';
      final imageModel = await _storage.read(key: _keyImageModel);
      final apiKey = await _storage.read(key: _keyApiKey);

      return ProviderConfig(
        provider: provider,
        endpoint: endpoint,
        model: model,
        imageModel: imageModel?.isNotEmpty == true ? imageModel : null,
        apiKey: apiKey?.isNotEmpty == true ? apiKey : null,
      );
    } on FormatException {
      // 暗号化方式の変更等でデータが破損した場合はクリアして再設定を促す
      await clear();
      return null;
    }
  }

  /// 設定が存在するか
  Future<bool> hasConfig() async {
    final provider = await _storage.read(key: _keyProvider);
    return provider != null;
  }

  /// 設定を全削除
  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
