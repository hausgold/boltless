# frozen_string_literal: true

module Boltless
  # A single neo4j transaction representation.
  #
  # When passing Cypher statements you can tweak some HTTP API result options
  # while passing the following keys to the Cypher parameters (they wont be
  # sent to neo4j):
  #
  #   * +with_stats: true|false+: whenever to include statement
  #     statistics, or not (see: https://bit.ly/3SKXfC8)
  #   * +result_as_graph: true|false+: whenever to return the result as a graph
  #     structure that can be visualized (see: https://bit.ly/3doJw3Z)
  #
  # Error handling details (see: https://bit.ly/3pdqTCy):
  #
  # > If there is an error in a request, the server will roll back the
  # > transaction. You can tell if the transaction is still open by inspecting
  # > the response for the presence/absence of the transaction key.
  class Transaction
    # We allow to read some internal configurations
    attr_reader :access_mode, :id, :raw_state

    # We allow to access helpful utilities straigth from here
    delegate :build_cypher, :prepare_label, :prepare_type, :prepare_string,
             :to_options, :resolve_cypher,
             to: Boltless

    # Setup a new neo4j transaction management instance.
    #
    # @param connection [HTTP::Client] a ready to use persistent
    #   connection object
    # @param database [String, Symbol] the neo4j database to use
    # @param access_mode [String, Symbol] the neo4j
    #   transaction mode (+:read+, or +:write+)
    # @param raw_results [Boolean] whenever to return the plain HTTP API JSON
    #  results (as plain +Hash{Symbol => Mixed}/Array+ data), or not (then we
    #  return +Array<Boltless::Result>+ structs
    def initialize(connection, database: Boltless.configuration.default_db,
                   access_mode: :write, raw_results: false)
      @request = Request.new(connection, access_mode: access_mode,
                                         database: database,
                                         raw_results: raw_results)
      @access_mode = access_mode
      @raw_state = :not_yet_started
    end

    # Return the transaction state as +ActiveSupport::StringInquirer+
    # for convenience.
    #
    # @return [ActiveSupport::StringInquirer] the transaction state
    def state
      ActiveSupport::StringInquirer.new(@raw_state.to_s)
    end

    # Begin a new transaction. No exceptions will be rescued.
    #
    # @return [TrueClass] when the transaction was successfully started
    #
    # @raise [Errors::RequestError] when an error occurs, see request object
    #   for fine-grained details
    #
    # rubocop:disable Naming/PredicateMethod -- because this method performs an
    #   action, not a predicate check (bool is for error signaling)
    def begin!
      # We do not allow messing around in wrong states
      unless @raw_state == :not_yet_started
        raise Errors::TransactionInBadStateError,
              "Transaction already #{@raw_state}"
      end

      @id = @request.begin_transaction
      @raw_state = :open
      true
    end
    # rubocop:enable Naming/PredicateMethod

    # Begin a new transaction. We rescue all errors transparently.
    #
    # @return [Boolean] whenever the transaction was successfully started,
    #   or not
    def begin
      handle_errors(false) { begin! }
    end

    # Run a single Cypher statement inside the transaction. This results
    # in a single HTTP API request for the statement.
    #
    # @param cypher [String] the Cypher statement to run
    # @param args [Hash{Symbol => Mixed}] the additional Cypher parameters
    # @return [Hash{Symbol => Mixed}] the raw neo4j results
    #
    # @raise [Errors::RequestError] when an error occurs, see request object
    #   for fine-grained details
    def run!(cypher, **args)
      # We do not allow messing around in wrong states
      raise Errors::TransactionInBadStateError, 'Transaction not open' \
        unless @raw_state == :open

      @request.run_query(@id, Request.statement_payload(cypher, **args)).first
    end

    # Run a single Cypher statement inside the transaction. This results in a
    # single HTTP API request for the statement. We rescue all errors
    # transparently.
    #
    # @param cypher [String] the Cypher statement to run
    # @param args [Hash{Symbol => Mixed}] the additional Cypher parameters
    # @return [Array<Hash{Symbol => Mixed}>, nil] the raw neo4j results,
    #   or +nil+ in case of errors
    def run(cypher, **args)
      handle_errors { run!(cypher, **args) }
    end

    # Run a multiple Cypher statement inside the transaction. This results
    # in a single HTTP API request for all the statements.
    #
    # @param statements [Array<Hash>] the Cypher statements to run
    # @return [Array<Hash{Symbol => Mixed}>] the raw neo4j results
    #
    # @raise [Errors::RequestError] when an error occurs, see request object
    #   for fine-grained details
    def run_in_batch!(*statements)
      # We do not allow messing around in wrong states
      raise Errors::TransactionInBadStateError, 'Transaction not open' \
        unless @raw_state == :open

      @request.run_query(@id, *Request.statement_payloads(*statements))
    end

    # Run a multiple Cypher statement inside the transaction. This results
    # in a single HTTP API request for all the statements. We rescue all errors
    # transparently.
    #
    # @param statements [Array<Hash>] the Cypher statements to run
    # @return [Array<Hash{Symbol => Mixed}>, nil] the raw neo4j results,
    #   or +nil+ in case of errors
    #
    # @raise [Errors::RequestError] when an error occurs, see request object
    #   for fine-grained details
    def run_in_batch(*statements)
      handle_errors { run_in_batch!(*statements) }
    end

    # Commit the transaction, while also sending finalizing Cypher
    # statement(s). This results in a single HTTP API request for all the
    # statement(s). You can also omit the statement(s) in order to just commit
    # the transaction.
    #
    # @param statements [Array<Hash>] the Cypher statements to run
    # @return [Array<Hash{Symbol => Mixed}>] the raw neo4j results
    #
    # @raise [Errors::RequestError] when an error occurs, see request object
    #   for fine-grained details
    def commit!(*statements)
      # We do not allow messing around in wrong states
      raise Errors::TransactionInBadStateError, 'Transaction not open' \
        unless @raw_state == :open

      @request.commit_transaction(
        @id,
        *Request.statement_payloads(*statements)
      ).tap { @raw_state = :closed }
    end

    # Commit the transaction, while also sending finalizing Cypher
    # statement(s). This results in a single HTTP API request for all the
    # statement(s). You can also omit the statement(s) in order to just commit
    # the transaction. We rescue all errors transparently.
    #
    # @param statements [Array<Hash>] the Cypher statements to run
    # @return [Array<Hash{Symbol => Mixed}>, nil] the raw neo4j results,
    #   or +nil+ in case of errors
    #
    # @raise [Errors::RequestError] when an error occurs, see request object
    #   for fine-grained details
    def commit(*statements)
      handle_errors { commit!(*statements) }
    end

    # Rollback this transaction. No exceptions will be rescued.
    #
    # @return [TrueClass] when the transaction was successfully rolled back
    #
    # @raise [Errors::RequestError] when an error occurs, see request object
    #   for fine-grained details
    #
    # rubocop:disable Naming/PredicateMethod -- because this method performs
    #   an action, not a predicate check (bool is for error signaling)
    def rollback!
      # We do not allow messing around in wrong states
      raise Errors::TransactionInBadStateError, 'Transaction not open' \
        unless @raw_state == :open

      @request.rollback_transaction(@id)
      @raw_state = :closed
      true
    end
    # rubocop:enable Naming/PredicateMethod

    # Rollback this transaction. We rescue all errors transparently.
    #
    # @return [Boolean] whenever the transaction was successfully rolled back,
    #   or not
    def rollback
      handle_errors(false) { rollback! }
    end

    # Handle all request/response errors of the low-level connection for
    # our non-bang methods in a generic way.
    #
    # @param error_result [Proc, Mixed] the object to return on errors, when a
    #   proc is given, we call it with the actual exception object as parameter
    #   and use the result of the proc as return value
    # @yield the given block
    # @return [Mixed] the result of the block, or on exceptions the
    #   given +error_result+
    def handle_errors(error_result = nil)
      yield
    rescue Errors::RequestError, Errors::ResponseError,
           Errors::TransactionInBadStateError => e
      # When an error occured, the transaction is automatically rolled back by
      # neo4j, so we cannot handle any further interaction
      cleanup
      @raw_state = :closed

      # When we got a proc/lambda as error result, call it
      return error_result.call(e) if error_result.is_a? Proc

      # Otherwise use the error result as it is
      error_result
    end

    # Clean the transaction, in order to make it unusable for further
    # interaction. This prevents users from leaking the transaction context and
    # mess around with the connection pool.
    def cleanup
      @request = nil
      @raw_state = :cleaned
    end
  end
end
