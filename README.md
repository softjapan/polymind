# PolyMind

**OSS なマルチプロバイダー AI チャットクライアント — OpenAI / Gemini / Claude / Ollama をシームレスに切り替え**

![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B?logo=flutter) ![Riverpod](https://img.shields.io/badge/Riverpod-2.x-50C878?logo=dart) ![LangChain](https://img.shields.io/badge/LangChain-Dart-2e7d32) ![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

---

## 概要

Flutter × Riverpod × LangChain で構築した、LINE 風 UI のオープンソース AI チャットクライアントです。  
OpenAI・Google Gemini・Anthropic Claude・Ollama（ローカル LLM）に対応し、アプリ内の設定画面からプロバイダー・モデル・エンドポイントを自由に切り替えられます。

API キーは `flutter_secure_storage` で安全に保管され、チャット履歴は SQLite に永続化。会話の一覧・切り替え・削除をサイドドロワーから操作できます。

---

## デモ動画

https://github.com/user-attachments/assets/fc89e894-818c-42a9-a589-b94df6c14388

---

## 主な機能

| 機能 | 説明 |
|------|------|
| **マルチ LLM 対応** | OpenAI / Gemini / Claude / Ollama（ローカル LLM）を設定画面から切り替え |
| **リアルタイム・ストリーミング** | LangChain の各 Chat モデルでトークン単位のストリーム描画 |
| **画像生成** | `/image <prompt>` コマンドで OpenAI 画像生成 API を呼び出し、チャット内にサムネイル表示 |
| **フルスクリーン画像ビューア** | ピンチズーム対応のプレビュー、ローカルへのダウンロード機能 |
| **チャット履歴の永続化** | SQLite で会話・メッセージを保存、サイドドロワーから一覧・切り替え・削除 |
| **セキュアな設定管理** | API キーを `flutter_secure_storage` で暗号化保存（`.env` 不要） |
| **シンタックスハイライト** | AI 応答内のコードブロックを `highlight` パッケージで自動カラーリング |
| **Markdown レンダリング** | `flutter_markdown` による見出し・リスト・コード・リンク等の表示 |
| **洗練された UI** | LINE 風チャットバブル、アニメーション付きローディング、Material 3 テーマ |
| **クロスプラットフォーム** | iOS / Android / macOS / Web に対応 |

---

## スクリーンショット

![チャット画面](./flutter-chatgpt.png)

---

## アーキテクチャ

```
lib/
├── main.dart                          # エントリポイント + UI ルート
├── constants.dart                     # カラー定義 + Material 3 テーマ
├── model/
│   ├── chat_message.dart              # 不変メッセージモデル
│   ├── chatmodel.dart                 # ChangeNotifier（状態管理）
│   └── provider_config.dart           # LLM プロバイダー設定モデル
├── repository/
│   ├── llm_repository.dart            # LLM 抽象インターフェース
│   ├── openai_repository.dart         # OpenAI 実装（LangChain）
│   ├── ollama_repository.dart         # Ollama 実装（LangChain）
│   ├── gemini_repository.dart         # Gemini 実装（LangChain）
│   ├── claude_repository.dart         # Claude 実装（LangChain）
│   ├── secure_settings.dart           # flutter_secure_storage ラッパー
│   └── chat_database.dart             # SQLite チャット履歴
└── widgets/
    ├── ai_message.dart                # AI バブル（Markdown + 画像）
    ├── user_message.dart              # ユーザーバブル
    ├── user_input.dart                # 入力フィールド
    ├── loading.dart                   # ローディングアニメーション
    ├── code_block.dart                # シンタックスハイライター
    ├── settings_screen.dart           # プロバイダー設定画面
    └── conversation_drawer.dart       # 会話一覧ドロワー
```

| レイヤー | 役割 |
|----------|------|
| **Presentation** | Flutter Widgets + Material 3 + Markdown 表示 |
| **State** | Riverpod + ChangeNotifier によるメッセージ・設定管理 |
| **Repository** | LangChain 経由の LLM 通信、SQLite 永続化、セキュア設定 |

---

## 技術スタック

| カテゴリ | パッケージ |
|----------|-----------|
| UI | `flutter_markdown`, `flutter_svg`, `cached_network_image` |
| 状態管理 | `flutter_riverpod` |
| LLM 連携 | `langchain`, `langchain_openai`, `langchain_ollama`, `langchain_google`, `langchain_anthropic` |
| シンタックスハイライト | `highlight` |
| ストレージ | `sqflite`, `flutter_secure_storage`, `path_provider` |
| ネットワーク | `http` |

---

## セットアップ

### 前提条件

- Flutter 3.19 以上
- Dart 3.3 以上
- （Ollama 使用時）[Ollama](https://ollama.ai) がローカルで起動していること

### インストール

```bash
git clone https://github.com/softjapan/flutter_chatgpt.git
cd flutter_chatgpt
flutter pub get
flutter run
```

> リポジトリ名は移行前の `flutter_chatgpt` のままです（別途リポジトリ名の変更が必要）。

### 初回設定

`.env` ファイルは不要です。アプリ起動後、設定画面からプロバイダーを選択してください。

| 項目 | OpenAI | Gemini | Claude | Ollama |
|------|--------|--------|--------|--------|
| Endpoint | `https://api.openai.com/v1` | `https://generativelanguage.googleapis.com` | `https://api.anthropic.com` | `http://localhost:11434` |
| Model | `gpt-4o-mini-2024-07-18` 等 | `gemini-2.5-flash` 等 | `claude-sonnet-4-5` 等 | `llama3.2` 等 |
| Image Model | `gpt-image-1`（任意） | — | — | — |
| API Key | 必須 | 必須 | 必須 | 不要 |

---

## 使い方

- 通常のメッセージを送信すると、AI の応答が Markdown としてリアルタイム描画されます
- `/image <プロンプト>` または `/img <プロンプト>` で画像を生成（OpenAI のみ）
- 生成された画像はタップで全画面表示 → ピンチズーム → ダウンロード
- サイドドロワーから過去の会話を切り替え・削除
- 設定画面から LLM プロバイダーをいつでも変更可能

---

## コマンド

| 用途 | コマンド |
|------|---------|
| 依存関係の取得 | `flutter pub get` |
| アプリ起動 | `flutter run` |
| テスト実行 | `flutter test` |
| 静的解析 | `flutter analyze` |
| ビルド | `flutter build <platform>` |

---

## コントリビューション

1. リポジトリを Fork
2. ブランチを作成: `git checkout -b feature/awesome-feature`
3. コミット: `git commit -m "Add awesome feature"`
4. Push & Pull Request: `git push origin feature/awesome-feature`

---

## ライセンス

[MIT License](./LICENSE)

---

## Author

- **Twitter**: [システムエンジニア@JP](https://twitter.com/fullstack_se)
- **GitHub**: [softjapan/flutter_chatgpt](https://github.com/softjapan/flutter_chatgpt)
