# Changelog

## Unreleased

- Cancellation-safe wire writes: `send_message`, `write_message`,
  `write_messages`, and `write_wire` now wrap their mutex blocks in
  `Async::Task#defer_cancel`. Prevents frame header/body desync when
  `Async::Cancel` arrives between the header write and the body write
  (e.g. from a barrier cascade teardown).
- GC micro-optimizations: `EMPTY_BODY` frozen constant replaces per-call
  `"".b` in `Frame.read_from` and IPC receive; skip `.b` when body is
  already `Encoding::BINARY` in `Frame#initialize` and `Frame.encode`;
  use `<<` instead of `+` in `Frame#to_wire` and `Frame.encode`.

## 0.1.1 — 2026-04-09

- `Protocol::SP::Protocols::VALID_PEERS` is now deep-frozen (each inner
  peer list is individually `.freeze`'d, matching how protocol-zmtp
  handles `VALID_PEERS`). This makes the constant Ractor-shareable so
  NNQ sockets can complete handshakes inside non-main Ractors.

## 0.1.0 — 2026-04-09

Initial release.

- `Protocol::SP::Codec::Frame` — length-prefixed framing. SP/TCP uses an 8-byte big-endian length; SP/IPC prepends a 1-byte message type to match nng's wire format.
- `Protocol::SP::Codec::Greeting` — 8-byte SP/TCP greeting.
- `Protocol::SP::Protocols` — protocol identifier constants.
- `Protocol::SP::Connection` — mutex-protected handshake, `#send_message`, `#write_message`, `#write_messages` (batched), `#receive_message`. `framing:` selects `:tcp` or `:ipc`.
