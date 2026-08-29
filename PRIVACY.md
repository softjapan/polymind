# Privacy Policy for PolyMind

**Last updated: August 28, 2026**

PolyMind ("the App") is an open-source, multi-provider AI chat client built with Flutter. This policy explains what data the App handles and how, in plain terms.

## Summary

- PolyMind has **no backend server of its own**. It is a direct client between your device and the AI provider you choose to configure (OpenAI, Google Gemini, Anthropic Claude, or a self-hosted Ollama instance).
- The developer of PolyMind **does not collect, receive, or have access to** your API keys, messages, or chat history at any point.
- There is **no analytics, advertising, or tracking SDK** in the App.

## What data the App handles, and where it goes

### API keys
When you enter an API key in Settings, it is stored only on your device using the operating system's secure credential storage (the iOS/macOS Keychain, or Android's `EncryptedSharedPreferences`). It is never sent anywhere except as an authorization header in requests to the AI provider you selected. It is not sent to the App's developer or any analytics service.

### Chat messages
When you send a message, it is transmitted directly from your device to the AI provider you configured in Settings (OpenAI, Google, Anthropic, or your own Ollama server), over HTTPS. The App's developer does not operate a server in this path and does not see this content. Each provider's own privacy policy governs how they process the messages you send them:

- OpenAI: https://openai.com/privacy
- Google (Gemini API): https://policies.google.com/privacy
- Anthropic (Claude): https://www.anthropic.com/legal/privacy
- Ollama: governed by wherever you choose to run your own Ollama instance; no data leaves your local network unless you point the App at a remote server yourself.

### Chat history
Conversations are stored locally on your device in a local database (SQLite) so you can revisit past chats. This history is never uploaded or synced to any server operated by the developer. Deleting a conversation in the App removes it from local storage; uninstalling the App removes all local data.

### Generated images
If you use the `/image` command (OpenAI only), the resulting image is displayed in the chat and, only if you explicitly tap "Download," saved to the App's local storage on your device. Images are not uploaded anywhere else by the App.

## Data we do not collect

PolyMind does not collect analytics, crash reports, advertising identifiers, or any other telemetry. It does not include third-party advertising or analytics SDKs.

## Your choices

- You can change or remove your API key at any time from Settings.
- You can delete individual conversations from the conversation list.
- Uninstalling the App deletes all locally stored data (API keys, chat history).

## Children's privacy

PolyMind is not directed at children and is not designed to knowingly collect data from children. Because the App connects to third-party AI providers, please review each provider's own terms regarding minimum age before use.

## Open source

PolyMind is open source. You can review exactly how data is handled in the source code:
https://github.com/softjapan/flutter_chatgpt

## Changes to this policy

If this policy changes, the updated version will be published at this same location with a revised "Last updated" date.

## Contact

Questions about this policy can be directed to the developer via the GitHub repository linked above.
