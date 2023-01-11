# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boltless::Extensions::Transactions do
  let(:described_class) { Boltless }
  let(:access_mode) { :write }
  let(:statement_payload) do
    cypher, params = statement
    [cypher, (params || {}).merge(opts)]
  end
  let(:statement_payloads) do
    statements.map do |(cypher, params)|
      [cypher, (params || {}).merge(opts)]
    end
  end
  let(:opts) { {} }
  let(:create_users) do
    Boltless.one_shot! do |tx|
      %w[Bernd Klaus Uwe Monika].each do |name|
        tx.add('CREATE (n:User { name: $name })', name: name)
      end
    end
  end
  let(:create_user_statement) do
    ['CREATE (n:User { name: $name })', { name: 'Silke' }]
  end
  let(:fetch_users_statement) do
    ['MATCH (n:User) RETURN n.name AS name', {}]
  end
  let(:count_users_statement) do
    ['MATCH (n:User) RETURN count(n) AS count', {}]
  end
  let(:statement_with_syntax_errors) do
    ['SOME THING!', {}]
  end
  let(:fetch_date_statement) do
    ['RETURN date() AS date', {}]
  end
  let(:fetch_static_number_statement) do
    ['RETURN 9867 AS number', {}]
  end

  before { clean_neo4j! }

  describe '.execute!' do
    let(:action) do
      cypher, args = statement_payload
      described_class.execute!(cypher, **args)
    end

    context 'with Cypher syntax errors' do
      let(:statement) { statement_with_syntax_errors }

      it 'raises an Boltless::Errors::TransactionRollbackError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionRollbackError,
                      /invalid input/i)
      end
    end

    context 'with multiple rows' do
      let(:statement) { fetch_users_statement }

      before { create_users }

      it 'returns the user names' do
        expect(action.pluck(:name)).to \
          match_array(%w[Bernd Klaus Uwe Monika])
      end

      it 'returns a Boltless::Result' do
        expect(action).to be_a(Boltless::Result)
      end
    end

    context 'with write operations on a read-only transaction' do
      let(:statement) { create_user_statement }
      let(:opts) { { access_mode: :read } }

      it 'raises an Boltless::Errors::TransactionRollbackError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionRollbackError,
                      /Neo.ClientError.Request.Invalid/i)
      end
    end
  end

  describe '.execute' do
    let(:action) do
      cypher, args = statement_payload
      described_class.execute(cypher, **args)
    end

    context 'with Cypher syntax errors' do
      let(:statement) { statement_with_syntax_errors }

      it 'returns nil' do
        expect(action).to be_nil
      end
    end

    context 'with multiple rows' do
      let(:statement) { fetch_users_statement }

      before { create_users }

      it 'returns the user names' do
        expect(action.pluck(:name)).to \
          match_array(%w[Bernd Klaus Uwe Monika])
      end

      it 'returns a Boltless::Result' do
        expect(action).to be_a(Boltless::Result)
      end
    end

    context 'with write operations on a read-only transaction' do
      let(:statement) { create_user_statement }
      let(:opts) { { access_mode: :read } }

      it 'returns nil' do
        expect(action).to be_nil
      end
    end
  end

  describe '.one_shot!' do
    let(:action) do
      described_class.one_shot!(access_mode) do |tx|
        statement_payloads.each { |cypher, args| tx.add(cypher, **args) }
      end
    end

    context 'with an error in between' do
      let(:statements) do
        [
          create_user_statement,
          statement_with_syntax_errors,
          create_user_statement,
          fetch_users_statement
        ]
      end

      it 'raises an Boltless::Errors::TransactionRollbackError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionRollbackError,
                      /Neo.ClientError.Statement.SyntaxError/i)
      end

      it 'rolls back the transaction (no data is written)' do
        suppress(StandardError) { action }
        cypher, args = count_users_statement
        expect(described_class.execute!(cypher, **args).value).to be_eql(0)
      end
    end

    context 'with multiple statements' do
      let(:statements) do
        [
          create_user_statement,
          create_user_statement,
          create_user_statement,
          count_users_statement
        ]
      end

      it 'returns 4 results (one for each statement)' do
        expect(action.count).to be_eql(4)
      end

      it 'returns the correct created user count' do
        expect(action.last.value).to be_eql(3)
      end
    end
  end

  describe '.one_shot' do
    let(:action) do
      described_class.one_shot(access_mode) do |tx|
        statement_payloads.each { |cypher, args| tx.add(cypher, **args) }
      end
    end

    context 'with an error in between' do
      let(:statements) do
        [
          create_user_statement,
          statement_with_syntax_errors,
          create_user_statement,
          fetch_users_statement
        ]
      end

      it 'returns nil' do
        expect(action).to be_nil
      end

      it 'rolls back the transaction (no data is written)' do
        suppress(StandardError) { action }
        cypher, args = count_users_statement
        expect(described_class.execute!(cypher, **args).value).to be_eql(0)
      end
    end

    context 'with multiple statements' do
      let(:statements) do
        [
          create_user_statement,
          create_user_statement,
          create_user_statement,
          count_users_statement
        ]
      end

      it 'returns 4 results (one for each statement)' do
        expect(action.count).to be_eql(4)
      end

      it 'returns the correct created user count' do
        expect(action.last.value).to be_eql(3)
      end
    end
  end

  describe '.transaction!' do
    let(:action) { described_class.transaction!(access_mode, &user_block) }

    context 'with an error in between' do
      let(:user_block) do
        proc do |tx|
          cypher, args = create_user_statement
          tx.run!(cypher, **args)

          cypher, args = statement_with_syntax_errors
          tx.run!(cypher, **args)
        end
      end

      it 'raises an Boltless::Errors::TransactionRollbackError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionRollbackError,
                      /Neo.ClientError.Statement.SyntaxError/i)
      end

      it 'rolls back the transaction (no data is written)' do
        suppress(StandardError) { action }
        cypher, args = count_users_statement
        expect(described_class.execute!(cypher, **args).value).to \
          be_eql(0)
      end
    end

    context 'with manual rollback (without raised errors)' do
      let(:user_block) do
        proc do |tx|
          cypher, args = create_user_statement
          tx.run!(cypher, **args)
          tx.rollback!
        end
      end

      it 'returns true' do
        expect(action).to be_eql(true)
      end

      it 'rolls back the transaction (no data is written)' do
        suppress(StandardError) { action }
        cypher, args = count_users_statement
        expect(described_class.execute!(cypher, **args).value).to be_eql(0)
      end
    end

    context 'with manual commit (without raised errors)' do
      let(:user_block) do
        proc do |tx|
          cypher, args = create_user_statement
          tx.run!(cypher, **args)
          tx.commit!
        end
      end

      it 'returns an empty array (due to no finalization statements given)' do
        expect(action).to match_array([])
      end

      it 'completed the transaction (data is written)' do
        suppress(StandardError) { action }
        cypher, args = count_users_statement
        expect(described_class.execute!(cypher, **args).value).to be_eql(1)
      end
    end

    context 'with intermediate results' do
      # rubocop:disable RSpec/MultipleExpectations because of the
      #   in-block testing
      # rubocop:disable RSpec/ExampleLength dito
      it 'allows direct access to each result' do
        Boltless.transaction! do |tx|
          cypher, args = fetch_date_statement
          expect(tx.run!(cypher, **args).value).to be_eql(Date.today.to_s)

          cypher, args = fetch_static_number_statement
          expect(tx.run!(cypher, **args).value).to be_eql(9867)
        end
      end
      # rubocop:enable RSpec/MultipleExpectations
      # rubocop:enable RSpec/ExampleLength
    end
  end

  describe '.transaction' do
    let(:action) { described_class.transaction(access_mode, &user_block) }

    context 'with an error in between (not raised)' do
      let(:user_block) do
        proc do |tx|
          cypher, args = create_user_statement
          tx.run(cypher, **args)

          cypher, args = statement_with_syntax_errors
          tx.run(cypher, **args)
        end
      end

      it 'returns nil' do
        expect(action).to be_nil
      end

      it 'rolls back the transaction (no data is written)' do
        suppress(StandardError) { action }
        cypher, args = count_users_statement
        expect(described_class.execute!(cypher, **args).value).to be_eql(0)
      end
    end

    context 'with an error in between (raised)' do
      let(:user_block) do
        proc do |tx|
          cypher, args = create_user_statement
          tx.run(cypher, **args)

          cypher, args = statement_with_syntax_errors
          tx.run!(cypher, **args)
        end
      end

      it 'raises an Boltless::Errors::TransactionRollbackError' do
        expect { action }.to \
          raise_error(Boltless::Errors::TransactionRollbackError,
                      /Neo.ClientError.Statement.SyntaxError/i)
      end

      it 'rolls back the transaction (no data is written)' do
        suppress(StandardError) { action }
        cypher, args = count_users_statement
        expect(described_class.execute!(cypher, **args).value).to be_eql(0)
      end
    end

    context 'with manual rollback (without raised errors)' do
      let(:user_block) do
        proc do |tx|
          cypher, args = create_user_statement
          tx.run(cypher, **args)
          tx.rollback
        end
      end

      it 'returns true' do
        expect(action).to be_eql(true)
      end

      it 'rolls back the transaction (no data is written)' do
        suppress(StandardError) { action }
        cypher, args = count_users_statement
        expect(described_class.execute!(cypher, **args).value).to be_eql(0)
      end
    end

    context 'with manual commit (without raised errors)' do
      let(:user_block) do
        proc do |tx|
          cypher, args = create_user_statement
          tx.run(cypher, **args)
          tx.commit
        end
      end

      it 'returns an empty array (due to no finalization statements given)' do
        expect(action).to match_array([])
      end

      it 'completed the transaction (data is written)' do
        suppress(StandardError) { action }
        cypher, args = count_users_statement
        expect(described_class.execute!(cypher, **args).value).to be_eql(1)
      end
    end

    context 'with intermediate results' do
      # rubocop:disable RSpec/MultipleExpectations because of the
      #   in-block testing
      # rubocop:disable RSpec/ExampleLength dito
      it 'allows direct access to each result' do
        Boltless.transaction do |tx|
          cypher, args = fetch_date_statement
          expect(tx.run(cypher, **args).value).to be_eql(Date.today.to_s)

          cypher, args = fetch_static_number_statement
          expect(tx.run(cypher, **args).value).to be_eql(9867)
        end
      end
      # rubocop:enable RSpec/MultipleExpectations
      # rubocop:enable RSpec/ExampleLength
    end
  end
end
