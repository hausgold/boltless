# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boltless::Result do
  let(:instance) { described_class.from(input) }
  let(:input) { raw_result_fixture }

  describe '.from' do
    let(:action) { described_class.from(input) }

    it 'returns a Boltless::Result' do
      expect(action).to be_a(described_class)
    end

    it 'allows to access the shared result columns' do
      expect(action.columns).to \
        match_array(%i[active birthday name written_books])
    end

    it 'returns the correct count of rows (via reader)' do
      expect(action.rows.count).to be(2)
    end

    it 'returns the correct count of rows (directly)' do
      expect(action.count).to be(2)
    end

    context 'with statistics' do
      let(:input) { raw_result_fixture(:with_stats) }

      it 'allows to access the result statistics' do
        expect(action.stats).to include(nodes_created: 1)
      end
    end
  end

  describe '#each' do
    it 'yields each row (count)' do
      expect { |control| instance.each(&control) }.to yield_control.twice
    end

    it 'yields each row (argument)' do
      instance.rows.pop
      expect { |control| instance.each(&control) }.to \
        yield_with_args(instance.rows.first)
    end
  end

  describe '#to_a' do
    it 'returns the rows' do
      expect(instance.to_a).to be(instance.rows)
    end
  end

  describe '#value' do
    it 'returns the correct value' do
      expect(instance.value).to eql('Bernd')
    end
  end

  describe '#values' do
    let(:mapped) do
      [
        {
          name: 'Bernd',
          birthday: Date.parse('1971-07-28'),
          written_books: 2,
          active: true
        },
        {
          name: 'Klaus',
          birthday: Date.parse('1998-01-03'),
          written_books: 0,
          active: false
        }
      ]
    end

    it 'returns the correct array' do
      expect(instance.values).to match_array(mapped)
    end
  end

  describe '#pretty_print' do
    let(:action) { PP.pp(instance, ''.dup) }
    let(:input) { raw_result_fixture(:with_stats) }

    it 'includes the struct name' do
      expect(action).to include('#<Boltless::Result')
    end

    it 'includes the columns' do
      expect(action).to include('columns=[:n]')
    end

    it 'includes the rows' do
      expect(action).to include('rows=[#<Boltless::ResultRow')
    end

    it 'includes the stats' do
      expect(action).to include(/stats={:?contains_updates(=>|: )true/)
    end
  end

  describe '#inspect' do
    let(:action) { instance.inspect }
    let(:input) { raw_result_fixture }

    it 'includes the struct name' do
      expect(action).to include('#<Boltless::Result')
    end

    it 'includes the columns' do
      expect(action).to \
        include('columns=[:name, :birthday, :written_books, :active]')
    end

    it 'includes the rows' do
      expect(action).to include('rows=[#<Boltless::ResultRow')
    end

    it 'includes the stats' do
      expect(action).to include('stats=nil')
    end
  end
end
