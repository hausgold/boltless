# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boltless::Extensions::ConfigurationHandling do
  let(:described_class) { Boltless }

  before { described_class.reset_configuration! }

  it 'allows the access of the configuration' do
    expect(described_class.configuration).not_to be_nil
  end

  describe '.configure' do
    it 'yields the configuration' do
      expect do |block|
        described_class.configure(&block)
      end.to yield_with_args(described_class.configuration)
    end
  end

  describe '.reset_configuration!' do
    it 'resets the configuration to its defaults' do
      described_class.configuration.request_timeout = 100
      expect { described_class.reset_configuration! }.to \
        change { described_class.configuration.request_timeout }
    end
  end

  describe '.logger' do
    it 'returns a Logger instance' do
      expect(described_class.logger).to be_a(Logger)
    end

    it 'returns a logger with the default info level' do
      expect(described_class.logger.level).to eql(Logger::INFO)
    end
  end
end
