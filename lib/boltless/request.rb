# frozen_string_literal: true

module Boltless
  # A neo4j HTTP API request abstraction class, which consumes a single HTTP
  # persistent connection for its whole runtime. This connection is strictly
  # owned by a single request object. It is not safe to share it.
  class Request
    class << self
      # Convert a multiple Cypher queries and +Hash+ arguments into multiple
      # HTTP API/Cypher transaction API compatible hashes.
      #
      # @param statements [Array<Array<String, Hash{Symbol => Mixed}>>] the
      #   Cypher statements to convert
      # @return [Array<Hash{Symbol => Mixed}>] the compatible statement objects
      def statement_payloads(*statements)
        statements.map do |(cypher, args)|
          statement_payload(cypher, **(args || {}))
        end
      end

      # Convert a single Cypher query string and +Hash+ arguments into a HTTP
      # API/Cypher transaction API compatible form.
      #
      # @param cypher [String] the Cypher statement to run
      # @param args [Hash{Symbol => Mixed}] the additional Cypher parameters
      # @return [Hash{Symbol => Mixed}] the compatible statement object
      def statement_payload(cypher, **args)
        { statement: cypher }.tap do |payload|
          # Enable the statement statistics if requested
          payload[:includeStats] = true if args.delete(:with_stats) == true

          # Enable the graphing output if request
          payload[:resultDataContents] = %w[row graph] \
            if args.delete(:result_as_graph) == true

          payload[:parameters] = args
        end
      end
    end

    # Setup a new neo4j request instance with the given connection to use.
    #
    # @param connection [HTTP::Client] a ready to use persistent
    #   connection object
    # @param access_mode [String, Symbol] the neo4j
    #   transaction mode (+:read+, or +:write+)
    # @param database [String, Symbol] the neo4j database to use
    # @param raw_results [Boolean] whenever to return the plain HTTP API JSON
    #  results (as plain +Hash{Symbol => Mixed}/Array+ data), or not (then we
    #  return +Array<Boltless::Result>+ structs
    def initialize(connection, access_mode: :write,
                   database: Boltless.configuration.default_db,
                   raw_results: false)
      # Check the given access mode
      @access_mode = mode = access_mode.to_s.upcase
      unless %(READ WRITE).include? mode
        raise ArgumentError, "Unknown access mode '#{access_mode}'. " \
                             "Use ':read' or ':write'."
      end

      @connection = connection
      @path_prefix = "/db/#{database}"
      @raw_results = raw_results
      @requests_done = 0

      # Make sure the upstream server is ready to rumble
      Boltless.wait_for_server!(connection)
    end

    # Run one/multiple Cypher statements inside a one-shot transaction.
    # A new transaction is opened, the statements are run and the transaction
    # is commited in a single HTTP request for efficiency.
    #
    # @param statements [Array<Hash>] the Cypher statements to run
    # @return [Array<Hash{Symbol => Mixed}>] the raw neo4j results
    #
    # @raise [Errors::TransactionNotFoundError] when no open transaction
    #   was found by the given identifier
    # @raise [Errors::TransactionRollbackError] when there was an error while
    #   committing the transaction, we assume that any error causes a
    #   transaction rollback at the neo4j side
    def one_shot_transaction(*statements)
      # We do not allow to send a run-request without Cypher statements
      raise ArgumentError, 'No statements given' if statements.empty?

      log_query(nil, *statements) do
        handle_transaction(tx_id: 'commit') do |path|
          @connection.headers('Access-Mode' => @access_mode)
                     .post(path, body: serialize_body(statements: statements))
        end
      end
    end

    # Start a new transaction within our dedicated HTTP connection object at
    # the neo4j server. When everything is fine, we return the transaction
    # identifier from neo4j for further usage.
    #
    # @return [Integer] the neo4j transaction identifier
    # @raise [Errors::TransactionBeginError] when we fail to start a
    #   new transaction
    def begin_transaction
      log_query(:begin, Request.statement_payload('BEGIN')) do
        handle_transport_errors do
          path = "#{@path_prefix}/tx"
          res = @connection.headers('Access-Mode' => @access_mode).post(path)

          # When neo4j sends a response code other than 2xx,
          # we stop further processing
          raise Errors::TransactionBeginError, res.to_s \
            unless res.status.success?

          # Try to extract the transaction identifier
          location = res.headers['Location'] || ''
          location.split("#{path}/").last.to_i.tap do |tx_id|
            # Make sure we flush this request from the persistent connection,
            # in order to allow further requests
            res.flush

            # When we failed to parse the transaction identifier,
            # we stop further processing
            raise Errors::TransactionBeginError, res.to_s \
              if tx_id.zero?
          end
        end
      end
    end

    # Run one/multiple Cypher statements inside an open transaction.
    #
    # @param tx_id [Integer] the neo4j transaction identifier
    # @param statements [Array<Hash>] the Cypher statements to run
    # @return [Array<Hash{Symbol => Mixed}>] the raw neo4j results
    #
    # @raise [Errors::TransactionNotFoundError] when no open transaction
    #   was found by the given identifier
    # @raise [Errors::TransactionRollbackError] when there was an error while
    #   committing the transaction, we assume that any error causes a
    #   transaction rollback at the neo4j side
    def run_query(tx_id, *statements)
      # We do not allow to send a run-request without Cypher statements
      raise ArgumentError, 'No statements given' if statements.empty?

      log_query(tx_id, *statements) do
        handle_transaction(tx_id: tx_id) do |path|
          @connection.post(path, body: serialize_body(statements: statements))
        end
      end
    end

    # Commit an open transaction, by the given neo4j transaction identifier.
    #
    # @param tx_id [Integer] the neo4j transaction identifier
    # @param statements [Array<Hash>] the Cypher statements to run,
    #   as transaction finalization
    # @return [Array<Hash{Symbol => Mixed}>] the raw neo4j results
    #
    # @raise [Errors::TransactionNotFoundError] when no open transaction
    #   was found by the given identifier
    # @raise [Errors::TransactionRollbackError] when there was an error while
    #   committing the transaction, we assume that any error causes a
    #   transaction rollback at the neo4j side
    def commit_transaction(tx_id, *statements)
      log_query(tx_id, Request.statement_payload('COMMIT')) do
        handle_transaction(tx_id: tx_id) do |path|
          args = {}
          args[:body] = serialize_body(statements: statements) \
            if statements.any?

          @connection.post("#{path}/commit", **args)
        end
      end
    end

    # Rollback an open transaction, by the given neo4j transaction identifier.
    #
    # @param tx_id [Integer] the neo4j transaction identifier
    # @return [Array<Hash{Symbol => Mixed}>] the raw neo4j results
    #
    # @raise [Errors::TransactionNotFoundError] when no open transaction
    #   was found by the given identifier
    # @raise [Errors::TransactionRollbackError] when there was an error while
    #   rolling the transaction back
    def rollback_transaction(tx_id)
      log_query(tx_id, Request.statement_payload('ROLLBACK')) do
        handle_transaction(tx_id: tx_id) do |path|
          @connection.delete(path)
        end
      end
    end

    # Handle a generic transaction interaction.
    #
    # @param tx_id [Integer] the neo4j transaction identifier
    # @return [Array<Hash{Symbol => Mixed}>] the raw neo4j results
    #
    # @raise [Errors::TransactionNotFoundError] when no open transaction
    #   was found by the given identifier
    # @raise [Errors::TransactionRollbackError] when there was an error while
    #   rolling the transaction back
    def handle_transaction(tx_id: nil)
      handle_transport_errors do
        # Run the user given block, and pass the transaction path to it
        res = yield("#{@path_prefix}/tx/#{tx_id}")

        # When the transaction was not found, we tell so
        raise Errors::TransactionNotFoundError.new(res.to_s, response: res) \
          if res.code == 404

        # When the response was simply not successful, we tell so, too
        raise Errors::TransactionRollbackError.new(res.to_s, response: res) \
          unless res.status.success?

        # Handle the response body in a generic way
        handle_response_body(res, tx_id: tx_id)
      end
    end

    # Handle a neo4j HTTP API response body in a generic way.
    #
    # @param res [HTTP::Response] the raw HTTP response to handle
    # @param tx_id [Integer] the neo4j transaction identifier
    # @return [Array<Hash{Symbol => Mixed}>] the raw neo4j results
    #
    # @raise [Errors::TransactionRollbackError] when there were at least one
    #   error in the response, so we assume the transaction was rolled back
    #   by neo4j
    #
    # rubocop:disable Metrics/MethodLength -- because of the result handling
    #   (error, raw result, restructured result)
    def handle_response_body(res, tx_id: nil)
      # Parse the response body as a whole, which is returned by
      # the configured raw response handler
      body = FastJsonparser.parse(
        Boltless.configuration.raw_response_handler.call(res.to_s, res)
      )

      # When we hit some response errors, we handle them and
      # re-raise in a wrapped exception
      if (errors = body.fetch(:errors, [])).any?
        list = errors.map do |error|
          Errors::ResponseError.new(error[:message],
                                    code: error[:code],
                                    response: res)
        end
        raise Errors::TransactionRollbackError.new(
          "Transaction (#{tx_id}) rolled back due to errors (#{list.count})",
          errors: list,
          response: res
        )
      end

      # Otherwise return the results, either wrapped in a
      # lightweight struct or raw
      return body[:results] if @raw_results

      body.fetch(:results, []).map do |result|
        Boltless::Result.from(result)
      end
    rescue FastJsonparser::ParseError => e
      # When we got something we could not parse, we tell so
      raise Errors::InvalidJsonError.new(e.message, response: res)
    end
    # rubocop:enable Metrics/MethodLength

    # Serialize the given object to a JSON string.
    #
    # @param obj [Mixed] the object to serialize
    # @return [String] the JSON string representation
    def serialize_body(obj)
      obj = obj.deep_stringify_keys if obj.is_a? Hash
      Oj.dump(obj)
    end

    # Handle all the low-level http.rb gem errors transparently.
    #
    # @yield the given block
    # @return [Mixed] the result of the given block
    #
    # @raise [Errors::RequestError] when a low-level error occured
    def handle_transport_errors
      yield
    rescue HTTP::Error => e
      raise Errors::RequestError, e.message
    end

    # Log the query details for the given statements, while benchmarking the
    # given user block (which should contain the full request preparation,
    # request performing and response parsing).
    #
    # When the +query_log_enabled+ configuration flag is set to +false+, we
    # effectively do a no-op here, to keep things fast.
    #
    # @param tx_id [Integer] the neo4j transaction identifier
    # @param statements [Array<Hash>] the Cypher statements to run
    # @yield the given user block
    # @return [Mixed] the result of the user given block
    #
    # rubocop:disable Metrics/MethodLength -- because of the configuration
    #   handling
    def log_query(tx_id, *statements)
      # When no query logging is enabled, we won't do it
      enabled = Boltless.configuration.query_log_enabled
      return yield unless enabled

      # Add a new request to the counter
      @requests_done += 1

      # When the +query_debug_log_enabled+ config flag is set, we prodce a
      # logging output before the actual request is sent, in order to help
      # while debugging slow/never-ending Cypher statements
      if enabled == :debug
        Boltless.logger.debug do
          generate_log_str(tx_id == :begin ? 'tbd' : tx_id,
                           nil,
                           *statements)
        end
      end

      # Otherwise measure the runtime of the user given block,
      # and log the related statements
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC,
                                    :float_millisecond)
      res = yield
      stop = Process.clock_gettime(Process::CLOCK_MONOTONIC,
                                   :float_millisecond)

      # As a fallback to the +query_log_enabled+ config flag, we just log to
      # the debug level with a block, so it won't be executed when the logger
      # is not configured to print debug level
      Boltless.logger.debug do
        generate_log_str(tx_id == :begin ? res : tx_id,
                         (stop - start).truncate(1),
                         *statements)
      end

      # Return the result of the user given block
      res
    end
    # rubocop:enable Metrics/MethodLength

    # Generate a logging string for the given details,
    # without actually printing it.
    #
    # @param tx_id [Integer, String, nil] the neo4j transaction identifier
    # @param duration [Numeric, nil] the duration (ms) of the query
    # @param statements [Array<Hash>] the Cypher statements to run
    # @return [String] the assembled logging string
    def generate_log_str(tx_id, duration, *statements)
      dur = "(#{duration}ms)".colorize(color: :magenta, mode: :bold) \
        if duration

      tag = [
        '[',
        "tx:#{@access_mode.downcase}:#{tx_id || 'one-shot'}",
        tx_id ? " rq:#{@requests_done}" : '',
        ']'
      ].join.colorize(:white)

      prefix = ['Boltless'.colorize(:magenta), tag, dur].compact.join(' ')

      statements.map do |stmt|
        cypher = Boltless.resolve_cypher(
          stmt[:statement], **(stmt[:parameters] || {})
        ).lines.map(&:strip).join(' ')
        cypher = cypher.colorize(color: Boltless.cypher_logging_color(cypher),
                                 mode: :bold)
        "#{prefix} #{cypher}"
      end.join("\n")
    end
  end
end
