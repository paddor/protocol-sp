# frozen_string_literal: true

require_relative "../../test_helper"
require "socket"

module Protocol
  module SP
    class ConnectionTest < Minitest::Test
      # Returns a pair of buffered IO::Stream wrappers around a socketpair.
      def stream_pair
        a, b = UNIXSocket.pair
        [IO::Stream::Buffered.new(a), IO::Stream::Buffered.new(b)]
      end


      def test_handshake_push_pull
        a, b   = stream_pair
        push   = Connection.new(a, protocol: Protocols::PUSH_V0)
        pull   = Connection.new(b, protocol: Protocols::PULL_V0)

        t = Thread.new { pull.handshake! }
        push.handshake!
        t.join

        assert_equal Protocols::PULL_V0, push.peer_protocol
        assert_equal Protocols::PUSH_V0, pull.peer_protocol
      end


      def test_handshake_incompatible
        a, b   = stream_pair
        push   = Connection.new(a, protocol: Protocols::PUSH_V0)
        pub    = Connection.new(b, protocol: Protocols::PUB_V0)

        t = Thread.new do
          pub.handshake!
        rescue Error
          # expected on at least one side
        end
        assert_raises(Error) { push.handshake! }
        t.join
      end


      def test_send_receive_round_trip
        a, b   = stream_pair
        push   = Connection.new(a, protocol: Protocols::PUSH_V0)
        pull   = Connection.new(b, protocol: Protocols::PULL_V0)

        t = Thread.new { pull.handshake! }
        push.handshake!
        t.join

        push.send_message("hello")
        push.send_message("world")

        assert_equal "hello", pull.receive_message
        assert_equal "world", pull.receive_message
      end


      def test_max_message_size_enforced
        a, b   = stream_pair
        push   = Connection.new(a, protocol: Protocols::PUSH_V0)
        pull   = Connection.new(b, protocol: Protocols::PULL_V0, max_message_size: 4)

        t = Thread.new { pull.handshake! }
        push.handshake!
        t.join

        push.send_message("toolong")
        assert_raises(Error) { pull.receive_message }
      end
    end
  end
end
