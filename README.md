# protocol-sp

Pure Ruby codec and connection for the Scalability Protocols (SP) wire
format used by nanomsg and nng. Sister gem to
[protocol-zmtp](https://github.com/paddor/protocol-zmtp).

## What's in the box

- `Protocol::SP::Codec::Frame` — 8-byte big-endian length-prefixed framing
  (per `nng` `src/sp/transport/tcp/tcp.c`).
- `Protocol::SP::Codec::Greeting` — 8-byte handshake:
  `00 'S' 'P' 00 <peer-proto:u16-BE> 00 00`.
- `Protocol::SP::Protocols` — protocol identifier constants
  (PUSH=0x50, PULL=0x51, PUB=0x20, SUB=0x21, REQ=0x30, REP=0x31,
   PAIR_V0=0x10, PAIR_V1=0x11, BUS=0x70, SURVEYOR=0x62, RESPONDENT=0x63).
- `Protocol::SP::Connection` — mutex-protected `#handshake!`,
  `#send_message`, `#receive_message` over any IO-like object.

## Notes

- SP messages are single-frame (no multipart, unlike ZMTP).
- No security mechanisms in the SP wire protocol — encryption is layered
  via TLS/WebSocket transports, not the SP framing.
- No commands at the wire level — protocol-specific control bytes (e.g.
  REQ request IDs, SUB topics) live inside the message body.
