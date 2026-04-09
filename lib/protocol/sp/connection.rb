# frozen_string_literal: true

module Protocol
  module SP
    # Manages one SP peer connection over any transport IO.
    #
    # The SP wire protocol has no commands, no security mechanisms, and no
    # multipart messages — `#handshake!` is just an exchange of two 8-byte
    # greetings, and `#send_message` / `#receive_message` work on single
    # binary bodies framed by an 8-byte big-endian length.
    #
    class Connection
      # @return [Integer] peer's protocol id (set after handshake)
      attr_reader :peer_protocol

      # @return [Object] transport IO (#read_exactly, #write, #flush, #close)
      attr_reader :io

      # @return [Float, nil] monotonic timestamp of last received frame
      attr_reader :last_received_at

      # @param io [#read_exactly, #write, #flush, #close] transport IO
      # @param protocol [Integer] our protocol id (e.g. Protocols::PUSH_V0)
      # @param max_message_size [Integer, nil] max body size, nil = unlimited
      def initialize(io, protocol:, max_message_size: nil)
        @io               = io
        @protocol         = protocol
        @peer_protocol    = nil
        @max_message_size = max_message_size
        @mutex            = Mutex.new
        @last_received_at = nil
      end


      # Performs the SP/TCP greeting exchange.
      #
      # @return [void]
      # @raise [Error] on greeting mismatch or peer-incompatibility
      def handshake!
        @io.write(Codec::Greeting.encode(protocol: @protocol))
        @io.flush

        peer = Codec::Greeting.decode(@io.read_exactly(Codec::Greeting::SIZE))
        @peer_protocol = peer

        valid = Protocols::VALID_PEERS[@protocol]
        unless valid&.include?(peer)
          raise Error, "incompatible SP protocols: 0x#{@protocol.to_s(16)} cannot speak to 0x#{peer.to_s(16)}"
        end
      end


      # Sends one message (write + flush).
      #
      # @param body [String] message body (single frame)
      # @return [void]
      def send_message(body)
        @mutex.synchronize do
          @io.write([body.bytesize].pack("Q>"))
          @io.write(body)
          @io.flush
        end
      end


      # Writes one message to the buffer without flushing.
      # Call {#flush} after batching writes.
      #
      # Two writes — header then body — into the buffered IO; avoids
      # the per-message intermediate String allocation that
      # {Codec::Frame.encode} would otherwise produce.
      #
      # @param body [String]
      # @return [void]
      def write_message(body)
        @mutex.synchronize do
          @io.write([body.bytesize].pack("Q>"))
          @io.write(body)
        end
      end


      # Writes pre-encoded wire bytes without flushing. Used for fan-out:
      # encode once with `Codec::Frame.encode`, write to many connections.
      #
      # @param wire_bytes [String]
      # @return [void]
      def write_wire(wire_bytes)
        @mutex.synchronize do
          @io.write(wire_bytes)
        end
      end


      # Flushes the write buffer to the underlying IO.
      #
      # @return [void]
      def flush
        @mutex.synchronize do
          @io.flush
        end
      end


      # Receives one message body.
      #
      # @return [String] binary body (NOT frozen — let callers freeze if
      #   they want, the freeze cost shows up in hot loops)
      # @raise [EOFError] if connection is closed
      def receive_message
        frame = Codec::Frame.read_from(@io, max_message_size: @max_message_size)
        touch_heartbeat
        frame.body
      rescue Error
        close
        raise
      end


      # Records that a frame was received (for inactivity tracking).
      #
      # @return [void]
      def touch_heartbeat
        @last_received_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end


      # Returns true if no frame has been received within +timeout+ seconds.
      #
      # @param timeout [Numeric] seconds
      # @return [Boolean]
      def heartbeat_expired?(timeout)
        return false unless @last_received_at
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_received_at) > timeout
      end


      # Closes the connection.
      #
      # @return [void]
      def close
        @io.close
      rescue IOError
        # already closed
      end
    end
  end
end
