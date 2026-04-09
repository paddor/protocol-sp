# protocol-sp

[![CI](https://github.com/paddor/protocol-sp/actions/workflows/ci.yml/badge.svg)](https://github.com/paddor/protocol-sp/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/protocol-sp?color=e9573f)](https://rubygems.org/gems/protocol-sp)
[![License: ISC](https://img.shields.io/badge/License-ISC-blue.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.3-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org)

Pure Ruby codec and connection for the [Scalability Protocols](https://nanomsg.org/documentation-zeromq.html) (SP) wire format used by [nanomsg](https://nanomsg.org) and [nng](https://nng.nanomsg.org). Zero runtime dependencies. Sister gem to [protocol-zmtp](https://github.com/paddor/protocol-zmtp).

## What's in the box

- `Protocol::SP::Codec::Frame` — length-prefixed framing. SP/TCP uses an 8-byte big-endian length; SP/IPC prepends a 1-byte message type (0x00 control, 0x01 user) to match nng's wire format.
- `Protocol::SP::Codec::Greeting` — 8-byte handshake: `00 'S' 'P' 00 <peer-proto:u16-BE> 00 00`.
- `Protocol::SP::Protocols` — protocol identifier constants (PUSH=0x50, PULL=0x51, PUB=0x20, SUB=0x21, REQ=0x30, REP=0x31, PAIR_V0=0x10, PAIR_V1=0x11, BUS=0x70, SURVEYOR=0x62, RESPONDENT=0x63).
- `Protocol::SP::Connection` — mutex-protected `#handshake!`, `#send_message`, `#write_message` (no flush), `#write_messages` (batched under a single mutex acquisition), `#receive_message` over any IO-like object. `framing:` selects `:tcp` or `:ipc`.

## Notes

- SP messages are single-frame (no multipart, unlike ZMTP).
- No security mechanisms in the SP wire protocol — encryption is layered via TLS/WebSocket transports, not the SP framing.
- No commands at the wire level — protocol-specific control bytes (e.g. REQ request IDs, SUB topics) live inside the message body.
- Zero-alloc frame headers on the unencrypted hot send path via `Array#pack(buffer:)`.

## Usage

`protocol-sp` is a low-level codec. For a full socket API (PUSH/PULL, REQ/REP, PAIR, transports, reconnect), see [nnq](https://github.com/paddor/nnq).
