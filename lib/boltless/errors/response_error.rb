# frozen_string_literal: true

module Boltless
  module Errors
    # A generic response error, for everything neo4j want to tell us
    class ResponseError < StandardError
      # We allow to read our details
      attr_accessor :message
      attr_reader :code, :response

      # Create a new generic response error instance.
      #
      # @param message [String] the error message
      # @param code [String, nil] the neo4j error code,
      #   or +nil+ when not available
      # @param response [HTTP::Response, nil] the HTTP response,
      #   or +nil+ when not available
      # @return [Errors::RequestError] the new error instance
      def initialize(message, code: nil, response: nil)
        formatted = "#{message} (#{code})" if message && code
        formatted = code unless message
        formatted ||= message
        super(formatted)
        @message = formatted
        @code = code
        @response = response
      end
    end
  end
end
