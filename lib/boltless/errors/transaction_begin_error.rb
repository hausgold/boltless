# frozen_string_literal: true

module Boltless
  module Errors
    # This exception is raised when we failed to start a new transaction
    # at the neo4j server.
    class TransactionBeginError < RequestError; end
  end
end
