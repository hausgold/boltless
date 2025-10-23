# frozen_string_literal: true

require 'zeitwerk'
require 'base64'
require 'http'
require 'connection_pool'
require 'oj'
require 'fast_jsonparser'
require 'colorize'
require 'logger'
require 'active_support'
require 'active_support/concern'
require 'active_support/ordered_options'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/enumerable'
require 'pp'

# The gem root namespace. Everything is bundled here.
module Boltless
  # Setup a Zeitwerk autoloader instance and configure it
  loader = Zeitwerk::Loader.for_gem

  # Finish the auto loader configuration
  loader.setup

  # Load standalone code
  require 'boltless/version'

  # Include top-level features
  include Extensions::ConfigurationHandling
  include Extensions::ConnectionPool
  include Extensions::Transactions
  include Extensions::Operations
  include Extensions::Utilities

  # Make sure to eager load all constants
  loader.eager_load
end
