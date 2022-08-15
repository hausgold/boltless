# frozen_string_literal: true

module Boltless
  module Errors
    # This exception is raised when we failed to rollback a transaction
    # at the neo4j server, or when another error caused a transaction rollback.
    class TransactionRollbackError < RequestError
      # We allow to read our details
      attr_reader :errors

      # Create a new generic response error instance.
      #
      # @param message [String] the error message
      # @param errors [Array<Errors::ResponseError>, Errors::ResponseError]
      #   a single/multiple response errors
      # @param response [HTTP::Response, nil] the HTTP response,
      #   or +nil+ when not available
      # @return [Errors::TransactionRollbackError] the new error instance
      def initialize(message, errors: [], response: nil)
        @errors = Array(errors)
        message += "\n\n#{@errors.map { |err| "* #{err.message}" }.join("\n")}"
        super(message, response: response)
      end
    end
  end
end
