# frozen_string_literal: true

module Boltless
  module Extensions
    # A top-level gem-module extension to add easy-to-use connection pool.
    #
    # rubocop:disable Metrics/BlockLength -- because this is how an
    #   +ActiveSupport::Concern+ looks like
    module ConnectionPool
      extend ActiveSupport::Concern

      class_methods do
        # Check if the neo4j server is ready to rumble. This comes in handy in
        # local scenarios when the neo4j server is booted in parallel to the
        # user application. Then it may be necessary to wait for the neo4j
        # server to come up, before sending real requests which may otherwise
        # be ignored.
        #
        # @param connection [HTTP::Client]
        # @return [HTTP::Client] the given connection
        #
        # @raise [HTTP::Error] in case the upstream server did not come up
        #
        # rubocop:disable Metrics/MethodLength -- because of the retry logic
        # rubocop:disable Metrics/AbcSize -- dito
        def wait_for_server!(connection)
          # Check if the server already accepted connections
          return connection if @upstream_is_ready

          # Otherwise we setup the retry counter and
          # increment it for the current try
          @upstream_retry_count ||= 0
          @upstream_retry_count += 1

          # We didn't checked the upstream server yet
          body = connection.get('/').to_s
          raise "Upstream server not available: #{body}" \
            unless body.include? 'neo4j_version'

          # When we reached this point, the remote connection is established,
          # so we reset the retry counter
          @upstream_retry_count = 0

          # Everything looks good, when we passed this point
          @upstream_is_ready = true

          # Return the given connection
          connection
        rescue HTTP::Error, RuntimeError => e
          # Something is bad, we got a timeout or the response body
          # was unexpected, so lets try it again
          retry_sleep = 2.seconds

          # We allow the service to be unavailable for 30 seconds
          max_retries = (
            configuration.wait_for_upstream_server / retry_sleep
          ).ceil
          raise e if @upstream_retry_count >= max_retries

          logger.warn do
            '> neo4j is unavailable, retry in 2 seconds ' \
            "(#{@upstream_retry_count}/#{max_retries}, " \
            "#{configuration.base_url})"
              .colorize(:yellow)
          end
          sleep(retry_sleep)
          retry
        end
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Metrics/AbcSize

        # A memoized connection pool for our HTTP API clients.
        #
        # @see https://github.com/mperham/connection_pool
        # @return [::ConnectionPool] the connection pool instance
        #
        # rubocop:disable Metrics/MethodLength -- because of the connection
        #   configuration
        # rubocop:disable Metrics/AbcSize -- dito
        def connection_pool
          @connection_pool ||= begin
            conf = Boltless.configuration

            ::ConnectionPool.new(
              size: conf.connection_pool_size,
              timeout: conf.connection_pool_timeout
            ) do
              HTTP
                .use({ normalize_uri: { normalizer: ->(uri) { uri } } })
                .use(:auto_inflate)
                .timeout(conf.request_timeout.to_i)
                .basic_auth(
                  user: conf.username,
                  pass: conf.password
                )
                .headers(
                  'User-Agent' => "Boltless/#{Boltless::VERSION}",
                  'Accept-Encoding' => 'gzip',
                  'Accept' => 'application/json',
                  'Content-Type' => 'application/json',
                  'X-Stream' => 'true'
                )
                .encoding('UTF-8')
                .persistent(conf.base_url)
                .yield_self do |connection|
                  conf.http_client_configure.call(connection)
                end
            end
          end
        end
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Metrics/AbcSize
      end

      included do
        # Install an shutdown handler for our connection pool
        at_exit do
          connection_pool.shutdown do |connection|
            connection&.close
          end
        end
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
