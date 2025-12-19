# frozen_string_literal: true

module Boltless
  module Extensions
    # A top-level gem-module extension to add easy-to-use methods to use the
    # Cypher transactional API.
    module Transactions
      extend ActiveSupport::Concern

      class_methods do
        # Perform a single Cypher statement and return its results.
        #
        # @param cypher [String] the Cypher statement to run
        # @param access_mode [String, Symbol] the neo4j transaction access
        #   mode, use +:read+ or +:write+
        # @param database [String, Symbol] the neo4j database to use
        # @param raw_results [Boolean] whenever to return the plain HTTP API
        #   JSON results (as plain +Hash{Symbol => Mixed}/Array+ data), or not
        #   (then we return +Array<Boltless::Result>+ structs
        # @return [Array<Hash{Symbol => Mixed}>] the (raw) neo4j results
        #
        # @raise [Boltless::Errors::RequestError] in case of low-level issues
        # @raise [Boltless::Errors::ResponseError] in case of issues
        #   found by neo4j
        def execute!(cypher, access_mode: :write,
                     database: Boltless.configuration.default_db,
                     raw_results: false, **args)
          one_shot!(
            access_mode,
            database: database,
            raw_results: raw_results
          ) do |tx|
            tx.add(cypher, **args)
          end.first
        end
        alias_method :write!, :execute!

        # Perform a single Cypher statement and return its results.
        # Any transfer error will be rescued.
        #
        # @param cypher [String] the Cypher statement to run
        # @param access_mode [String, Symbol] the neo4j transaction access
        #   mode, use +:read+ or +:write+
        # @param database [String, Symbol] the neo4j database to use
        # @param raw_results [Boolean] whenever to return the plain HTTP API
        #   JSON results (as plain +Hash{Symbol => Mixed}/Array+ data), or not
        #   (then we return +Array<Boltless::Result>+ structs
        # @return [Array<Hash{Symbol => Mixed}>, nil] the (raw) neo4j
        #   results, or +nil+ in case of errors
        def execute(cypher, access_mode: :write,
                    database: Boltless.configuration.default_db,
                    raw_results: false, **args)
          one_shot(
            access_mode,
            database: database,
            raw_results: raw_results
          ) do |tx|
            tx.add(cypher, **args)
          end&.first
        end
        alias_method :write, :execute

        # A simple shortcut to perform a single Cypher in read access mode. See
        # +.execute!+ for further details.
        #
        # @param cypher [String] the Cypher statement to run
        # @param access_mode [String, Symbol] the neo4j transaction access
        #   mode, use +:read+ or +:write+
        # @param args [Hash{Symbol}] all additional arguments of +.execute!+
        # @return [Array<Hash{Symbol => Mixed}>, nil] the (raw) neo4j
        #   results, or +nil+ in case of errors
        def query!(cypher, access_mode: :read, **args)
          execute!(cypher, access_mode: access_mode, **args)
        end
        alias_method :read!, :query!

        # A simple shortcut to perform a single Cypher in read access mode. See
        # +.execute+ for further details. Any transfer error will be rescued.
        #
        # @param cypher [String] the Cypher statement to run
        # @param access_mode [String, Symbol] the neo4j transaction access
        #   mode, use +:read+ or +:write+
        # @param args [Hash{Symbol}] all additional arguments of +.execute+
        # @return [Array<Hash{Symbol => Mixed}>, nil] the (raw) neo4j
        #   results, or +nil+ in case of errors
        def query(cypher, access_mode: :read, **args)
          execute(cypher, access_mode: access_mode, **args)
        end
        alias_method :read, :query

        # Start an single shot transaction and run all the given Cypher
        # statements inside it. When anything within the user given block
        # raises, we do not send the actual HTTP API request to the neo4j
        # server.
        #
        # @param access_mode [String, Symbol] the neo4j transaction access
        #   mode, use +:read+ or +:write+
        # @param database [String, Symbol] the neo4j database to use
        # @param raw_results [Boolean] whenever to return the plain HTTP API
        #   JSON results (as plain +Hash{Symbol => Mixed}/Array+ data), or not
        #   (then we return +Array<Boltless::Result>+ structs
        # @yield [Boltless::StatementCollector] the statement collector object
        #   to use
        # @return [Array<Hash{Symbol => Mixed}>] the (raw) neo4j results
        #
        # @raise [Boltless::Errors::RequestError] in case of low-level issues
        # @raise [Boltless::Errors::ResponseError] in case of issues
        #   found by neo4j
        # @raise [Mixed] when an exception occurs inside the user given block
        def one_shot!(access_mode = :write,
                      database: Boltless.configuration.default_db,
                      raw_results: false)
          # Fetch a connection from the pool
          connection_pool.with do |connection|
            # Setup a neo4j HTTP API request abstraction instance,
            # and a statement collector
            req = Request.new(connection, access_mode: access_mode,
                                          database: database,
                                          raw_results: raw_results)
            collector = StatementCollector.new

            # Run the user given block, and pass down the collector
            yield(collector)

            # Perform the actual HTTP API request
            req.one_shot_transaction(*collector.statements)
          end
        end

        # Start an single shot transaction and run all the given Cypher
        # statements inside it. When anything within the user given block
        # raises, we do not send the actual HTTP API request to the neo4j
        # server. Any other transfer error will be rescued.
        #
        # @param access_mode [String, Symbol] the neo4j transaction access
        #   mode, use +:read+ or +:write+
        # @param database [String, Symbol] the neo4j database to use
        # @param raw_results [Boolean] whenever to return the plain HTTP API
        #   JSON results (as plain +Hash{Symbol => Mixed}/Array+ data), or not
        #   (then we return +Array<Boltless::Result>+ structs
        # @yield [Boltless::StatementCollector] the statement collector object
        #   to use
        # @return [Array<Hash{Symbol => Mixed}>, nil] the (raw) neo4j results,
        #   or +nil+ on errors
        #
        # @raise [Mixed] when an exception occurs inside the user given block
        def one_shot(access_mode = :write,
                     database: Boltless.configuration.default_db,
                     raw_results: false)
          # Fetch a connection from the pool
          connection_pool.with do |connection|
            # Setup a neo4j HTTP API request abstraction instance,
            # and a statement collector
            req = Request.new(connection, access_mode: access_mode,
                                          database: database,
                                          raw_results: raw_results)
            collector = StatementCollector.new

            # Run the user given block, and pass down the collector
            yield(collector)

            # Perform the actual HTTP API request
            begin
              req.one_shot_transaction(*collector.statements)
            rescue Errors::RequestError, Errors::ResponseError
              # When we hit an error here, we will return +nil+ to signalize it
              nil
            end
          end
        end

        # Start an new transaction and run Cypher statements inside it. When
        # anything within the user given block raises, we automatically
        # rollback the transaction.
        #
        # @param access_mode [String, Symbol] the neo4j transaction access
        #   mode, use +:read+ or +:write+
        # @param database [String, Symbol] the neo4j database to use
        # @param raw_results [Boolean] whenever to return the plain HTTP API
        #   JSON results (as plain +Hash{Symbol => Mixed}/Array+ data), or not
        #   (then we return +Array<Boltless::Result>+ structs
        # @yield [Boltless::Transaction] the transaction object to use
        # @return [Mixed] the result of the user given block
        #
        # @raise [Boltless::Errors::RequestError] in case of low-level issues
        # @raise [Boltless::Errors::ResponseError] in case of issues
        #   found by neo4j
        # @raise [Mixed] when an exception occurs inside the user given
        #   block, we re-raise it
        def transaction!(access_mode = :write,
                         database: Boltless.configuration.default_db,
                         raw_results: false)
          # Fetch a connection from the pool
          connection_pool.with do |connection|
            # Setup and start a new transaction
            tx = Boltless::Transaction.new(connection,
                                           database: database,
                                           access_mode: access_mode,
                                           raw_results: raw_results)
            tx.begin!

            begin
              # Run the user given block, and pass
              # the transaction instance down
              res = yield(tx)
            rescue StandardError => e
              # In case anything raises inside the user block,
              # we try to auto-rollback the opened transaction
              tx.rollback

              # Re-raise the original error
              raise e
            end

            # Try to commit after the user given block,
            # when the transaction is still open
            tx.commit! if tx.state.open?

            # Return the result of the user given block
            res
          ensure
            # Clean up the transaction object
            tx.cleanup
          end
        end

        # Start an new transaction and run Cypher statements inside it. When
        # anything within the user given block raises, we automatically
        # rollback the transaction.
        #
        # @param access_mode [String, Symbol] the neo4j transaction access
        #   mode, use +:read+ or +:write+
        # @param database [String, Symbol] the neo4j database to use
        # @param raw_results [Boolean] whenever to return the plain HTTP API
        #   JSON results (as plain +Hash{Symbol => Mixed}/Array+ data), or not
        #   (then we return +Array<Boltless::Result>+ structs
        # @yield [Boltless::Transaction] the transaction object to use
        # @return [Mixed] the result of the user given block
        #
        # @raise [Mixed] when an exception occurs inside the user given
        #   block, we re-raise it
        def transaction(access_mode = :write,
                        database: Boltless.configuration.default_db,
                        raw_results: false)
          # Fetch a connection from the pool
          connection_pool.with do |connection|
            # Setup and start a new transaction, when the start up fails,
            # we return +nil+ and stop further processing
            tx = Boltless::Transaction.new(connection,
                                           database: database,
                                           access_mode: access_mode,
                                           raw_results: raw_results)
            next unless tx.begin

            begin
              # Run the user given block, and pass
              # the transaction instance down
              res = yield(tx)
            rescue StandardError => e
              # In case anything raises inside the user block,
              # we auto-rollback the opened transaction
              tx.rollback

              # Re-raise the original error
              raise e
            end

            # Try to commit after the user given block, when the transaction is
            # still open, and return the results of the user given block if the
            # transaction is successfully commited
            tx_committed = tx.state.open? ? tx.commit : true
            next res if tx_committed

            # Otherwise return +nil+ again,
            # to signalize the transaction failed
            nil
          ensure
            # Clean up the transaction object
            tx.cleanup
          end
        end
      end
    end
  end
end
