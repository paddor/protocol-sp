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
      # SP/IPC data messages are prefixed with a 1-byte message type.
      # 0x01 = user message. 0x00 is reserved in nng for control frames
      # (keepalive) that we don't emit, but we still accept and skip on
      # read for forward-compatibility with nng peers.
      IPC_MSG_TYPE = 0x01


      # @return [Integer] peer's protocol id (set after handshake)
      attr_reader :peer_protocol

      # @return [Object] transport IO (#read_exactly, #write, #flush, #close)
      attr_reader :io

      # @return [Float, nil] monotonic timestamp of last received frame
      attr_reader :last_received_at

      # @return [Symbol] :tcp or :ipc
      attr_reader :framing

      # @param io [#read_exactly, #write, #flush, #close] transport IO
      # @param protocol [Integer] our protocol id (e.g. Protocols::PUSH_V0)
      # @param max_message_size [Integer, nil] max body size, nil = unlimited
      # @param framing [Symbol] :tcp (default) uses 8-byte length headers;
      #   :ipc prepends a 1-byte message-type marker to each frame
      #   (nng's SP/IPC wire format)
      def initialize(io, protocol:, max_message_size: nil, framing: :tcp)
        @io               = io
        @protocol         = protocol
        @peer_protocol    = nil
        @max_message_size = max_message_size
        @framing          = framing
        @mutex            = Mutex.new
        @last_received_at = nil
        # Reusable scratch buffer for frame headers — written into by
        # Array#pack(buffer:), then flushed to @io. Capacity 9 covers
        # both :tcp (8B) and :ipc (1+8B) framings.
        @header_buf = String.new(capacity: 9, encoding: Encoding::BINARY)
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
        with_deferred_cancel do
          @mutex.synchronize do
            write_header_nolock(body.bytesize)
            @io.write(body)
            @io.flush
          end
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
        with_deferred_cancel do
          @mutex.synchronize do
            write_header_nolock(body.bytesize)
            @io.write(body)
          end
        end
      end


      # Writes a batch of messages to the buffer under a single mutex
      # acquisition. Used by work-stealing send pumps that dequeue up
      # to N messages at once — avoids N lock/unlock pairs per batch.
      # Call {#flush} after to push the buffer to the socket.
      #
      # @param bodies [Array<String>]
      # @return [void]
      def write_messages(bodies)
        with_deferred_cancel do
          @mutex.synchronize do
            i = 0
            n = bodies.size
            while i < n
              body = bodies[i]
              write_header_nolock(body.bytesize)
              @io.write(body)
              i += 1
            end
          end
        end
      end


      # Writes the frame header into the already-held @mutex. Hotpath:
      # keep the branch monomorphic per-connection and avoid fresh pack
      # allocations by packing into a per-connection scratch buffer.
      #
      # @param size [Integer] body size
      # @return [void]
      private def write_header_nolock(size)
        buf = @header_buf
        buf.clear
        if @framing == :ipc
          [IPC_MSG_TYPE, size].pack("CQ>", buffer: buf)
        else
          [size].pack("Q>", buffer: buf)
        end
        @io.write(buf)
      end


      # Writes pre-encoded wire bytes without flushing. Used for fan-out:
      # encode once with `Codec::Frame.encode`, write to many connections.
      #
      # @param wire_bytes [String]
      # @return [void]
      def write_wire(wire_bytes)
        with_deferred_cancel do
          @mutex.synchronize do
            @io.write(wire_bytes)
          end
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
        if @framing == :ipc
          loop do
            # One read_exactly(9) is cheaper than separate 1+8 reads:
            # halves the io-stream dispatch overhead per message.
            header     = @io.read_exactly(9)
            type, size = header.unpack("CQ>")
            if @max_message_size && size > @max_message_size
              raise Error, "frame size #{size} exceeds max_message_size #{@max_message_size}"
            end
            body = size > 0 ? @io.read_exactly(size) : Codec::Frame::EMPTY_BODY
            touch_heartbeat
            # Skip nng IPC control frames (0x00 — keepalive/etc.); only
            # deliver user messages (0x01) to the caller.
            return body if type == IPC_MSG_TYPE
          end
        else
          frame = Codec::Frame.read_from(@io, max_message_size: @max_message_size)
          touch_heartbeat
          frame.body
        end
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


      private

      # Defers task cancellation around a block of wire writes so the
      # peer never sees a half-written frame. Without this, an
      # +Async::Cancel+ arriving between the header write and the body
      # write would desync the peer's framer unrecoverably.
      #
      # When called outside an Async task (test fixtures, blocking
      # callers), the block runs directly — there is no task to defer on.
      def with_deferred_cancel
        if defined?(Async::Task) && (task = Async::Task.current?)
          task.defer_cancel { yield }
        else
          yield
        end
      end
    end
  end
end
