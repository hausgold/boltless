# frozen_string_literal: true

module Boltless
  # The configuration for the Boltless gem.
  class Configuration
    include ActiveSupport::Configurable

    # The base URL of the neo4j HTTP API (port 7474 for HTTP, port 7473
    # for HTTPS when configured at server side)
    config_accessor(:base_url) { 'http://neo4j:7474' }

    # The username for the neo4j database (used for HTTP Basic Authentication)
    config_accessor(:username) { 'neo4j' }

    # The password for the neo4j database (used for HTTP Basic Authentication)
    config_accessor(:password) { 'neo4j' }

    # The default user database of the neo4j instance/cluster, for the
    # community edition this is always +neo4j+, only a single user database is
    # supported with the community editon. You can always specify which
    # database to operate on, on each top-level querying method (eg.
    # +Boltless.execute(.., database: 'custom')+
    config_accessor(:default_db) { 'neo4j' }

    # The seconds to wait for a connection from the pool,
    # when all connections are currently in use
    config_accessor(:connection_pool_timeout) { 15.seconds }

    # The size of the connection pool, make sure it matches your application
    # server (eg. Puma) thread pool size, in order to avoid
    # timeouts/bottlenecks
    config_accessor(:connection_pool_size) { 10 }

    # The overall timeout for a single HTTP request (including connecting,
    # transmitting and response completion)
    config_accessor(:request_timeout) { 10.seconds }

    # We allow the neo4j server to bootup for the configured time. This allows
    # parallel starts of the user application and the neo4j server, without
    # glitching.
    config_accessor(:wait_for_upstream_server) { 30.seconds }

    # Configure a logger for the gem
    config_accessor(:logger) do
      Logger.new($stdout).tap do |logger|
        logger.level = :info
      end
    end

    # Whenever we should log the neo4j queries, including benchmarking. When
    # disabled we reduce the logging overhead even more as no debug logs hit
    # the logger at all. Enable this for testing purposes or for local
    # development. (Heads up: No parameter sanitation is done, so passwords etc
    # will be logged with this enabled) Setting the value to +:debug+ will
    # print the actual Cypher statements before any request is sent. This may
    # be helpful inspection of slow/never-ending Cypher statements.
    config_accessor(:query_log_enabled) { false }

    # We allow the http.rb gem to be configured by the user for special needs.
    # Just assign a user given block here and you can reconfigure the client.
    # Just make sure to return the configured +HTTP::Client+ instance
    # afterwards.
    config_accessor(:http_client_configure) do
      proc do |connection|
        connection
      end
    end
  end
end
