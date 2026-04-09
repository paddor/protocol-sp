# frozen_string_literal: true

module Protocol
  module SP
    module Codec
      # SP/TCP frame encode/decode.
      #
      # Wire format (per nng `src/sp/transport/tcp/tcp.c`):
      #   8 bytes  body length, big-endian unsigned 64-bit
      #   N bytes  body
      #
      # SP messages are single-frame — there is no MORE flag and no
      # multipart concept at the transport level.
      #
      class Frame
        HEADER_SIZE = 8


        # @return [String] frame body (binary)
        attr_reader :body

        # @param body [String] frame body
        def initialize(body)
          @body = body.b
        end


        # Encodes to wire bytes.
        #
        # @return [String] binary wire representation (length + body)
        def to_wire
          [@body.bytesize].pack("Q>") + @body
        end


        # Encodes a body into wire bytes without allocating a Frame.
        #
        # @param body [String]
        # @return [String] frozen binary wire representation
        def self.encode(body)
          ([body.bytesize].pack("Q>") + body.b).freeze
        end


        # Reads one frame from an IO-like object.
        #
        # @param io [#read_exactly] must support read_exactly(n)
        # @param max_message_size [Integer, nil] maximum body size, nil = unlimited
        # @return [Frame]
        # @raise [Error] on oversized frame
        # @raise [EOFError] if the connection is closed
        def self.read_from(io, max_message_size: nil)
          size = io.read_exactly(HEADER_SIZE).unpack1("Q>")

          if max_message_size && size > max_message_size
            raise Error, "frame size #{size} exceeds max_message_size #{max_message_size}"
          end

          body = size > 0 ? io.read_exactly(size) : "".b
          new(body)
        end
      end
    end
  end
end
