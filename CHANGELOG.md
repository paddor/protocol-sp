# Changelog

## 0.1.0 — 2026-04-09

Initial release.

- `Protocol::SP::Codec::Frame` — length-prefixed framing. SP/TCP uses an 8-byte big-endian length; SP/IPC prepends a 1-byte message type to match nng's wire format.
- `Protocol::SP::Codec::Greeting` — 8-byte SP/TCP greeting.
- `Protocol::SP::Protocols` — protocol identifier constants.
- `Protocol::SP::Connection` — mutex-protected handshake, `#send_message`, `#write_message`, `#write_messages` (batched), `#receive_message`. `framing:` selects `:tcp` or `:ipc`.
