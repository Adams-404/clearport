# Termux companion: llama.cpp server

> **Recommended setup:** use the Clearport CLI for one-command installation, server management, and direct terminal chat. See [Termux CLI](termux-cli.md). Install it with `curl -fsSL https://raw.githubusercontent.com/Adams-404/clearport-cli/main/install.sh | bash`. This page documents the lower-level `clearport-server` helper for existing/manual setups.

Clearport is the chat client; this optional helper starts a separate `llama-server` process in Termux. It does not install llama.cpp, download a model, or run anything inside the Flutter app.

## 1. Install prerequisites

In Termux:

```sh
pkg update
pkg install curl procps
```

Install a Termux-compatible llama.cpp build that provides the `llama-server` executable. Confirm it is on your PATH:

```sh
command -v llama-server
llama-server --version
```

The exact installation method depends on the llama.cpp build you use. Do not download random prebuilt binaries; use a build you trust and that matches your device architecture.

## 2. Install the launcher

Clone the CLI repository (which ships the launcher) and copy it into Termux's executable directory:

```sh
git clone https://github.com/Adams-404/clearport-cli.git
cd clearport-cli
mkdir -p "$PREFIX/bin"
cp scripts/clearport-server "$PREFIX/bin/clearport-server"
chmod 700 "$PREFIX/bin/clearport-server"
```

If you already have a local clone, pull the latest `main` first. The script can also be run directly with `bash scripts/clearport-server`.

## 3. Configure your GGUF model

Create the configuration directory and file:

```sh
mkdir -p "$HOME/.config/clearport"
nano "$HOME/.config/clearport/server.conf"
```

Example configuration (change the model path to the GGUF file you actually have):

```sh
MODEL_PATH="$HOME/models/your-model.gguf"
LLAMA_SERVER_BIN="llama-server"
HOST="127.0.0.1"
PORT="8080"
EXTRA_ARGS="--ctx-size 4096"
```

Save the file and restrict its permissions:

```sh
chmod 600 "$HOME/.config/clearport/server.conf"
```

The default model path is `$HOME/models/model.gguf`. The default bind address is `127.0.0.1`, so the server is reachable only from the same phone. Keep that default for Clearport's same-device setup. Changing `HOST` to `0.0.0.0` can expose the model API to your local network; do so only when you intentionally need LAN access and understand the security implications.

Supported settings:

| Setting | Default | Purpose |
| --- | --- | --- |
| `MODEL_PATH` | `$HOME/models/model.gguf` | Path to the GGUF model |
| `LLAMA_SERVER_BIN` | `llama-server` | Executable name or path |
| `HOST` | `127.0.0.1` | Listen address |
| `PORT` | `8080` | Listen port |
| `EXTRA_ARGS` | empty | Additional llama-server flags |

## 4. Start and manage the server

```sh
clearport-server start
clearport-server status
clearport-server logs
clearport-server stop
```

The launcher writes its PID and log under `$HOME/.local/state/clearport/` (or `$XDG_STATE_HOME/clearport/` when configured). The log is `llama-server.log`. The `logs` command follows the latest output; press Ctrl-C to leave the log view without stopping the server.

The launcher checks for an existing managed process before starting, removes stale PID files, validates the model path and port, and checks whether the selected port is already responding. It sends a normal termination signal first and force-stops the process only if it does not exit within ten seconds.

If startup fails, inspect the log:

```sh
clearport-server logs
```

## 5. Connect Clearport

In Clearport → Settings, set the Server URL to:

```
http://127.0.0.1:8080/v1
```

Set the Model field if your server requires a model ID, then use Test. The launcher does not change Clearport settings.

## 6. Keep Android from suspending Termux

Before starting a long generation session, run:

```sh
termux-wake-lock
clearport-server start
```

Release the wake lock when you no longer need it:

```sh
termux-wake-unlock
```

Also set Termux's Android battery usage to Unrestricted (Settings → Apps → Termux → Battery, wording varies by Android version and device). Some manufacturers apply additional background-process restrictions. These settings reduce the chance of Termux being suspended, but Android may still terminate background processes; this helper cannot guarantee that the server remains alive after the OS kills Termux.

## Troubleshooting

- **llama-server not found:** install a compatible llama.cpp build or set `LLAMA_SERVER_BIN` to its full executable path.
- **Model file not found:** correct `MODEL_PATH`; it must point to a readable GGUF file.
- **Port already responding:** stop the other service or choose another `PORT` and update Clearport's Server URL to match.
- **Server exits during startup:** run `clearport-server logs` and check the llama.cpp error output.
- **Status says not running after Android killed Termux:** start it again; the launcher removes the stale PID file.
