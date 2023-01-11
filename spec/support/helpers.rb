# frozen_string_literal: true

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

# Fetch a file fixture by name/path.
#
# @param path [String, Symbol] the path to fetch
# @return [Pathname] the found file fixture
def file_fixture(path)
  Pathname.new(File.expand_path(File.join(__dir__,
                                          "../fixtures/files/#{path}")))
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
