# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boltless::StatementCollector do
  let(:instance) { described_class.new }

  describe 'delegations' do
    it 'allows to access the #build_cypher utility' do
      expect(instance.respond_to?(:build_cypher)).to be_eql(true)
    end
  end

  describe '#add' do
    let(:action) { -> { instance.add('cypher', param_a: 1) } }

    it 'returns itself for chaining' do
      expect(action.call).to be(instance)
    end

    it 'collects the given statements' do
      action.call
      action.call
      expect(instance.statements.count).to be_eql(2)
    end

    it 'calls Request.statement_payload to prepare the statement' do
      expect(Boltless::Request).to \
        receive(:statement_payload).with('cypher', param_a: 1).once
      action.call
    end
  end

  describe '#statements' do
    let(:action) { instance.statements }

    before { instance.add('cypher', param_a: 1) }

    it 'returns the mapped statements' do
      expect(action.first).to \
        match(statement: 'cypher',
              parameters: { param_a: 1 })
    end
  end
end
