# Clearport CLI for Termux

The Termux companion lives in its own repository:
[Adams-404/clearport-cli](https://github.com/Adams-404/clearport-cli). This page only
covers what you need to know from the app's side; the command reference, changelog and
installer live in that repo so the two copies cannot drift.

## Install

Inside Termux on the phone:

```bash
pkg install -y curl && curl -fsSL https://raw.githubusercontent.com/Adams-404/clearport-cli/main/install.sh | bash
```

The installer adds `clearport` and `clearport-server` to `$PREFIX/bin`. It does not
download model weights.

## Quick start

```bash
clearport pull gemma-tiny   # Gemma 3 270M, 292 MB, checksum-verified
clearport start             # llama-server on 127.0.0.1:8080
clearport chat              # terminal chat, no app needed
clearport haunt             # the model comments on your last commands
```

`clearport pull gemma` fetches the larger Gemma 3 1B build (806 MB) instead. Any GGUF
your `llama-server` can load also works: `clearport use ~/models/your-model.gguf`.

## Connect the app

Open Clearport, go to **Settings**, and leave the base URL at
`http://127.0.0.1:8080/v1`. The app and the CLI talk to the same local server, so a
conversation started in Termux and one started in the app use the same model and port.

If the status dot stays red, run `clearport status` in Termux: it reports whether the
server process is alive and whether the OpenAI-compatible API answers on `/v1/models`.

## Why the split

Both the app and the CLI used to ship a copy of `scripts/`. Two copies of a shell
launcher is one copy too many, and the app repo's copies went stale. The CLI repo is now
the single source, tested by its own CI (`bash -n`, ShellCheck, and a history-parsing
test for `haunt`).
