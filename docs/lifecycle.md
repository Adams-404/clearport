# What happens when Clearport is backgrounded

A long generation can outlive the screen. This page is the contract, so nobody has to
guess what the app does when Android takes it away.

## While the app is in the foreground

The reply is read as a server-sent event stream. Tokens are buffered in memory and
flushed to the conversation file at most every 45 ms, so a long answer is already on
disk before it finishes.

## When the app goes to the background

Android walks the app through `inactive` → `hidden` → `paused`. On `paused`, Clearport
does exactly two things:

1. Flushes any buffered tokens into the conversation file.
2. Persists the conversation immediately instead of waiting for the usual debounce.

The request is **not** cancelled. If Android keeps the process alive, tokens keep
arriving and keep being written. Backgrounding the app for a notification does not
throw away the answer.

## When Android kills the process

There is no background service and no foreground notification, so a low-memory kill is
always possible. On the next launch Clearport:

- keeps any partial assistant answer that was already written to disk,
- removes assistant messages that are still empty (an interrupted request leaves a
  placeholder behind, and an empty bubble is worse than no bubble),
- starts with `isStreaming == false`, so the UI can never show a "streaming" state for
  a request that no longer exists.

There is no automatic resume: the model has forgotten the request, so the honest thing
is to send again. The partial answer stays in the transcript, so nothing is lost.

## What the app does not promise

Clearport does not keep `llama-server` alive. The server runs in Termux, outside the
app's process, and Android may suspend or kill Termux at any time regardless of what the
app is doing. Termux's wake lock and Android's battery settings reduce the chance, and
`clearport status` tells you whether the server is still answering — but the app cannot
guarantee it, and does not claim to.

If the server disappears mid-answer, the stream ends and the partial text is kept; the
next request surfaces the connection error in the transcript.

## Covered by tests

`test/lifecycle_test.dart` checks the three claims above: a pause writes the tokens
received so far, a restart keeps a partial answer, and a restart drops empty
placeholders and never restores a streaming state.
