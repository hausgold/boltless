# frozen_string_literal: true

module Boltless
  module Errors
    # This exception is raised whenever we were not able to produce or
    # consume JSON data.
    class InvalidJsonError < RequestError; end
  end
end
