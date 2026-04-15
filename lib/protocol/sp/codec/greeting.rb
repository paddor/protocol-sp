# frozen_string_literal: true

module Protocol
  module SP
    module Codec
      # SP/TCP greeting encode/decode.
      #
      # The greeting is exactly 8 bytes (per nng `src/sp/transport/tcp/tcp.c`,
      # `tcptran_pipe_nego_cb` and `tcptran_pipe_send_start`):
      #
      #   Offset  Bytes  Field
      #   0       1      0x00
      #   1       1      'S' (0x53)
      #   2       1      'P' (0x50)
      #   3       1      0x00
      #   4-5     2      protocol id (u16, big-endian)
      #   6-7     2      reserved (must be 0x00 0x00)
      #
      module Greeting
        SIZE      = 8
        SIGNATURE = "\x00SP\x00".b.freeze


        # Encodes an SP/TCP greeting.
        #
        # @param protocol [Integer] our protocol id (e.g. Protocols::PUSH_V0)
        # @return [String] 8-byte binary greeting
        def self.encode(protocol:)
          SIGNATURE + [protocol].pack("n") + "\x00\x00".b
        end


        # Decodes an SP/TCP greeting.
        #
        # @param data [String] 8-byte binary greeting
        # @return [Integer] peer protocol id
        # @raise [Error] on invalid greeting
        def self.decode(data)
          raise Error, "greeting too short (#{data.bytesize} bytes)" if data.bytesize < SIZE

          data = data.b
          unless data.byteslice(0, 4) == SIGNATURE
            raise Error, "invalid SP greeting signature"
          end
          unless data.getbyte(6) == 0 && data.getbyte(7) == 0
            raise Error, "invalid SP greeting reserved bytes"
          end

          data.byteslice(4, 2).unpack1("n")
        end

      end
    end
  end
end
