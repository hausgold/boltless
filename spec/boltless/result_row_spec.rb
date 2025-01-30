# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boltless::ResultRow do
  let(:instance) { Boltless::Result.from(input).first }
  let(:input) { raw_result_fixture }

  describe '#[]' do
    it 'allows direct key access to the row data (string key)' do
      expect(instance['active']).to be(true)
    end

    it 'allows direct key access to the row data (symbol key)' do
      expect(instance[:active]).to be(true)
    end

    it 'returns the expected value (name)' do
      expect(instance[:name]).to eql('Bernd')
    end

    it 'returns the expected value (birthday)' do
      expect(instance[:birthday]).to eql(Date.parse('1971-07-28'))
    end

    it 'returns the expected value (written_books)' do
      expect(instance[:written_books]).to be(2)
    end
  end

  describe '#value' do
    it 'returns the first value of the row' do
      expect(instance.value).to eql(instance.values.first)
    end
  end

  describe '#values' do
    it 'returns all row values' do
      expect(instance.values).to \
        contain_exactly('Bernd', Date.parse('1971-07-28'), 2, true)
    end
  end

  describe '#to_h' do
    let(:hash) do
      {
        active: true,
        birthday: Date.parse('1971-07-28'),
        name: 'Bernd',
        written_books: 2
      }
    end

    it 'returns the correct hash representation' do
      expect(instance.to_h).to match(hash)
    end
  end

  describe '#as_json' do
    let(:hash) do
      {
        'active' => true,
        'birthday' => Date.parse('1971-07-28'),
        'name' => 'Bernd',
        'written_books' => 2
      }
    end

    it 'returns the correct hash representation' do
      expect(instance.as_json).to match(hash)
    end
  end

  describe '#each' do
    let(:simple_instance) do
      Boltless::Result.from(columns: [:key], data: [{ row: ['value'] }]).first
    end

    it 'yields each cell of the row (count)' do
      expect { |control| instance.each(&control) }.to \
        yield_control.exactly(4).times
    end

    it 'yields each row (argument)' do
      expect { |control| simple_instance.each(&control) }.to \
        yield_with_args(:key, 'value')
    end
  end

  describe '#pretty_print' do
    let(:action) { PP.pp(instance, ''.dup) }
    let(:input) { raw_result_fixture(:with_stats) }

    it 'includes the struct name' do
      expect(action).to include('#<Boltless::ResultRow')
    end

    it 'includes the columns' do
      expect(action).to include('columns=[:n]')
    end

    it 'includes the values' do
      expect(action).to include(/values=\[{:?name(=>|: )"Klaus"}\]/)
    end

    it 'includes the meta' do
      parts = [':?id(=>|: )146', ':?type(=>|: )"node"', ':?deleted(=>|: )false']
      expect(action).to include(/meta=\[{#{parts.join(', ')}}\]/)
    end

    it 'includes the graph' do
      expect(action).to include('graph=nil')
    end
  end

  describe '#inspect' do
    let(:action) { instance.inspect }
    let(:input) { raw_result_fixture }

    it 'includes the struct name' do
      expect(action).to include('#<Boltless::ResultRow')
    end

    it 'includes the columns' do
      expect(action).to \
        include('columns=[:name, :birthday, :written_books, :active]')
    end

    it 'includes the values' do
      expect(action).to include('values=["Bernd",')
    end

    it 'includes the meta' do
      expect(action).to \
        include('meta=[nil]')
    end

    it 'includes the graph' do
      expect(action).to include('graph=nil')
    end

    context 'with a graph result' do
      let(:input) { raw_result_fixture(:with_graph_result) }

      it 'includes the graph (key)' do
        expect(action).to include(/graph={:?nodes(=>|: )/)
      end

      it 'includes the graph (nodes)' do
        parts = [':?id(=>|: )"149"', ':?labels(=>|: )\["User"\]',
                 ':?properties(=>|: ){:?name(=>|: )"Kalle"}']
        expect(action).to include(/\[{#{parts.join(', ')}}\]/)
      end

      it 'includes the graph (relationships)' do
        expect(action).to \
          include(/:?relationships(=>|: )\[\]/)
      end
    end
  end
end
