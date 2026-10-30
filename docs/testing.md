# Testing Clearport

Clearport's automated Flutter checks cover the app's core logic and the local
HTTP integration path. Run the full suite with:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Automated coverage

- App startup and chat-screen rendering are covered by widget tests.
- Settings serialization tests verify that connection and generation
  preferences can be restored from persisted JSON.
- Local-server integration tests bind a controllable HTTP server to loopback,
  exercise model discovery, send a chat-completion request, and verify the
  streamed response and request payload.
- Android manifest and network-security configuration tests verify that
  cleartext HTTP is permitted for `127.0.0.1` and `localhost`, while the
  base configuration denies cleartext traffic for other hosts.

## Manual Android and Termux validation

Automated host-side tests do not run the Android app inside a device emulator
or prove that a separate Termux process remains alive. Before a release, install
the APK on a physical Android device and:

1. Start `llama-server` in Termux on `127.0.0.1:8080`.
2. Confirm Clearport can discover the loaded model.
3. Send a prompt and verify that streamed output appears.
4. Background and resume Clearport during a response, then confirm the saved
   conversation remains usable.
5. Confirm that a non-loopback plain-HTTP endpoint is rejected by Android's
   network security policy; use HTTPS for remote servers.

These device checks remain necessary because host-side tests cannot reproduce
Android process management, device-specific networking, or Termux lifecycle
behaviour.
