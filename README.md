# Clearport

A clean, minimal Flutter chat client for a local AI server. Streaming replies, saved conversations, and a live model status indicator — no cloud, no accounts, no telemetry.

Built Android-first. The UI is platform-agnostic, so desktop is a `flutter create` away.

> **Scope:** Clearport is the frontend only. It does not bundle or run a model — you point it at an OpenAI-compatible server (Ollama, LM Studio, llama.cpp, vLLM, LocalAI…).

## Features

- **Streaming responses** over Server-Sent Events, rendered token by token with a smooth, throttled UI update loop
- **Conversation history** persisted on device; new chat, switch, delete, regenerate, stop generation
- **Model status** in the header — pings `/models`, discovers the model name, refreshes every 30s or on tap
- **Settings** — server URL, model, optional API key, system prompt, temperature, theme
- **Light / dark / system** Material 3 themes with a small hand-rolled markdown renderer (code blocks, bold, italic, inline code)
- **Copy** any reply; errors render inline with a retry action
- No `.env` files, no secrets, no third-party services

## Requirements

| Tool | Version |
| --- | --- |
| Flutter | 3.27+ (built and tested on 3.44.8) |
| Dart | 3.6+ |
| Android SDK | API 21+ device, SDK 36 to build |
| Local AI server | Any OpenAI-compatible API on port 8080 |

## Quick start

```bash
git clone https://github.com/Adams-404/clearport.git
cd clearport
flutter pub get
flutter run
```

With no server running, the app still opens and shows **Offline** — that's expected.

```bash
flutter test      # parser, URL normalization, title helpers
flutter analyze
```

## Connect it to your server

Open **Settings → Server URL** and enter an OpenAI-compatible base URL. The default is:

```
http://127.0.0.1:8080/v1
```

Clearport calls:

| Purpose | Request |
| --- | --- |
| Chat | `POST {baseUrl}/chat/completions` with `"stream": true` |
| Status | `GET {baseUrl}/models` |

If you paste a full endpoint (e.g. `http://127.0.0.1:8080/v1/chat/completions`), the app trims it back to the base URL for you.

Example server contract:

```bash
curl -N http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"local","stream":true,
       "messages":[{"role":"user","content":"Hello"}]}'
```

Expected stream (OpenAI shape):

```
data: {"choices":[{"delta":{"content":"Hel"}}]}
data: {"choices":[{"delta":{"content":"lo"}}]}
data: [DONE]
```

The parser also accepts Ollama's native `{"message":{"content":"…"}}` / `{"response":"…"}` shapes and plain-text streams, so most local servers work without changes.

### Servers that work

- **Ollama** — `ollama serve`, then use `http://127.0.0.1:11434/v1` (OpenAI compatibility)
- **LM Studio** — enable the local server, use `http://127.0.0.1:1234/v1`
- **llama.cpp** (`llama-server`) — use `http://127.0.0.1:8080/v1`
- **vLLM**, **LocalAI**, **text-generation-webui** — use their OpenAI-compatible base URL

### ⚠️ `127.0.0.1` on a phone is the phone

This is the most common setup mistake:

| Where the app runs | URL to use |
| --- | --- |
| Android **emulator** | `http://10.0.2.2:8080/v1` |
| Physical phone over **USB** | `http://127.0.0.1:8080/v1` **after** `adb reverse tcp:8080 tcp:8080` |
| Physical phone over **Wi‑Fi** | `http://<your-computer-LAN-IP>:8080/v1`, e.g. `http://192.168.1.20:8080/v1` |

For the Wi‑Fi option, start your server on `0.0.0.0` (not just localhost), keep both devices on the same network, and allow port 8080 through your computer's firewall.

`adb reverse` is the simplest path:

```bash
adb reverse tcp:8080 tcp:8080
# then leave the app's URL as http://127.0.0.1:8080/v1
```

## Install on your phone

### Option A — run from your computer over USB (fastest)

1. On the phone: **Settings → About phone**, tap **Build number** seven times to unlock Developer options.
2. In **Developer options**, enable **USB debugging**.
3. Connect the phone, tap **Allow** on the debugging prompt.
4. Verify the device is visible:

   ```bash
   flutter devices
   adb devices
   ```

5. Run:

   ```bash
   flutter run
   ```

6. If your server runs on the computer:

   ```bash
   adb reverse tcp:8080 tcp:8080
   ```

   Keep the app's URL at `http://127.0.0.1:8080/v1`.

### Option B — build an APK and install it

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Or copy `build/app/outputs/flutter-apk/app-release.apk` to the phone (USB, Drive, Telegram…), tap it, and allow **Install unknown apps** for that file manager.

The release build is signed with the debug keystore, which is fine for personal sideloading. Configure a proper keystore before publishing to Play.

### Option C — Android Studio

Open the project folder, pick your device in the toolbar, and press **Run**.

> On first launch the app has no conversations. Start typing, or tap a suggestion chip.

## Settings

| Field | What it does |
| --- | --- |
| **Server URL** | OpenAI-compatible base URL. Default `http://127.0.0.1:8080/v1` |
| **Model** | Optional model id sent with each request. Empty = server default |
| **API key** | Optional `Authorization: Bearer …` header for protected servers |
| **System prompt** | Prepended as a system message to every request |
| **Temperature** | 0.00–1.50, sent with each request |
| **Theme** | System / Light / Dark |
| **Clear chat history** | Deletes every conversation on the device |

Settings and history are stored as JSON in the app's private support directory. No data leaves the device except requests to the server URL you configure.

## Project structure

```
lib/
├── main.dart                 # bootstrap: load store → run app
├── app.dart                  # MaterialApp + theme mode
├── theme.dart                # palette, light/dark themes
├── models/                   # ChatMessage, Conversation, AppSettings
├── services/
│   ├── chat_api.dart         # streaming HTTP client + status probe
│   ├── stream_parser.dart    # SSE / NDJSON / plain-text parser
│   └── store.dart            # atomic JSON persistence
├── state/app_state.dart      # conversations, streaming, settings, health
├── screens/
│   ├── chat_screen.dart
│   └── settings_screen.dart
└── widgets/                  # header, composer, bubbles, sheets…
```

No state-management package: `ChangeNotifier` + `ListenableBuilder` and one `InheritedWidget`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| **Offline / connection refused** | Is the server running? Does `curl http://127.0.0.1:8080/v1/models` work on the computer? |
| Emulator can't connect | Use `10.0.2.2`, not `127.0.0.1` |
| Phone can't connect on Wi‑Fi | Use the computer's LAN IP, bind the server to `0.0.0.0`, check the firewall |
| Phone over USB can't connect | Run `adb reverse tcp:8080 tcp:8080` |
| **HTTP 404** | The URL probably needs `/v1` at the end |
| Reply arrives all at once | Your server (or a proxy) is buffering. Disable response buffering; Clearport renders SSE deltas as they arrive |
| Status says **Server reachable** | The server answered, but `/models` is missing or unauthorized. Chat may still work |
| `flutter build apk` fails on licenses | Run `flutter doctor --android-licenses` |
| App can't reach `http://` | Cleartext HTTP is enabled in `AndroidManifest.xml` (`usesCleartextTraffic="true"`); keep it for local servers |

## Desktop (optional)

The Dart code has no Android-only dependencies. To add a desktop target:

```bash
flutter create . --platforms=macos,windows,linux
flutter run -d linux   # or macos / windows
```

Then use `http://127.0.0.1:8080/v1` directly.

## License

MIT — see [LICENSE](LICENSE).
