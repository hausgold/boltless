# frozen_string_literal: true

module Boltless
  module Errors
    # A generic request error wrapper, from the low-level http.rb gem
    class RequestError < StandardError
      # We allow to read our details
      attr_accessor :message
      attr_reader :response

      # Create a new generic request error instance.
      #
      # @param message [String] the error message
      # @param response [HTTP::Response, nil] the HTTP response,
      #   or +nil+ when not available
      # @return [Errors::RequestError] the new error instance
      def initialize(message, response: nil)
        super(message)
        @message = message
        @response = response
      end
    end
  end
end
