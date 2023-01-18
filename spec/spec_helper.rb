# frozen_string_literal: true

require 'simplecov'
SimpleCov.command_name 'specs'

require 'bundler/setup'
require 'active_support/core_ext/kernel/reporting'
require 'yaml'
require 'boltless'

# Load all support helpers and shared examples
Dir[File.join(__dir__, 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Enable the focus inclusion filter and run all when no filter is set
  # See: http://bit.ly/2TVkcIh
  config.filter_run(focus: true)
  config.run_all_when_everything_filtered = true

  # Clean the neo4j database before we use it
  config.before(:suite) do
    reset_boltless_config!
    clean_neo4j!
  end

  # Reset the gem configuration before each example
  config.before do
    reset_boltless_config!
  end
end
