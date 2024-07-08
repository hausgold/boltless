# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boltless::Extensions::ConnectionPool do
  let(:described_class) { Boltless }
  let(:reload) do
    proc do
      described_class.connection_pool.shutdown(&:close)
      described_class.instance_variable_set(:@connection_pool, nil)
    end
  end

  after do
    Boltless.reset_configuration!
    reload.call
  end

  describe '.connection_pool' do
    let(:action) { described_class.connection_pool }
    let(:options) { action.checkout.default_options }
    let(:auth) do
      Base64.decode64(options.headers['Authorization'].split.last).split(':')
    end

    # rubocop:disable RSpec/IdenticalEqualityAssertion because we want to
    #   check for a memoized result
    it 'returns a memoized connection pool instance' do
      expect(described_class.connection_pool).to \
        be(described_class.connection_pool)
    end
    # rubocop:enable RSpec/IdenticalEqualityAssertion

    it 'returns a HTTP client instance when requested' do
      expect(action.checkout).to be_a(HTTP::Client)
    end

    it 'returns a configured HTTP client (pool size)' do
      Boltless.configuration.connection_pool_size = 1
      reload.call
      expect(action.size).to be(1)
    end

    it 'returns a configured HTTP client (connection aquire timeout)' do
      Boltless.configuration.connection_pool_timeout = 1
      reload.call
      expect(action.instance_variable_get(:@timeout)).to be(1)
    end

    it 'returns a configured HTTP client (persistent base URL)' do
      Boltless.configuration.base_url = 'http://test:1234'
      reload.call
      expect(options.persistent).to eql('http://test:1234')
    end

    it 'returns a configured HTTP client (username)' do
      Boltless.configuration.username = 'test'
      reload.call
      expect(auth.first).to eql('test')
    end

    it 'returns a configured HTTP client (password)' do
      Boltless.configuration.password = 'test'
      reload.call
      expect(auth.last).to eql('test')
    end

    it 'returns a configured HTTP client (request timeout)' do
      Boltless.configuration.request_timeout = 7
      reload.call
      expect(options.timeout_options[:global_timeout]).to be(7)
    end

    it 'allows send requests' do
      expect(action.checkout.get('/').to_s).to include('neo4j')
    end
  end

  describe '.wait_for_server!' do
    let(:connection) { described_class.connection_pool.checkout }
    let(:action) { described_class.wait_for_server!(connection) }
    let(:request_timeout) { 2.seconds }
    let(:wait_for_upstream_server) { 2.seconds }
    let(:logger) { Logger.new(log) }
    let(:log) { StringIO.new }

    before do
      Boltless.configure do |conf|
        conf.request_timeout = request_timeout
        conf.wait_for_upstream_server = wait_for_upstream_server
        conf.logger = logger
      end
      Boltless.instance_variable_set(:@upstream_is_ready, nil)
      Boltless.instance_variable_set(:@upstream_retry_count, nil)
      reload.call
    end

    context 'when the server is up and running' do
      it 'returns the given connection' do
        expect(action).to be(connection)
      end

      it 'memoizes the check' do
        action
        expect(connection).not_to receive(:get)
        action
      end
    end

    context 'when the server is not available' do
      before do
        Boltless.configuration.base_url = 'http://localhost:8751'
        reload.call
      end

      it 'raises a HTTP::ConnectionError' do
        expect { action }.to raise_error(HTTP::ConnectionError)
      end

      describe 'logging' do
        let(:wait_for_upstream_server) { 2.1.seconds }

        it 'logs a retry' do
          suppress(HTTP::ConnectionError) { action }
          expect(log.string).to \
            include('neo4j is unavailable, retry in 2 seconds ' \
                    '(1/2, http://localhost:8751)')
        end
      end
    end
  end
end
