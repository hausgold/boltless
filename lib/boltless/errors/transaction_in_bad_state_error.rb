# frozen_string_literal: true

module Boltless
  module Errors
    # This exception is raised when a transaction is going to be used, but is
    # not usable in its current state. This may happen when a not-yet-started
    # transaction should send a query, or when an already rolled back
    # transaction should be used, etc.
    class TransactionInBadStateError < RequestError; end
  end
end
