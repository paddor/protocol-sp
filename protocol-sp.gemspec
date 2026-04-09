# frozen_string_literal: true

require_relative "lib/protocol/sp/version"

Gem::Specification.new do |s|
  s.name     = "protocol-sp"
  s.version  = Protocol::SP::VERSION
  s.authors  = ["Patrik Wenger"]
  s.email    = ["paddor@gmail.com"]
  s.summary  = "Scalability Protocols (nanomsg/nng) wire codec and connection"
  s.description = "Pure Ruby implementation of the Scalability Protocols " \
                  "wire format used by nanomsg and nng. Includes the SP/TCP " \
                  "framing codec, 8-byte greeting, protocol identifiers, and " \
                  "connection management. No runtime dependencies."
  s.homepage = "https://github.com/paddor/protocol-sp"
  s.license  = "ISC"

  s.required_ruby_version = ">= 3.3"

  s.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
end
