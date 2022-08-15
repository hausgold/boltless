# frozen_string_literal: true

module Boltless
  module Extensions
    # A top-level gem-module extension to handle configuration needs.
    module ConfigurationHandling
      extend ActiveSupport::Concern

      class_methods do
        # Retrieve the current configuration object.
        #
        # @return [Configuration] the current configuration object
        def configuration
          @configuration ||= Configuration.new
        end

        # Configure the concern by providing a block which takes
        # care of this task. Example:
        #
        #   Boltless.configure do |conf|
        #     # conf.xyz = [..]
        #   end
        def configure
          yield(configuration)
        end

        # Reset the current configuration with the default one.
        def reset_configuration!
          @configuration = Configuration.new
        end

        # A shortcut to the configured logger.
        delegate :logger, to: :configuration
      end
    end
  end
end
