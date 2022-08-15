# frozen_string_literal: true

module Boltless
  module Errors
    # This exception is raised when there is no open transaction at the neo4j
    # server with the given identifier. The neo4j server closes an
    # idling/inactive transaction after 60 seconds by default (after the last
    # interaction). This value can be configured at the neo4j server.
    class TransactionNotFoundError < RequestError; end
  end
end
