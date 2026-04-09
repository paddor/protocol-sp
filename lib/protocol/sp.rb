# frozen_string_literal: true

module Protocol
  # Scalability Protocols (nanomsg/nng) wire codec and connection.
  module SP
  end
end

require_relative "sp/version"
require_relative "sp/error"
require_relative "sp/protocols"
require_relative "sp/codec"
require_relative "sp/connection"
