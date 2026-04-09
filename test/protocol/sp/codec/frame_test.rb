# frozen_string_literal: true

require_relative "../../../test_helper"

module Protocol
  module SP
    module Codec
      class FrameTest < Minitest::Test
        def test_encode_round_trip
          wire = Frame.new("hello").to_wire
          assert_equal "\x00\x00\x00\x00\x00\x00\x00\x05hello".b, wire
        end


        def test_encode_class_method_freezes
          wire = Frame.encode("x")
          assert wire.frozen?
          assert_equal 9, wire.bytesize
        end


        def test_read_from_io_stream
          io  = IO::Stream::Buffered.new(StringIO.new("\x00\x00\x00\x00\x00\x00\x00\x03foo".b))
          frame = Frame.read_from(io)
          assert_equal "foo", frame.body
        end


        def test_read_from_empty_body
          io  = IO::Stream::Buffered.new(StringIO.new("\x00" * 8))
          frame = Frame.read_from(io)
          assert_equal "", frame.body
        end


        def test_max_message_size_enforced
          io = IO::Stream::Buffered.new(StringIO.new("\x00\x00\x00\x00\x00\x00\x00\x05hello".b))
          assert_raises(Error) { Frame.read_from(io, max_message_size: 4) }
        end


        def test_large_body
          body = "x" * 1024
          wire = Frame.encode(body)
          io   = IO::Stream::Buffered.new(StringIO.new(wire.dup))
          assert_equal body, Frame.read_from(io).body
        end
      end
    end
  end
end
