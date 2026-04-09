# frozen_string_literal: true

require_relative "../../test_helper"
require "socket"
require "tempfile"

# Verifies that protocol-sp speaks the same wire format as libnng's
# `nngcat`. Skipped automatically if nngcat is not installed or fails to
# launch.
module Protocol
  module SP
    class NngcatInteropTest < Minitest::Test
      ENDPOINT = "tcp://127.0.0.1:5599"

      def setup
        skip "nngcat not installed" unless system("which nngcat >/dev/null 2>&1")
      end


      # protocol-sp PUSH (listening) ↔ nngcat --pull0 --dial
      def test_protocol_sp_push_to_nngcat_pull
        server = TCPServer.new("127.0.0.1", 5599)
        out    = Tempfile.new("nng-out")
        out.close

        nng_pid = spawn("nngcat", "--pull0", "--dial", ENDPOINT, "--count", "1", "--quoted",
                        out: out.path, err: File::NULL)

        client = server.accept
        server.close

        io   = IO::Stream::Buffered.new(client)
        push = Connection.new(io, protocol: Protocols::PUSH_V0)
        push.handshake!
        assert_equal Protocols::PULL_V0, push.peer_protocol

        push.send_message("hello from protocol-sp")
        push.close

        Process.wait(nng_pid)
        assert_match(/hello from protocol-sp/, File.read(out.path))
      ensure
        out&.unlink
        Process.kill("KILL", nng_pid) rescue nil
      end


      # nngcat --push0 --listen ↔ protocol-sp PULL (dialing)
      def test_nngcat_push_to_protocol_sp_pull
        nng_pid = spawn("nngcat", "--push0", "--listen", ENDPOINT,
                        "--data", "hello from nngcat", "--count", "1",
                        out: File::NULL, err: File::NULL)

        sock = nil
        10.times do
          sock = TCPSocket.new("127.0.0.1", 5599) rescue (sleep 0.05; nil)
          break if sock
        end
        flunk "could not connect to nngcat" unless sock

        io   = IO::Stream::Buffered.new(sock)
        pull = Connection.new(io, protocol: Protocols::PULL_V0)
        pull.handshake!
        assert_equal Protocols::PUSH_V0, pull.peer_protocol

        body = pull.receive_message
        assert_equal "hello from nngcat", body
      ensure
        Process.kill("TERM", nng_pid) rescue nil
        Process.wait(nng_pid) rescue nil
      end
    end
  end
end
