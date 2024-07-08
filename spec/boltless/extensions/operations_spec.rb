# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boltless::Extensions::Operations do
  let(:described_class) { Boltless }

  before { clean_neo4j! }

  describe '.clear_database!' do
    let(:action) { described_class.clear_database! }
    let(:logger) { Logger.new(log_dev) }
    let(:log_dev) { StringIO.new }
    let(:log) { log_dev.string }

    before do
      described_class.configuration.logger = logger
      described_class.add_index(name: 'user_id', for: '(n:User)', on: 'n.id')
      described_class.add_constraint(name: 'uniq_user_email', for: '(n:User)',
                                     require: 'n.email IS UNIQUE')
      described_class.one_shot! do |tx|
        tx.add('CREATE (n:User { name: $name })', name: 'Klaus')
        tx.add('CREATE (n:User { name: $name })', name: 'Bernd')
        tx.add('MATCH (a:User { name: $a_name }) ' \
               'MATCH (b:User { name: $b_name }) ' \
               'CREATE (a)-[:FRIEND_OF { since: $since }]->(b)',
               a_name: 'Klaus', b_name: 'Bernd', since: Date.today.to_s)
      end
    end

    it 'removes all indexes' do
      expect { action }.to \
        change { described_class.index_names.count }.from(1).to(0)
    end

    it 'removes all constraints' do
      expect { action }.to \
        change { described_class.constraint_names.count }.from(1).to(0)
    end

    it 'removes all nodes' do
      expect { action }.to \
        change { described_class.query!('MATCH (n) RETURN count(n)').value }
        .from(2).to(0)
    end

    it 'removes all relationships' do
      check = proc do
        described_class.query!('MATCH (a)-[r]->(b) RETURN type(r) AS type')
                       .count
      end
      expect { action }.to change(&check).from(1).to(0)
    end

    it 'logs the removed indexes' do
      action
      expect(log).to include('Drop neo4j index user_id')
    end

    it 'logs the removed constraints' do
      action
      expect(log).to include('Drop neo4j constraint uniq_user_email')
    end

    it 'logs the removed nodes count' do
      action
      expect(log).to include('Nodes deleted: 2')
    end

    it 'logs the removed relationships count' do
      action
      expect(log).to include('Relationships deleted: 1')
    end
  end

  describe '.component_name_present?' do
    before do
      described_class.add_index(name: 'user_id', for: '(n:User)', on: 'n.id')
      described_class.add_constraint(name: 'uniq_user_email', for: '(n:User)',
                                     require: 'n.email IS UNIQUE')
    end

    context 'with an known index' do
      it 'returns true' do
        expect(described_class.component_name_present?('user_id')).to \
          be(true)
      end
    end

    context 'with an known constraint' do
      it 'returns true' do
        expect(described_class.component_name_present?('uniq_user_email')).to \
          be(true)
      end
    end

    context 'with an unknown name' do
      it 'returns false' do
        expect(described_class.component_name_present?('unknown')).to \
          be(false)
      end
    end
  end

  describe '.index_names' do
    before do
      described_class.add_index(name: 'user_id', for: '(n:User)', on: 'n.id')
      described_class.add_index(name: 'session_id', for: '(n:Session)',
                                on: 'n.id')
    end

    it 'returns the known index names' do
      expect(described_class.index_names).to \
        contain_exactly('user_id', 'session_id')
    end
  end

  describe '.constraint_names' do
    before do
      described_class.add_constraint(name: 'uniq_user_email',
                                     for: '(n:User)',
                                     require: 'n.email IS UNIQUE')
      described_class.add_constraint(name: 'uniq_user_session',
                                     for: '(n:Session)',
                                     require: 'n.user_id IS UNIQUE')
    end

    it 'returns the known constraint names' do
      expect(described_class.constraint_names).to \
        contain_exactly('uniq_user_email', 'uniq_user_session')
    end
  end

  describe '.add_index' do
    it 'allows to create a new index' do
      described_class.add_index(name: 'user_id', for: '(n:User)', on: 'n.id')
      expect(described_class.index_names).to contain_exactly('user_id')
    end
  end

  describe '.drop_index' do
    before do
      described_class.add_index(name: 'user_id', for: '(n:User)', on: 'n.id')
    end

    context 'with an existing index' do
      it 'allows to drop an index' do
        described_class.drop_index('user_id')
        expect(described_class.index_names).to be_empty
      end
    end

    context 'without an existing index' do
      it 'does not raise errors' do
        expect { described_class.drop_index('unknown') }.not_to raise_error
      end
    end
  end

  describe '.add_constraint' do
    it 'allows to create a new constraint' do
      described_class.add_constraint(name: 'uniq_user_email', for: '(n:User)',
                                     require: 'n.email IS UNIQUE')
      expect(described_class.constraint_names).to \
        contain_exactly('uniq_user_email')
    end
  end

  describe '.drop_constraint' do
    before do
      described_class.add_constraint(name: 'uniq_user_email', for: '(n:User)',
                                     require: 'n.email IS UNIQUE')
    end

    context 'with an existing constraint' do
      it 'allows to drop an constraint' do
        described_class.drop_constraint('uniq_user_email')
        expect(described_class.constraint_names).to be_empty
      end
    end

    context 'without an existing constraint' do
      it 'does not raise errors' do
        expect { described_class.drop_constraint('unknown') }.not_to \
          raise_error
      end
    end
  end
end
