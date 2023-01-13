# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boltless::Transaction do
  let(:new_instance) { ->(**args) { described_class.new(connection, **args) } }
  let(:instance) { new_instance.call }
  let(:connection) { Boltless.connection_pool.checkout }
  let(:request) { instance.instance_variable_get(:@request) }
  let(:req_err) { ->(*) { raise Boltless::Errors::RequestError, 'test' } }
  let(:res_err) { ->(*) { raise Boltless::Errors::ResponseError, 'test' } }
  let(:raw_state) { nil }

  before do
    # Only force the raw state when it is configured
    instance.instance_variable_set(:@raw_state, raw_state) if raw_state
  end

  describe 'full workflow' do
    let(:opts) { {} }
    let(:failed_action) do
      tx = new_instance[**opts]
      tx.begin
      tx.run('CREATE (n:User { name: $name })', name: 'Klaus')
      tx.run('SOME THING!')
      tx.commit
    end
    let(:check_action) do
      tx = new_instance[**opts]
      tx.begin
      tx.run('MATCH (n:User) RETURN n.name').tap do
        tx.commit
      end
    end
    let(:write_action) do
      tx = new_instance[**opts]
      tx.begin!
      tx.run!('CREATE (n:User { name: $name })', name: 'Klaus')
      tx.commit!
    end

    it 'rolls back the transaction on errors' do
      failed_action
      expect(check_action.count).to be_eql(0)
    end

    it 'returns a mapped result' do
      expect(check_action).to be_a(Boltless::Result)
    end

    describe 'with raw results' do
      let(:opts) { { raw_results: true } }

      it 'returns an unmapped result' do
        expect(check_action).to be_a(Hash)
      end
    end

    describe 'with the read access mode' do
      let(:opts) { { access_mode: :read } }

      it 'does not allow us to perform write operations' do
        expect { write_action }.to \
          raise_error(Boltless::Errors::TransactionRollbackError,
                      /Neo.ClientError.Request.Invalid/i)
      end
    end
  end

  describe 'delegations' do
    it 'allows to access the #build_cypher utility' do
      expect(instance.respond_to?(:build_cypher)).to be_eql(true)
    end
  end

  describe '#initialize' do
    it 'passes down the connection to the request' do
      expect(Boltless::Request).to \
        receive(:new).with(connection, anything)
      described_class.new(connection)
    end

    it 'passes down the access mode to the request' do
      expect(Boltless::Request).to \
        receive(:new).with(connection, a_hash_including(access_mode: :read))
      described_class.new(connection, access_mode: :read)
    end

    it 'passes down the database to the request' do
      expect(Boltless::Request).to \
        receive(:new).with(connection, a_hash_including(database: 'test'))
      described_class.new(connection, database: 'test')
    end

    it 'passes down the raw results flag to the request' do
      expect(Boltless::Request).to \
        receive(:new).with(connection, a_hash_including(raw_results: true))
      described_class.new(connection, raw_results: true)
    end

    context 'with unknown access mode' do
      it 'raises an ArgumentError' do
        expect { described_class.new(connection, access_mode: :unknown) }.to \
          raise_error(
            ArgumentError,
            /Unknown access mode 'unknown'.*use ':read' or ':write'/i
          )
      end
    end
  end

  describe '#access_mode' do
    let(:action) { instance.access_mode }

    context 'when not explictly configured' do
      it 'returns write' do
        expect(action).to be_eql(:write)
      end
    end

    context 'when initialized with read' do
      let(:instance) { new_instance[access_mode: :read] }

      it 'returns read' do
        expect(action).to be_eql(:read)
      end
    end

    context 'when initialized with write' do
      let(:instance) { new_instance[access_mode: :write] }

      it 'returns write' do
        expect(action).to be_eql(:write)
      end
    end
  end

  describe '#id' do
    let(:action) { instance.id }

    context 'when not yet started' do
      it 'returns nil' do
        expect(action).to be_nil
      end
    end

    context 'when started' do
      before { instance.begin! }

      it 'returns an Integer' do
        expect(action).to be_a(Integer)
      end
    end
  end

  describe '#raw_state' do
    let(:action) { instance.raw_state }

    it 'returns an Symbol' do
      expect(action).to be_a(Symbol)
    end

    describe 'after initialization' do
      it 'returns not_yet_started' do
        expect(action).to be_eql(:not_yet_started)
      end
    end
  end

  describe '#state' do
    let(:action) { instance.state }

    it 'returns an ActiveSupport::StringInquirer' do
      expect(action).to be_a(ActiveSupport::StringInquirer)
    end

    describe 'after initialization' do
      it 'returns not_yet_started' do
        expect(action).to be_eql('not_yet_started')
      end
    end
  end

  describe '#begin!' do
    let(:action) { instance.begin! }
    let(:instance) { new_instance[access_mode: :read] }

    before { allow(request).to receive(:begin_transaction) }

    context 'when the transaction is not in a usable state' do
      let(:raw_state) { :closed }

      it 'raises a Boltless::Errors::TransactionInBadStateError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionInBadStateError,
                      /Transaction already closed/i)
      end
    end

    it 'call the #begin_transaction on the request' do
      expect(request).to receive(:begin_transaction).once
      action
    end

    it 'returns true' do
      expect(action).to be_eql(true)
    end

    it 'switches the state to open' do
      expect { action }.to \
        change(instance, :state).from('not_yet_started').to('open')
    end
  end

  describe '#begin' do
    let(:action) { instance.begin }

    context 'when the transaction is not in a usable state' do
      let(:raw_state) { :closed }

      it 'returns false' do
        expect(action).to be_eql(false)
      end
    end

    it 'wraps the bang-variant in a #handle_errors call' do
      expect(instance).to receive(:handle_errors).with(false)
      action
    end

    context 'with errors' do
      before { allow(instance).to receive(:begin!, &res_err) }

      it 'returns false' do
        expect(action).to be_eql(false)
      end
    end

    context 'without errors' do
      before { allow(request).to receive(:begin_transaction) }

      it 'returns true' do
        expect(action).to be_eql(true)
      end

      it 'switches the state to open' do
        expect { action }.to \
          change(instance, :state).from('not_yet_started').to('open')
      end
    end
  end

  describe '#run!' do
    let(:action) { instance.run!('RETURN 1') }

    context 'when the transaction is not in a usable state' do
      let(:raw_state) { :closed }

      it 'raises a Boltless::Errors::TransactionInBadStateError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionInBadStateError,
                      /Transaction not open/i)
      end
    end

    context 'with open state' do
      before { instance.begin! }

      it 'calls the #run_query on the request' do
        expect(request).to \
          receive(:run_query).with(instance.id, Hash).and_return([])
        action
      end

      it 'returns the result' do
        res = instance.run!('RETURN date() AS date')
        expect(res.value).to be_eql(Date.today.to_s)
      end
    end
  end

  describe '#run' do
    let(:action) { instance.run('RETURN date()') }
    let(:raw_state) { :open }

    context 'when the transaction is not in a usable state' do
      let(:raw_state) { :closed }

      it 'returns nil' do
        expect(action).to be_eql(nil)
      end
    end

    it 'wraps the bang-variant in a #handle_errors call' do
      expect(instance).to receive(:handle_errors)
      action
    end

    context 'with errors' do
      before { allow(instance).to receive(:run!, &res_err) }

      it 'returns nil' do
        expect(action).to be_eql(nil)
      end
    end

    context 'without errors' do
      before { allow(request).to receive(:run_query).and_return([123]) }

      it 'returns an the first result' do
        expect(action).to be_eql(123)
      end
    end
  end

  describe '#run_in_batch!' do
    let(:action) { instance.run_in_batch!(['RETURN 1'], ['RETURN date()']) }

    context 'when the transaction is not in a usable state' do
      let(:raw_state) { :closed }

      it 'raises a Boltless::Errors::TransactionInBadStateError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionInBadStateError,
                      /Transaction not open/i)
      end
    end

    context 'with open state' do
      let(:statements) do
        [
          {
            statement: 'RETURN 1',
            parameters: {}
          },
          {
            statement: 'RETURN date()',
            parameters: {}
          }
        ]
      end

      before { instance.begin! }

      it 'calls the #run_query on the request' do
        expect(request).to receive(:run_query).with(instance.id, *statements)
        action
      end

      it 'returns two results (one for each statement)' do
        expect(action.count).to be_eql(2)
      end

      it 'returns the correct result (first statement)' do
        expect(action.first.value).to be_eql(1)
      end

      it 'returns the correct result (second statement)' do
        expect(action.last.value).to be_eql(Date.today.to_s)
      end
    end
  end

  describe '#run_in_batch' do
    let(:action) { instance.run_in_batch(['RETURN date()'], ['RETURN 1']) }
    let(:raw_state) { :open }

    context 'when the transaction is not in a usable state' do
      let(:raw_state) { :closed }

      it 'returns nil' do
        expect(action).to be_eql(nil)
      end
    end

    it 'wraps the bang-variant in a #handle_errors call' do
      expect(instance).to receive(:handle_errors)
      action
    end

    context 'with errors' do
      before { allow(instance).to receive(:run_in_batch!, &res_err) }

      it 'returns nil' do
        expect(action).to be_eql(nil)
      end
    end

    context 'without errors' do
      before { allow(request).to receive(:run_query).and_return([]) }

      it 'returns an empty array' do
        expect(action).to match_array([])
      end
    end
  end

  describe '#commit!' do
    let(:action) { instance.commit! }
    let(:instance) { new_instance[access_mode: :read] }

    context 'when the transaction is not in a usable state' do
      let(:raw_state) { :closed }

      it 'raises a Boltless::Errors::TransactionInBadStateError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionInBadStateError,
                      /Transaction not open/i)
      end
    end

    context 'with open state' do
      before { instance.begin! }

      it 'calls the #commit_transaction on the request' do
        expect(request).to receive(:commit_transaction).with(instance.id)
        action
      end

      it 'allows to send finalizing statements' do
        res = instance.commit!(['RETURN date() AS date'])
        expect(res.first.value).to be_eql(Date.today.to_s)
      end

      it 'switches the state to closed' do
        expect { action }.to \
          change(instance, :state).from('open').to('closed')
      end
    end
  end

  describe '#commit' do
    let(:action) { instance.commit }
    let(:raw_state) { :open }

    context 'when the transaction is not in a usable state' do
      let(:raw_state) { :closed }

      it 'returns nil' do
        expect(action).to be_eql(nil)
      end
    end

    it 'wraps the bang-variant in a #handle_errors call' do
      expect(instance).to receive(:handle_errors)
      action
    end

    context 'with errors' do
      before { allow(instance).to receive(:commit!, &res_err) }

      it 'returns nil' do
        expect(action).to be_eql(nil)
      end
    end

    context 'without errors' do
      before { allow(request).to receive(:commit_transaction).and_return([]) }

      it 'returns an empty array' do
        expect(action).to match_array([])
      end

      it 'switches the state to closed' do
        expect { action }.to \
          change(instance, :state).from('open').to('closed')
      end
    end
  end

  describe '#rollback!' do
    let(:action) { instance.rollback! }
    let(:instance) { new_instance[access_mode: :read] }

    context 'when the transaction is not in a usable state' do
      let(:raw_state) { :closed }

      it 'raises a Boltless::Errors::TransactionInBadStateError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionInBadStateError,
                      /Transaction not open/i)
      end
    end

    context 'with open state' do
      before { instance.begin! }

      it 'calls the #rollback_transaction on the request' do
        expect(request).to receive(:rollback_transaction).with(instance.id)
        action
      end

      it 'returns true' do
        expect(action).to be_eql(true)
      end

      it 'switches the state to closed' do
        expect { action }.to \
          change(instance, :state).from('open').to('closed')
      end
    end
  end

  describe '#rollback' do
    let(:action) { instance.rollback }
    let(:raw_state) { :open }

    context 'when the transaction is not in a usable state' do
      let(:raw_state) { :closed }

      it 'returns false' do
        expect(action).to be_eql(false)
      end
    end

    it 'wraps the bang-variant in a #handle_errors call' do
      expect(instance).to receive(:handle_errors).with(false)
      action
    end

    context 'with errors' do
      before { allow(instance).to receive(:rollback!, &res_err) }

      it 'returns false' do
        expect(action).to be_eql(false)
      end
    end

    context 'without errors' do
      before { allow(request).to receive(:rollback_transaction) }

      it 'returns true' do
        expect(action).to be_eql(true)
      end

      it 'switches the state to closed' do
        expect { action }.to \
          change(instance, :state).from('open').to('closed')
      end
    end
  end

  describe '#handle_errors' do
    let(:action) { ->(*args, &block) { instance.handle_errors(*args, &block) } }

    it 'yields the user given block' do
      expect { |control| action.call(&control) }.to yield_control
    end

    it 'rescues Boltless::Errors::RequestError' do
      expect { action.call(&req_err) }.not_to raise_error
    end

    it 'rescues Boltless::Errors::ResponseError' do
      expect { action.call(&res_err) }.not_to raise_error
    end

    it 'does not rescue ArgumentError' do
      expect { action.call { raise ArgumentError } }.to \
        raise_error(ArgumentError)
    end

    it 'returns the given error result in case of errors (non-proc)' do
      expect(action.call(true, &res_err)).to be_eql(true)
    end

    it 'returns the given error result in case of errors (proc)' do
      err_res = ->(e) { "Err: #{e.message}" }
      expect(action.call(err_res, &res_err)).to be_eql('Err: test')
    end

    it 'returns the result of the user given block when no errors occur' do
      expect(action.call { 123 }).to be_eql(123)
    end

    it 'switches the state to closed on errors' do
      expect { action.call(&res_err) }.to \
        change(instance, :state).from('not_yet_started').to('closed')
    end

    it 'calls #cleanup on errors' do
      expect(instance).to receive(:cleanup).once
      action.call(&res_err)
    end
  end

  describe '#cleanup' do
    let(:action) { instance.cleanup }

    it 'clears the request instance variable' do
      expect { action }.to \
        change { instance.instance_variable_get(:@request) }
        .from(Boltless::Request).to(nil)
    end

    it 'changes the state to cleaned' do
      expect { action }.to \
        change(instance, :state).from('not_yet_started').to('cleaned')
    end
  end
end
