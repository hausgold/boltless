# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'boltless/version'

Gem::Specification.new do |spec|
  spec.name          = 'boltless'
  spec.version       = Boltless::VERSION
  spec.authors       = ['Hermann Mayer']
  spec.email         = ['hermann.mayer92@gmail.com']

  spec.summary       = 'neo4j driver, via the HTTP API'
  spec.description   = 'neo4j driver, via the HTTP API'
  spec.homepage      = 'https://github.com/hausgold/identity-api'

  spec.files         = Dir['{ext,lib,spec,src}/**/*'] +
                       Dir['{*file,*.toml,*.yml}']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.5'

  spec.add_runtime_dependency 'activesupport', '>= 5.2.0'
  spec.add_runtime_dependency 'colorize', '>= 0.8.0'
  spec.add_runtime_dependency 'connection_pool', '~> 2.2'
  spec.add_runtime_dependency 'fast_jsonparser', '>= 0.6.0'
  spec.add_runtime_dependency 'http', '~> 5.0'
  spec.add_runtime_dependency 'oj', '~> 3.0'
  spec.add_runtime_dependency 'rake', '>= 13.0'
  spec.add_runtime_dependency 'zeitwerk', '~> 2.4'

  spec.add_development_dependency 'appraisal'
  spec.add_development_dependency 'benchmark-ips', '~> 2.10'
  spec.add_development_dependency 'bundler', '>= 1.16', '< 3'
  spec.add_development_dependency 'countless', '~> 1.0'
  spec.add_development_dependency 'guard-rspec', '~> 4.7'
  spec.add_development_dependency 'irb', '~> 1.2'
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'rubocop', '~> 1.25'
  spec.add_development_dependency 'rubocop-rails', '~> 2.14'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.10'
  spec.add_development_dependency 'simplecov', '< 0.18'
  spec.add_development_dependency 'yard', '~> 0.9.18'
  spec.add_development_dependency 'yard-activesupport-concern', '~> 0.0.1'
end
