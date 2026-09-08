import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:polymind/model/provider_config.dart';

/// flutter_secure_storage を使ったセキュア設定管理
class SecureSettings {
  SecureSettings([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  /// 現在アクティブなプロバイダー名を覚えておくキー
  static const _keyActiveProvider = 'activeProvider';

  // 各設定項目はプロバイダーごとに名前空間を分けて保存する
  // （例: "endpoint_openai", "apiKey_gemini"）。こうすることで、
  // プロバイダーを切り替えても各プロバイダーの API Key 等が
  // 上書きされずに残る。
  static const _fieldEndpoint = 'endpoint';
  static const _fieldModel = 'model';
  static const _fieldImageModel = 'imageModel';
  static const _fieldApiKey = 'apiKey';
  static const _fieldTemperature = 'temperature';

  String _scopedKey(String field, LlmProvider provider) =>
      '${field}_${provider.name}';

  /// 設定を保存（現在アクティブなプロバイダーとして記録する）
  Future<void> save(ProviderConfig config) async {
    await _storage.write(key: _keyActiveProvider, value: config.provider.name);
    await _saveForProvider(config);
  }

  /// 指定プロバイダーの設定だけを保存する（アクティブプロバイダーは変更しない）
  Future<void> _saveForProvider(ProviderConfig config) async {
    final provider = config.provider;
    await _storage.write(
      key: _scopedKey(_fieldEndpoint, provider),
      value: config.endpoint,
    );
    await _storage.write(
      key: _scopedKey(_fieldModel, provider),
      value: config.model,
    );
    await _storage.write(
      key: _scopedKey(_fieldImageModel, provider),
      value: config.imageModel ?? '',
    );
    await _storage.write(
      key: _scopedKey(_fieldApiKey, provider),
      value: config.apiKey ?? '',
    );
    await _storage.write(
      key: _scopedKey(_fieldTemperature, provider),
      value: config.temperature.toString(),
    );
  }

  /// 現在アクティブな設定を読み込み（未設定なら null）
  Future<ProviderConfig?> load() async {
    try {
      var providerName = await _storage.read(key: _keyActiveProvider);
      providerName ??= await _migrateLegacyConfig();
      if (providerName == null) return null;

      final provider = LlmProvider.values.firstWhere(
        (e) => e.name == providerName,
        orElse: () => LlmProvider.openai,
      );

      return await loadForProvider(provider);
    } on FormatException {
      // 暗号化方式の変更等でデータが破損した場合はクリアして再設定を促す
      await clear();
      return null;
    }
  }

  /// プロバイダー名前空間導入前（旧バージョン）の設定を新形式へ移行する。
  /// 旧キーが存在すればアクティブプロバイダーとして書き戻し、
  /// 旧キーは削除する。旧キーが無ければ null を返す。
  Future<String?> _migrateLegacyConfig() async {
    const legacyKeyProvider = 'provider';
    final legacyProviderName = await _storage.read(key: legacyKeyProvider);
    if (legacyProviderName == null) return null;

    const legacyKeyEndpoint = 'endpoint';
    const legacyKeyModel = 'model';
    const legacyKeyImageModel = 'imageModel';
    const legacyKeyApiKey = 'apiKey';
    const legacyKeyTemperature = 'temperature';

    final provider = LlmProvider.values.firstWhere(
      (e) => e.name == legacyProviderName,
      orElse: () => LlmProvider.openai,
    );
    final endpoint = await _storage.read(key: legacyKeyEndpoint) ?? '';
    final model = await _storage.read(key: legacyKeyModel) ?? '';
    final imageModel = await _storage.read(key: legacyKeyImageModel);
    final apiKey = await _storage.read(key: legacyKeyApiKey);
    final temperatureStr = await _storage.read(key: legacyKeyTemperature);
    final temperature = double.tryParse(temperatureStr ?? '') ?? 0.7;

    await save(
      ProviderConfig(
        provider: provider,
        endpoint: endpoint,
        model: model,
        imageModel: imageModel?.isNotEmpty == true ? imageModel : null,
        apiKey: apiKey?.isNotEmpty == true ? apiKey : null,
        temperature: temperature,
      ),
    );

    await _storage.delete(key: legacyKeyProvider);
    await _storage.delete(key: legacyKeyEndpoint);
    await _storage.delete(key: legacyKeyModel);
    await _storage.delete(key: legacyKeyImageModel);
    await _storage.delete(key: legacyKeyApiKey);
    await _storage.delete(key: legacyKeyTemperature);

    return provider.name;
  }

  /// 指定プロバイダーの保存済み設定を読み込み（未設定なら null）
  Future<ProviderConfig?> loadForProvider(LlmProvider provider) async {
    final endpoint = await _storage.read(
      key: _scopedKey(_fieldEndpoint, provider),
    );
    if (endpoint == null) return null;

    final model =
        await _storage.read(key: _scopedKey(_fieldModel, provider)) ?? '';
    final imageModel = await _storage.read(
      key: _scopedKey(_fieldImageModel, provider),
    );
    final apiKey = await _storage.read(key: _scopedKey(_fieldApiKey, provider));
    final temperatureStr = await _storage.read(
      key: _scopedKey(_fieldTemperature, provider),
    );
    final temperature = double.tryParse(temperatureStr ?? '') ?? 0.7;

    return ProviderConfig(
      provider: provider,
      endpoint: endpoint,
      model: model,
      imageModel: imageModel?.isNotEmpty == true ? imageModel : null,
      apiKey: apiKey?.isNotEmpty == true ? apiKey : null,
      temperature: temperature,
    );
  }

  /// 設定が存在するか
  Future<bool> hasConfig() async {
    final provider = await _storage.read(key: _keyActiveProvider);
    return provider != null;
  }

  /// 設定を全削除
  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
