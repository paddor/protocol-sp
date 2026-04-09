# frozen_string_literal: true

require_relative "../../../test_helper"

module Protocol
  module SP
    module Codec
      class GreetingTest < Minitest::Test
        def test_encode_push
          bytes = Greeting.encode(protocol: Protocols::PUSH_V0)
          assert_equal "\x00SP\x00\x00\x50\x00\x00".b, bytes
          assert_equal 8, bytes.bytesize
        end


        def test_encode_pull
          bytes = Greeting.encode(protocol: Protocols::PULL_V0)
          assert_equal "\x00SP\x00\x00\x51\x00\x00".b, bytes
        end


        def test_round_trip
          Protocols::NAMES.each_key do |id|
            assert_equal id, Greeting.decode(Greeting.encode(protocol: id))
          end
        end


        def test_decode_invalid_signature
          assert_raises(Error) { Greeting.decode("XXXX\x00\x50\x00\x00".b) }
        end


        def test_decode_nonzero_reserved
          assert_raises(Error) { Greeting.decode("\x00SP\x00\x00\x50\x01\x00".b) }
        end


        def test_decode_short
          assert_raises(Error) { Greeting.decode("\x00SP".b) }
        end
      end
    end
  end
end
