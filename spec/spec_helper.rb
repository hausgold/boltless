# frozen_string_literal: true

require 'simplecov'
SimpleCov.command_name 'specs'

require 'bundler/setup'
require 'active_support/core_ext/kernel/reporting'
require 'yaml'
require 'boltless'

# Reset the gem configuration.
def reset_boltless_config!
  Boltless.logger.level = :info
  Boltless.reset_configuration!
  # Check for CI in order to set the correct neo4j base URL
  Boltless.configuration.base_url = 'http://neo4j.boltless.local:7474' \
    unless ENV['GITHUB_ACTIONS'].nil?
end

# Clean neo4j database (nodes/relationships).
def clean_neo4j!
  Boltless.logger.level = :error
  Boltless.clear_database!
  reset_boltless_config!
end

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

# Print some information
puts
puts <<DESC
  -------------- Versions --------------
            Ruby: #{RUBY_VERSION}
  Active Support: #{ActiveSupport.version}
  --------------------------------------
DESC
puts

# Fetch a file fixture by name/path.
#
# @param path [String, Symbol] the path to fetch
# @return [Pathname] the found file fixture
def file_fixture(path)
  Pathname.new(File.expand_path(File.join(__dir__, "fixtures/files/#{path}")))
end

# Return a neo4j raw result from a file fixture. It looks excatly like produced
# by +Boltless::Request#handle_response_body+.
#
# @param suffixes [Array<String, Symbol>] additional file suffixes, check the
#   +spec/fixtures/files/+ directory for all available variants
def raw_result_fixture(*suffixes)
  suffixes = suffixes.map(&:to_s).join('_')
  suffixes = "_#{suffixes}" unless suffixes.empty?
  file = "raw_result#{suffixes}.yml"

  yml_meth = YAML.respond_to?(:unsafe_load) ? :unsafe_load : :load
  res = YAML.send(yml_meth, file_fixture(file).read)

  res = res.map(&:deep_symbolize_keys) if res.is_a? Array
  res = res.deep_symbolize_keys if res.is_a? Hash
  res
end
