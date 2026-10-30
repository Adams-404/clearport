# Clearport CLI for Termux

Clearport CLI is a small Termux companion for running a local llama.cpp model and chatting with it directly in the terminal. The Android Clearport app is optional: the same local API can serve the app, but you can use clearport chat without opening it.

## Install

Run this single command inside Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/Adams-404/clearport/main/scripts/install-termux.sh | bash
```

The installer installs the Termux packages needed by the CLI, including llama-cpp, curl, and jq. It downloads the CLI and its server helper into $PREFIX/bin.

No model is downloaded. GGUF models can be several gigabytes, so choose and download one separately.

## First run

Put your GGUF model in ~/models. Then:

```bash
clearport local-models
clearport use ~/models/your-model.gguf
clearport start
clearport chat
```

If you have exactly one GGUF model in ~/models and no model has been configured, clearport start automatically selects it. If you have multiple models, choose one explicitly with clearport use.

## Commands

| Command | What it does |
| --- | --- |
| clearport start | Acquires a Termux wake lock when available and starts llama-server in the background |
| clearport chat | Starts the server if needed, then opens an interactive terminal chat |
| clearport models | Lists models currently loaded by the local API |
| clearport local-models | Lists local *.gguf files in ~/models |
| clearport use <path> | Selects the GGUF model to load |
| clearport status | Checks the server process and API |
| clearport logs | Follows the server log; Ctrl-C exits the log view |
| clearport stop | Stops the managed server and releases the wake lock |
| clearport restart | Stops and starts the server with the current configuration |
| clearport config | Opens the server configuration in your editor |

Inside terminal chat, type /clear to clear conversation context or /exit to leave.

## Defaults and configuration

- API: http://127.0.0.1:8080/v1
- Bind address: 127.0.0.1 (loopback only)
- Model directory: ~/models
- Config: ~/.config/clearport/server.conf
- State and logs: ~/.local/state/clearport/

The configuration is shell-style. Example:

```sh
MODEL_PATH="$HOME/models/qwen2.5-1.5b-instruct-q4_k_m.gguf"
LLAMA_SERVER_BIN="llama-server"
HOST="127.0.0.1"
PORT="8080"
EXTRA_ARGS="-c 2048 -t 4"
```

Use clearport config to edit it. clearport use changes only MODEL_PATH and preserves other settings.

## Use it with the Android app

The server runs independently of the app. If you want the Clearport Android interface, set its Server URL to:

```text
http://127.0.0.1:8080/v1
```

You can use clearport chat and the Android app against the same server, but avoid simultaneous long generations on a phone with limited RAM.

## Android background behaviour

Before a long session, clearport start requests termux-wake-lock automatically. Termux still needs permission to run in the background. On some itel devices, the separate Foreground Intelligence control under Special Functions → AI → Intelligent Management can suspend Termux even when ordinary battery settings look unrestricted. Disable that restriction if you experience the same issue. Keep Android's Battery Saver off during long model sessions.

A wake lock cannot override every OEM process-management feature. If the server stops responding, check the device's background-management settings and inspect clearport logs.

## Notes

- The CLI manages llama-server; it does not download model weights. The installer installs the llama-cpp package if available in your Termux repository.
- The API binds to 127.0.0.1 by default, so it is not exposed to your Wi-Fi network.
- The interactive chat uses non-streaming OpenAI-compatible chat completions. Long generations may take time on mobile hardware.
- clearport stop only stops a server started and tracked by the Clearport helper. If another process already owns port 8080, stop that process separately before using the managed start/stop lifecycle.
- MIT License. See the repository LICENSE.
