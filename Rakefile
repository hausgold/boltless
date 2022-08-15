# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'countless/rake_tasks'
require 'pp'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

# Configure all code statistics directories
Countless.configure do |config|
  config.stats_base_directories = [
    { name: 'Top-levels', dir: 'lib',
      pattern: %r{/lib(/boltless)?/[^/]+\.rb$} },
    { name: 'Top-levels specs', test: true, dir: 'spec',
      pattern: %r{/spec(/boltless)?/[^/]+_spec\.rb$} },
    { name: 'Extensions', pattern: 'lib/boltless/extensions/**/*.rb' },
    { name: 'Extensions specs', test: true,
      pattern: 'spec/boltless/extensions/**/*_spec.rb' },
    { name: 'Errors', pattern: 'lib/boltless/errors/**/*.rb' },
    { name: 'Errors specs', test: true,
      pattern: 'spec/boltless/errors/**/*_spec.rb' }
  ]
end
