# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'boltless/version'

Gem::Specification.new do |spec|
  spec.name = 'boltless'
  spec.version = Boltless::VERSION
  spec.authors = ['Hermann Mayer']
  spec.email = ['hermann.mayer92@gmail.com']

  spec.license = 'MIT'
  spec.summary = 'neo4j driver, via the HTTP API'
  spec.description = 'neo4j driver, via the HTTP API'

  base_uri = "https://github.com/hausgold/#{spec.name}"
  spec.metadata = {
    'homepage_uri' => base_uri,
    'source_code_uri' => base_uri,
    'changelog_uri' => "#{base_uri}/blob/master/CHANGELOG.md",
    'bug_tracker_uri' => "#{base_uri}/issues",
    'documentation_uri' => "https://www.rubydoc.info/gems/#{spec.name}"
  }

  spec.files = Dir['{ext,lib,spec,src}/**/*'] +
               Dir['{*file,*.toml,*.yml}']

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.7'

  spec.add_dependency 'activesupport', '>= 6.1'
  spec.add_dependency 'base64', '~> 0.2.0'
  spec.add_dependency 'colorize', '>= 0.8.0'
  spec.add_dependency 'connection_pool', '~> 2.3'
  spec.add_dependency 'fast_jsonparser', '>= 0.6.0'
  spec.add_dependency 'http', '~> 5.0'
  spec.add_dependency 'oj', '~> 3.13'
  spec.add_dependency 'rake', '~> 13.0'
  spec.add_dependency 'zeitwerk', '~> 2.6'
end
