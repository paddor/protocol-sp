# frozen_string_literal: true

module Protocol
  module SP
    # Wire-level protocol identifiers (16-bit, big-endian on the wire).
    #
    # Encoding: `(major << 4) | minor`, matching nng's `NNI_PROTO(major,
    # minor)` macro in `src/core/protocol.h`. Sourced from
    # `src/sp/protocol/*/`.
    #
    module Protocols
      PAIR_V0    = 0x10  # (1, 0)
      PAIR_V1    = 0x11  # (1, 1)

      PUB_V0     = 0x20  # (2, 0)
      SUB_V0     = 0x21  # (2, 1)

      REQ_V0     = 0x30  # (3, 0)
      REP_V0     = 0x31  # (3, 1)

      PUSH_V0    = 0x50  # (5, 0)
      PULL_V0    = 0x51  # (5, 1)

      SURVEYOR_V0   = 0x62 # (6, 2)
      RESPONDENT_V0 = 0x63 # (6, 3)

      BUS_V0     = 0x70  # (7, 0)


      # Compatibility table: which peer ID is acceptable for each self ID.
      VALID_PEERS = {
        PAIR_V0       => [PAIR_V0],
        PAIR_V1       => [PAIR_V1],
        PUB_V0        => [SUB_V0],
        SUB_V0        => [PUB_V0],
        REQ_V0        => [REP_V0],
        REP_V0        => [REQ_V0],
        PUSH_V0       => [PULL_V0],
        PULL_V0       => [PUSH_V0],
        SURVEYOR_V0   => [RESPONDENT_V0],
        RESPONDENT_V0 => [SURVEYOR_V0],
        BUS_V0        => [BUS_V0],
      }.freeze


      NAMES = {
        PAIR_V0       => "pair",
        PAIR_V1       => "pair1",
        PUB_V0        => "pub",
        SUB_V0        => "sub",
        REQ_V0        => "req",
        REP_V0        => "rep",
        PUSH_V0       => "push",
        PULL_V0       => "pull",
        SURVEYOR_V0   => "surveyor",
        RESPONDENT_V0 => "respondent",
        BUS_V0        => "bus",
      }.freeze
    end
  end
end
