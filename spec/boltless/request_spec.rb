# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/NestedGroups because nesting makes sense here
RSpec.describe Boltless::Request do
  let(:new_instance) { ->(**args) { described_class.new(connection, **args) } }
  let(:instance) { new_instance.call }
  let(:connection) { Boltless.connection_pool.checkout }
  let(:catch_exception) do
    proc do |&block|
      block.call
    rescue StandardError => e
      e
    end
  end
  let(:tx_id) { nil }
  let(:response) do
    HTTP::Response.new(
      status: http_status_code,
      version: '1.1',
      headers: headers,
      body: body,
      request: nil
    )
  end
  let(:body) { '' }
  let(:headers) { {} }
  let(:http_status_code) { 200 }
  let(:statements) do
    [
      {
        statement: 'RETURN 1',
        parameters: {}
      },
      {
        statement: 'RETURN $arg',
        parameters: { arg: 2 }
      }
    ]
  end
  let(:logger) { Logger.new(log_dev, level: :debug) }
  let(:log_dev) { StringIO.new }
  let(:log) { log_dev.string.uncolorize }

  before { Boltless.configuration.logger = logger }

  describe 'full workflow' do
    let(:action) do
      id = instance.begin_transaction
      instance.run_query(id, *statements).tap do
        instance.rollback_transaction(id)
      end
    end
    let(:statements) do
      [
        # Create a new user named Klaus
        {
          statement: 'CREATE (n:User { name: $name })',
          parameters: { name: 'Klaus' }
        },
        # Create a new user named Bernd
        {
          statement: 'CREATE (n:User { name: $name })',
          parameters: { name: 'Bernd' }
        },
        # Create a relationship between Klaus and Bernd
        # to signalize they are friends
        {
          statement: 'MATCH (a:User), (b:User) ' \
                     'WHERE a.name = $name_a AND b.name = $name_b ' \
                     'CREATE (a)-[:FRIEND_OF]->(b)',
          parameters: { name_a: 'Klaus', name_b: 'Bernd' }
        },
        # Then ask for all friends of Klaus
        {
          statement: 'MATCH (l:User { name: $name })-[:FRIEND_OF]->(r:User) ' \
                     'RETURN r.name AS name',
          parameters: { name: 'Klaus' }
        }
      ]
    end

    it 'returns 4 results' do
      expect(action.count).to be_eql(4)
    end

    it 'returns the expected results (first 3)' do
      expect(action[0..2].map(&:count)).to all(be_eql(0))
    end

    it 'returns the expected results (last)' do
      expect(action.last.value).to be_eql('Bernd')
    end

    it 'does not write the data actually' do
      count = instance.one_shot_transaction(
        { statement: 'MATCH (n:User) RETURN count(n)' }
      ).first.value
      expect(count).to be_eql(0)
    end
  end

  describe '.statement_payloads' do
    let(:action) { ->(*args) { described_class.statement_payloads(*args) } }

    it 'returns an Array' do
      expect(action.call).to be_a(Array)
    end

    it 'returns an array with the converted statements' do
      expect(action.call(['a', { a: true }], ['b', {}]).count).to be_eql(2)
    end

    it 'returns an array of converted statement Hashes' do
      expect(action.call(['a', { a: true }], ['b', {}])).to all(be_a(Hash))
    end
  end

  describe '.statement_payload' do
    let(:action) do
      ->(cypher, **args) { described_class.statement_payload(cypher, **args) }
    end

    context 'without parameters' do
      let(:action) { super().call('cypher') }

      it 'returns a Hash instance' do
        expect(action).to be_a(Hash)
      end

      it 'returns a correct statement structure' do
        expect(action).to match(statement: 'cypher', parameters: {})
      end
    end

    context 'with user parameters only' do
      let(:action) { super().call('cypher', a: { b: true }) }

      it 'returns a Hash instance' do
        expect(action).to be_a(Hash)
      end

      it 'returns a correct statement structure' do
        expect(action).to \
          match(statement: 'cypher', parameters: { a: { b: true } })
      end
    end

    context 'with statistics parameter' do
      let(:action) { super().call('cypher', with_stats: true, a: { b: true }) }

      it 'returns a Hash instance' do
        expect(action).to be_a(Hash)
      end

      it 'returns a correct statement structure' do
        expect(action).to \
          match(statement: 'cypher',
                includeStats: true,
                parameters: { a: { b: true } })
      end
    end

    context 'with graph output parameter' do
      let(:action) { super().call('cypher', result_as_graph: true, a: 1) }

      it 'returns a Hash instance' do
        expect(action).to be_a(Hash)
      end

      it 'returns a correct statement structure' do
        expect(action).to \
          match(statement: 'cypher',
                resultDataContents: %w[row graph],
                parameters: { a: 1 })
      end
    end
  end

  describe '#one_shot_transaction' do
    let(:action) { ->(*args) { instance.one_shot_transaction(*args) } }
    let(:body) { '{}' }
    let(:req_body) { { statements: statements }.to_json }

    before do
      allow(connection).to receive(:headers).and_return(connection)
      allow(connection).to receive(:post).and_return(response)
    end

    context 'without statements' do
      it 'raises an ArgumentError' do
        expect { action.call }.to \
          raise_error(ArgumentError, /No statements given/)
      end
    end

    it 'wraps the user block inside a #handle_transaction call' do
      expect(instance).to receive(:handle_transaction).with(tx_id: 'commit')
      action.call(*statements)
    end

    it 'sends a HTTP POST request' do
      expect(connection).to \
        receive(:post).with('/db/neo4j/tx/commit', body: req_body)
                      .and_return(response)
      action.call(*statements)
    end

    describe 'logging' do
      before do
        Boltless.configuration.query_log_enabled = true
      end

      it 'logs the one-shot transaction' do
        action.call(statements.first)
        expect(log).to match(/\[tx:write:one-shot\] \(.*ms\) RETURN 1/)
      end
    end
  end

  describe '#begin_transaction' do
    let(:action) { ->(*args) { instance.begin_transaction(*args) } }
    let(:body) { '{}' }

    before do
      allow(connection).to receive(:headers).and_return(connection)
      allow(connection).to receive(:post).and_return(response)
    end

    it 'sets the correct access mode header' do
      expect(connection).to \
        receive(:headers).with('Access-Mode' => 'WRITE').and_call_original
      action.call
    end

    context 'with an unsuccessful response' do
      let(:http_status_code) { 500 }
      let(:body) { 'Something went wrong' }

      it 'raises an Boltless::Errors::TransactionBeginError' do
        expect { action.call }.to \
          raise_error(Boltless::Errors::TransactionBeginError,
                      /Something went wrong/)
      end
    end

    context 'with an successful response without Location header' do
      let(:body) { '{"some":"thing"}' }

      it 'raises an Boltless::Errors::TransactionBegin' do
        expect { action.call }.to \
          raise_error(Boltless::Errors::TransactionBeginError,
                      /{"some":"thing"}/)
      end
    end

    context 'with an successful response with Location header' do
      let(:headers) { { 'location' => 'http://neo4j:7474/db/neo4j/tx/3894' } }

      it 'returns the correct transaction identifier' do
        expect(action.call).to be_eql(3894)
      end
    end

    describe 'logging' do
      let(:headers) { { 'location' => 'http://neo4j:7474/db/neo4j/tx/3894' } }

      before { Boltless.configuration.query_log_enabled = :debug }

      it 'logs the start of the transaction' do
        action.call
        expect(log).to match(/\[tx:write:3894 rq:1\] \(.*ms\) BEGIN/)
      end

      it 'logs the start of the transaction (debug)' do
        action.call
        expect(log).to match(/\[tx:write:tbd rq:1\] BEGIN/)
      end
    end
  end

  describe '#run_query' do
    let(:action) do
      proc do |*args|
        instance.run_query(8134, *args)
      end
    end
    let(:body) { '{}' }

    it 'wraps the user block inside a #handle_transaction call' do
      expect(instance).to receive(:handle_transaction).with(tx_id: 8134)
      action.call(*statements)
    end

    context 'without statements' do
      it 'raises an ArgumentError' do
        expect { action.call }.to \
          raise_error(ArgumentError, /No statements given/)
      end
    end

    context 'with statements' do
      let(:req_body) { { statements: statements }.to_json }

      it 'sends a HTTP POST request' do
        expect(connection).to \
          receive(:post).with('/db/neo4j/tx/8134', body: req_body)
                        .and_return(response)
        action.call(*statements)
      end
    end

    describe 'logging' do
      before do
        allow(connection).to receive(:post).and_return(response)
        Boltless.configuration.query_log_enabled = true
      end

      it 'logs the query within the transaction' do
        action.call(statements.first)
        expect(log).to match(/\[tx:write:8134 rq:1\] \(.*ms\) RETURN 1/)
      end
    end
  end

  describe '#commit_transaction' do
    let(:action) do
      proc do |*args|
        instance.commit_transaction(8134, *args)
      end
    end
    let(:body) { '{}' }

    it 'wraps the user block inside a #handle_transaction call' do
      expect(instance).to receive(:handle_transaction).with(tx_id: 8134)
      action.call
    end

    context 'without finalizing statements' do
      it 'sends a HTTP POST request' do
        opts = {}
        expect(connection).to \
          receive(:post).with('/db/neo4j/tx/8134/commit', **opts)
                        .and_return(response)
        action.call
      end
    end

    context 'with finalizing statements' do
      let(:statements) do
        [
          {
            statement: 'RETURN 1',
            parameters: {}
          },
          {
            statement: 'RETURN $arg',
            parameters: { arg: 2 }
          }
        ]
      end
      let(:req_body) { { statements: statements }.to_json }

      it 'sends a HTTP POST request' do
        expect(connection).to \
          receive(:post).with('/db/neo4j/tx/8134/commit', body: req_body)
                        .and_return(response)
        action.call(*statements)
      end
    end

    describe 'logging' do
      before do
        Boltless.configuration.query_log_enabled = true
        allow(connection).to receive(:post).and_return(response)
      end

      it 'logs the commit' do
        action.call
        expect(log).to match(/\[tx:write:8134 rq:1\] \(.*ms\) COMMIT/)
      end
    end
  end

  describe '#rollback_transaction' do
    let(:action) do
      proc do
        instance.rollback_transaction(8134)
      end
    end
    let(:body) { '{}' }

    it 'wraps the user block inside a #handle_transaction call' do
      expect(instance).to receive(:handle_transaction).with(tx_id: 8134)
      action.call
    end

    it 'sends a HTTP DELETE request' do
      expect(connection).to \
        receive(:delete).with('/db/neo4j/tx/8134').and_return(response)
      action.call
    end

    describe 'logging' do
      before do
        Boltless.configuration.query_log_enabled = true
        allow(connection).to receive(:delete).and_return(response)
      end

      it 'logs the rollback' do
        action.call
        expect(log).to match(/\[tx:write:8134 rq:1\] \(.*ms\) ROLLBACK/)
      end
    end
  end

  describe '#handle_transaction' do
    let(:action) do
      proc do |&block|
        instance.handle_transaction(tx_id: tx_id) do |*args|
          block&.call(*args)
          response
        end
      end
    end
    let(:tx_id) { 8134 }
    let(:body) { '{}' }

    it 'yields the given block' do
      expect { |control| action.call(&control) }.to yield_control
    end

    it 'passes down the transaction path to the given block' do
      expect { |control| action.call(&control) }.to \
        yield_with_args('/db/neo4j/tx/8134')
    end

    context 'with a 404 HTTP status code' do
      let(:http_status_code) { 404 }
      let(:body) { 'Not found' }

      it 'raises a Boltless::Errors::TransactionNotFoundError' do
        expect { action.call }.to \
          raise_error(Boltless::Errors::TransactionNotFoundError,
                      /Not found/)
      end
    end

    context 'with an unsuccessful status code' do
      let(:http_status_code) { 500 }
      let(:body) { 'Unknown error happend' }

      it 'raises a Boltless::Errors::TransactionRollbackError' do
        expect { action.call }.to \
          raise_error(Boltless::Errors::TransactionRollbackError,
                      /Unknown error happend/)
      end
    end

    context 'with a successful status code' do
      let(:http_status_code) { 200 }
      let(:body) { '{}' }

      it 'calls the #handle_response_body method' do
        expect(instance).to \
          receive(:handle_response_body).with(response, tx_id: 8134)
        action.call
      end
    end
  end

  describe '#handle_response_body' do
    let(:action) { instance.handle_response_body(response, tx_id: tx_id) }
    let(:safe_action) { suppress(StandardError) { action } }

    context 'with invalid JSON response' do
      let(:body) { '<html>Service unavailable</html>' }

      it 'raises a Boltless::Errors::InvalidJsonError' do
        expect { action }.to \
          raise_error(Boltless::Errors::InvalidJsonError,
                      /JSON document has an improper structure/i)
      end
    end

    context 'with an empty response' do
      let(:body) { '{}' }

      it 'does not raise errors' do
        expect { action }.not_to raise_error
      end

      it 'returns an empty array' do
        expect(action).to match_array([])
      end
    end

    context 'with results' do
      let(:body) { { results: raw_results }.to_json }
      let(:raw_results) do
        [
          {
            columns: %w[a b],
            data: [
              {
                row: [1, 2],
                meta: [nil, nil]
              }
            ]
          }
        ]
      end

      context 'with raw results' do
        let(:instance) { new_instance[raw_results: true] }

        it 'does not raise errors' do
          expect { action }.not_to raise_error
        end

        it 'returns the untouched response' do
          expect(action).to match_array(raw_results)
        end
      end

      context 'with restructured results' do
        let(:instance) { new_instance[raw_results: false] }

        it 'does not raise errors' do
          expect { action }.not_to raise_error
        end

        it 'returns the restructured response' do
          expect(action).to all(be_a(Boltless::Result))
        end
      end
    end

    context 'with a single error' do
      let(:tx_id) { 777 }
      let(:body) do
        {
          errors: [
            {
              code: 'com.neo4j.some.thing',
              message: 'NullPointerException'
            }
          ]
        }.to_json
      end
      let(:error_message) do
        'Transaction \(777\) rolled back due to errors \(1\)' \
          '.*NullPointerException \(com.neo4j.some.thing\)'
      end

      it 'raises a Boltless::Errors::TransactionRollbackError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionRollbackError,
                      /#{error_message}/m)
      end

      it 'allows to access the wrapped error' do
        expect(catch_exception.call { action }.errors.first).to \
          be_a(Boltless::Errors::ResponseError)
      end
    end

    context 'with a multiple errors' do
      let(:tx_id) { 666 }
      let(:body) do
        {
          errors: [
            {
              code: 'com.neo4j.some.thing1',
              message: 'StringIndexOutOfBoundsException'
            },
            {
              code: 'com.neo4j.some.thing2',
              message: 'NullPointerException'
            }
          ]
        }.to_json
      end
      let(:error_message) do
        'Transaction \(666\) rolled back due to errors \(2\)' \
          '.*StringIndexOutOfBoundsException \(com.neo4j.some.thing1\)' \
          '.*NullPointerException \(com.neo4j.some.thing2\)'
      end

      it 'raises a Boltless::Errors::TransactionRollbackError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionRollbackError,
                      /#{error_message}/m)
      end

      it 'allows to access the wrapped errors' do
        expect(catch_exception.call { action }.errors).to \
          all(be_a(Boltless::Errors::ResponseError))
      end
    end

    context 'with a custom raw response handler' do
      let(:body) { { test: true }.to_json }
      let(:handler) { proc { 'test!' } }

      before { Boltless.configuration.raw_response_handler = handler }

      it 'uses the raw response handler return value for parsing' do
        expect(FastJsonparser).to \
          receive(:parse).with('test!').once.and_call_original
        safe_action
      end

      it 'passes over the raw response body' do
        Boltless.configuration.raw_response_handler = proc do |body, _res|
          expect(body).to be_eql('{"test":true}')
          body
        end
        action
      end

      it 'passes over the raw response' do
        Boltless.configuration.raw_response_handler = proc do |body, res|
          expect(res).to be_a(HTTP::Response)
          body
        end
        action
      end
    end
  end

  describe '#serialize_body' do
    let(:action) { ->(obj) { instance.serialize_body(obj) } }

    context 'with an Array' do
      it 'returns the expected JSON representation' do
        expect(action[[1, [2]]]).to be_eql('[1,[2]]')
      end
    end

    context 'with a Hash' do
      it 'returns the expected JSON representation' do
        expect(action[{ a: { b: true } }]).to be_eql('{"a":{"b":true}}')
      end
    end

    context 'with a String' do
      it 'returns the expected JSON representation' do
        expect(action['test']).to be_eql('"test"')
      end
    end
  end

  describe '#handle_transport_errors' do
    let(:action) do
      instance.handle_transport_errors do
        raise HTTP::Error, 'Something went wrong'
      end
    end

    it 're-raises any HTTP::Error as Boltless::Errors::RequestError' do
      expect { action }.to raise_error(Boltless::Errors::RequestError,
                                       /Something went wrong/)
    end
  end

  describe '#log_query' do
    let(:action) do
      proc do |&block|
        block ||= user_block
        instance.log_query(tx_id, *statements, &block)
      end
    end
    let(:tx_id) { 8934 }
    let(:statements) do
      [{ statement: 'RETURN date()' }, { statement: 'RETURN 1' }]
    end
    let(:user_block) { -> { 923 } }

    before do
      Boltless.configuration.query_log_enabled = conf_value
    end

    context 'when query logging is disabled (false)' do
      let(:conf_value) { false }

      it 'yields the user block' do
        expect { |control| action[&control] }.to yield_control
      end

      it 'returns the result of the user block' do
        expect(action.call).to be_eql(923)
      end

      it 'does not change the request counter' do
        expect { action.call }.not_to \
          change { instance.instance_variable_get(:@requests_done) }.from(0)
      end

      it 'does not call the logger' do
        expect(Boltless.logger).not_to receive(:debug)
        action.call
      end
    end

    context 'when query logging is enabled (true)' do
      let(:conf_value) { true }

      it 'yields the user block' do
        expect { |control| action[&control] }.to yield_control
      end

      it 'returns the result of the user block' do
        expect(action.call).to be_eql(923)
      end

      it 'change the request counter' do
        expect { action.call }.to \
          change { instance.instance_variable_get(:@requests_done) }
          .from(0).to(1)
      end

      it 'calls the logger' do
        expect(Boltless.logger).to receive(:debug).once
        action.call
      end

      it 'calls the logger without arguments' do
        expect(Boltless.logger).to receive(:debug).with(no_args)
        action.call
      end

      it 'calls the logger with a block' do
        allow(Boltless.logger).to receive(:debug) do |&block|
          expect(block).to be_a(Proc)
        end
        action.call
      end

      it 'calls the #generate_log_str with the transaction identifier' do
        expect(instance).to \
          receive(:generate_log_str).with(8934, anything, anything, anything)
        action.call
      end

      it 'calls the #generate_log_str with the mesaured duration' do
        expect(instance).to \
          receive(:generate_log_str).with(anything, Float, anything, anything)
        action.call
      end

      it 'calls the #generate_log_str with the statements' do
        expect(instance).to \
          receive(:generate_log_str).with(anything, anything, *statements)
        action.call
      end

      context 'with :begin as transaction identifier' do
        let(:tx_id) { :begin }
        let(:statements) { [{ statement: 'RETURN date()' }] }

        it 'calls the #generate_log_str with block result ' \
           'as transaction identifier' do
          expect(instance).to \
            receive(:generate_log_str).with(923, anything, anything)
          action.call
        end
      end
    end

    context 'when query logging is enabled (:debug)' do
      let(:conf_value) { :debug }

      it 'yields the user block' do
        expect { |control| action[&control] }.to yield_control
      end

      it 'returns the result of the user block' do
        expect(action.call).to be_eql(923)
      end

      it 'calls the logger twice' do
        expect(Boltless.logger).to receive(:debug).twice
        action.call
      end

      describe 'the extra debug logging call' do
        # NOTE: We prepare to run only the "half" of the method, by raising
        # within the user block. This results in a single +#generate_log_str+
        # call, the one we want to inspect. Other we would have to distinguish
        # them with more complex logic.
        let(:action) do
          saction = super()
          -> { suppress(StandardError) { saction.call } }
        end
        let(:user_block) { -> { raise } }

        it 'calls the logger' do
          expect(Boltless.logger).to receive(:debug).once
          action.call
        end

        it 'calls the logger without arguments' do
          expect(Boltless.logger).to receive(:debug).with(no_args)
          action.call
        end

        it 'calls the logger with a block' do
          allow(Boltless.logger).to receive(:debug) do |&block|
            expect(block).to be_a(Proc)
          end
          action.call
        end

        it 'calls the #generate_log_str with the transaction identifier' do
          expect(instance).to \
            receive(:generate_log_str).with(8934, anything, anything, anything)
          action.call
        end

        it 'calls the #generate_log_str without a duration' do
          expect(instance).to \
            receive(:generate_log_str).with(anything, nil, anything, anything)
          action.call
        end

        it 'calls the #generate_log_str with the statements' do
          expect(instance).to \
            receive(:generate_log_str).with(anything, anything, *statements)
          action.call
        end

        context 'with :begin as transaction identifier' do
          let(:tx_id) { :begin }
          let(:statements) { [{ statement: 'RETURN date()' }] }

          it 'calls the #generate_log_str with "tbd" ' \
             'as transaction identifier' do
            expect(instance).to \
              receive(:generate_log_str).with('tbd', anything, anything)
            action.call
          end
        end
      end
    end
  end

  describe '#generate_log_str' do
    let(:action) do
      instance.generate_log_str(tx_id, duration, *statements).uncolorize
    end
    let(:tx_id) { 594 }
    let(:duration) { 9.5 }
    let(:statements) do
      [
        {
          statement: 'RETURN $arg',
          parameters: { arg: 2 }
        }
      ]
    end

    it 'follows the log pattern' do
      expect(action).to \
        match(/^Boltless \[tx:\w+:\d+ rq:\d+\] \([\d.]+ms\) .*/)
    end

    context 'with read access mode' do
      let(:instance) { new_instance[access_mode: :read] }

      it 'includes the access mode of the request' do
        expect(action).to include('[tx:read:')
      end
    end

    context 'with write access mode' do
      let(:instance) { new_instance[access_mode: :write] }

      it 'includes the access mode of the request' do
        expect(action).to include('[tx:write:')
      end
    end

    context 'with a transaction identifier' do
      it 'includes the transaction identifier inside the tag' do
        expect(action).to include('[tx:write:594 ')
      end

      it 'includes the current request count' do
        instance.instance_variable_set(:@requests_done, 8)
        expect(action).to include('[tx:write:594 rq:8]')
      end
    end

    context 'without a transaction identifier' do
      let(:tx_id) { nil }

      it 'falls back to the one-shot transaction identifier' do
        expect(action).to include('[tx:write:one-shot]')
      end
    end

    context 'with a duration' do
      it 'includes the formatted duration' do
        expect(action).to include('] (9.5ms) RETURN')
      end
    end

    context 'without a duration' do
      let(:duration) { nil }

      it 'skips the duration between tag and statement' do
        expect(action).to include('] RETURN')
      end
    end

    context 'with a single statement' do
      it 'returns a string with a single line' do
        expect(action.lines.count).to be_eql(1)
      end

      it 'resolves the Cypher statement with the parameters' do
        expect(action).to include('RETURN 2')
      end
    end

    context 'with multiple statements' do
      let(:statements) do
        [
          {
            statement: 'RETURN $arg',
            parameters: { arg: 2 }
          },
          {
            statement: 'MATCH (n:User { name: $name }) RETURN count(n)',
            parameters: { name: 'Klaus' }
          }
        ]
      end

      it 'returns a string with two lines' do
        expect(action.lines.count).to be_eql(2)
      end

      it 'resolves the Cypher statement with the parameters (1)' do
        expect(action).to include('RETURN 2')
      end

      it 'resolves the Cypher statement with the parameters (2)' do
        expect(action).to \
          include('MATCH (n:User { name: "Klaus" }) RETURN count(n)')
      end
    end

    context 'with a mult-line Cypher statement' do
      let(:statements) do
        [
          {
            statement: <<~CYPHER,
              MATCH (n:User { name: $name })
              RETURN count(n) // Nice comment
            CYPHER
            parameters: { name: 'Klaus' }
          }
        ]
      end

      it 'flattens multi-line Cypher statements to a single line each' do
        expect(action).to \
          include('MATCH (n:User { name: "Klaus" }) RETURN count(n)')
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
