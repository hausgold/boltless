# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boltless::Extensions::Utilities do
  let(:described_class) { Boltless }

  describe '.build_cypher' do
    let(:action) { described_class.build_cypher(**replacements) { cypher } }

    context 'without replacements' do
      let(:cypher) { 'CREATE (n:User)' }
      let(:replacements) { {} }

      it 'returns the untouched input string' do
        expect(action).to be_eql(cypher)
      end
    end

    context 'with replacements (unbalanced)' do
      let(:cypher) { 'CREATE (n:%<subject>s)' }
      let(:replacements) { { object: 'test' } }

      it 'raises a KeyError' do
        expect { action }.to raise_error(KeyError, /subject.*not found/)
      end
    end

    context 'with replacements (balanced, untouched string)' do
      let(:cypher) { 'CREATE (n:%<subject>s)' }
      let(:replacements) { { subject: 'User' } }

      it 'returns the processed input string' do
        expect(action).to be_eql('CREATE (n:User)')
      end
    end

    context 'with replacements (balanced, single label symbol, +label+)' do
      let(:cypher) { 'CREATE (n:%<label>s)' }
      let(:replacements) { { label: :user } }

      it 'returns the processed input string' do
        expect(action).to be_eql('CREATE (n:User)')
      end
    end

    context 'with replacements (balanced, single label symbol)' do
      let(:cypher) { 'CREATE (n:%<subject_label>s)' }
      let(:replacements) { { subject_label: :user } }

      it 'returns the processed input string' do
        expect(action).to be_eql('CREATE (n:User)')
      end
    end

    context 'with replacements (balanced, multiple label symbols)' do
      let(:cypher) { 'CREATE (n:%<subject_labels>s)' }
      let(:replacements) { { subject_labels: %i[user customer] } }

      it 'returns the processed input string' do
        expect(action).to be_eql('CREATE (n:Customer:User)')
      end
    end

    context 'with replacements (balanced, single type symbol, +type+)' do
      let(:cypher) { 'CREATE (a)-[:%<type>s]->(b)' }
      let(:replacements) { { type: :read } }

      it 'returns the processed input string' do
        expect(action).to be_eql('CREATE (a)-[:READ]->(b)')
      end
    end

    context 'with replacements (balanced, single type symbol)' do
      let(:cypher) { 'CREATE (a)-[:%<predicate_type>s]->(b)' }
      let(:replacements) { { predicate_type: :read } }

      it 'returns the processed input string' do
        expect(action).to be_eql('CREATE (a)-[:READ]->(b)')
      end
    end

    context 'with replacements (balanced, multiple type symbols)' do
      let(:cypher) { 'CREATE (a)-[:%<predicate_types>s]->(b)' }
      let(:replacements) { { predicate_types: %i[read write] } }

      it 'returns the processed input string' do
        expect(action).to be_eql('CREATE (a)-[:READ|WRITE]->(b)')
      end
    end

    context 'with replacements (balanced, single string)' do
      let(:cypher) { 'CREATE (n:User { name: %<name_str>s })' }
      let(:replacements) { { name_str: 'Klaus' } }

      it 'returns the processed input string' do
        expect(action).to be_eql('CREATE (n:User { name: "Klaus" })')
      end
    end

    context 'with replacements (balanced, multiple strings)' do
      let(:cypher) { 'CREATE (n:User { states: [%<state_strs>s] })' }
      let(:replacements) { { state_strs: %w[active locked] } }

      it 'returns the processed input string' do
        expect(action).to \
          be_eql('CREATE (n:User { states: ["active", "locked"] })')
      end
    end

    context 'without replacements, with comments' do
      let(:cypher) do
        <<~CYPHER
          // Nice comment!
          CREATE (n:User)     // Yay.
             // Other comment
        CYPHER
      end
      let(:replacements) { {} }

      it 'returns the processed input string' do
        expect(action).to \
          be_eql('CREATE (n:User)')
      end
    end
  end

  describe '.prepare_label' do
    context 'with a single string' do
      it 'returns the escaped string' do
        expect(described_class.prepare_label('user')).to \
          be_eql('User')
      end
    end

    context 'with multiple strings' do
      it 'returns the escaped string' do
        expect(described_class.prepare_label('user', 'payment')).to \
          be_eql('Payment:User')
      end
    end

    context 'with nested strings' do
      it 'returns the escaped string' do
        res = described_class.prepare_label(['user'], [['payment']], 'session')
        expect(res).to be_eql('Payment:Session:User')
      end
    end

    context 'with some nasty strings' do
      it 'returns the escaped string' do
        expect(described_class.prepare_label('userv2', 'user+v2')).to \
          be_eql('Userv2:`User+v2`')
      end
    end

    context 'with an underscored string' do
      it 'returns the escaped string' do
        expect(described_class.prepare_label('payment_mandate')).to \
          be_eql('PaymentMandate')
      end
    end

    context 'with an camel-cased string' do
      it 'returns the escaped string' do
        expect(described_class.prepare_label('paymentMandate')).to \
          be_eql('PaymentMandate')
      end
    end

    context 'with an pascal-cased string' do
      it 'returns the escaped string' do
        expect(described_class.prepare_label('PaymentMandate')).to \
          be_eql('PaymentMandate')
      end
    end

    context 'with an underscored symbol' do
      it 'returns the escaped string' do
        expect(described_class.prepare_label(:payment_mandate)).to \
          be_eql('PaymentMandate')
      end
    end

    context 'with an kabab-cased string' do
      it 'returns the escaped string' do
        expect(described_class.prepare_label('payment-mandate')).to \
          be_eql('PaymentMandate')
      end
    end

    context 'with an boolean (false)' do
      it 'returns the escaped string' do
        expect(described_class.prepare_label(false)).to be_eql('False')
      end
    end

    context 'with nil' do
      it 'raises an ArgumentError' do
        expect { described_class.prepare_label(nil) }.to \
          raise_error(ArgumentError, /Bad labels: \[nil\]/)
      end
    end

    context 'with mixed values' do
      it 'returns the escaped string' do
        res = described_class.prepare_label(
          [:a], [true, [false, ['"nice"', "o'neil"], nil]]
        )
        expect(res).to be_eql("A:False:True:`\"nice\"`:`O'neil`")
      end
    end

    context 'with a set' do
      it 'returns the escaped string' do
        set = Set[:user, :payment, :session, true]
        expect(described_class.prepare_label(set)).to \
          be_eql('Payment:Session:True:User')
      end
    end
  end

  describe '.prepare_type' do
    context 'with a single string' do
      it 'returns the escaped string' do
        expect(described_class.prepare_type('read')).to \
          be_eql('READ')
      end
    end

    context 'with multiple strings' do
      it 'returns the escaped string' do
        expect(described_class.prepare_type('read', 'write')).to \
          be_eql('READ|WRITE')
      end
    end

    context 'with nested strings' do
      it 'returns the escaped string' do
        res = described_class.prepare_type(['read'], [['write']], 'delete')
        expect(res).to be_eql('DELETE|READ|WRITE')
      end
    end

    context 'with some nasty strings' do
      it 'returns the escaped string' do
        expect(described_class.prepare_type('userv2', 'user+v2')).to \
          be_eql('USERV2|`USER+V2`')
      end
    end

    context 'with an underscored string' do
      it 'returns the escaped string' do
        expect(described_class.prepare_type('read_write')).to \
          be_eql('READ_WRITE')
      end
    end

    context 'with an camel-cased string' do
      it 'returns the escaped string' do
        expect(described_class.prepare_type('readWrite')).to \
          be_eql('READ_WRITE')
      end
    end

    context 'with an pascal-cased string' do
      it 'returns the escaped string' do
        expect(described_class.prepare_type('ReadWrite')).to \
          be_eql('READ_WRITE')
      end
    end

    context 'with an underscored symbol' do
      it 'returns the escaped string' do
        expect(described_class.prepare_type(:read_write)).to \
          be_eql('READ_WRITE')
      end
    end

    context 'with an kabab-cased string' do
      it 'returns the escaped string' do
        expect(described_class.prepare_type('read-write')).to \
          be_eql('READ_WRITE')
      end
    end

    context 'with an boolean (false)' do
      it 'returns the escaped string' do
        expect(described_class.prepare_type(false)).to be_eql('FALSE')
      end
    end

    context 'with nil' do
      it 'raises an ArgumentError' do
        expect { described_class.prepare_type(nil) }.to \
          raise_error(ArgumentError, /Bad types: \[nil\]/)
      end
    end

    context 'with mixed values' do
      it 'returns the escaped string' do
        res = described_class.prepare_type(
          [:a], [true, [false, ['"nice"', "o'neil"], nil], 1], 12.14
        )
        expect(res).to be_eql("1|A|FALSE|TRUE|`\"NICE\"`|`12.14`|`O'NEIL`")
      end
    end

    context 'with a set' do
      it 'returns the escaped string' do
        set = Set[:a, :b, :c, 1]
        expect(described_class.prepare_type(set)).to be_eql('1|A|B|C')
      end
    end
  end

  describe '.prepare_string' do
    context 'with a single string' do
      it 'returns the escaped string' do
        expect(described_class.prepare_string('super "cool" string')).to \
          be_eql('"super \"cool\" string"')
      end
    end

    context 'with multiple strings' do
      it 'returns the escaped string' do
        expect(described_class.prepare_string('a', 'b')).to \
          be_eql('"a", "b"')
      end
    end

    context 'with nested strings' do
      it 'returns the escaped string' do
        expect(described_class.prepare_string(['a'], [['b']], 'c')).to \
          be_eql('"a", "b", "c"')
      end
    end

    context 'with an integer' do
      it 'returns the escaped string' do
        expect(described_class.prepare_string(1)).to be_eql('"1"')
      end
    end

    context 'with an boolean (true)' do
      it 'returns the escaped string' do
        expect(described_class.prepare_string(true)).to be_eql('"true"')
      end
    end

    context 'with an boolean (false)' do
      it 'returns the escaped string' do
        expect(described_class.prepare_string(false)).to be_eql('"false"')
      end
    end

    context 'with nil' do
      it 'returns the escaped string' do
        expect(described_class.prepare_string(nil)).to be_eql('""')
      end
    end

    context 'with mixed values' do
      it 'returns the escaped string' do
        res = described_class.prepare_string(
          [:a], [true, [false, ['"nice"', "o'neil"], nil], 1], 12.14
        )
        expect(res).to \
          be_eql('"a", "true", "false", "\"nice\"", "o\'neil", "1", "12.14"')
      end
    end

    context 'with a set' do
      it 'returns the escaped string' do
        set = Set[:a, :b, :c, 1]
        expect(described_class.prepare_string(set)).to \
          be_eql('"a", "b", "c", "1"')
      end
    end
  end

  describe '.to_options' do
    let(:action) { described_class.to_options(obj) }
    let(:obj) do
      {
        indexProvider: 'lucene+native-3.0',
        indexConfig: {
          'spatial.wgs-84.min': [-100.0, -80.0],
          'spatial.wgs-84.max': [100.0, 80.0]
        }
      }
    end
    let(:cypher_opts) do
      "{ `indexProvider`: 'lucene+native-3.0', " \
        '`indexConfig`: { `spatial.wgs-84.min`: [ -100.0, -80.0 ], ' \
        '`spatial.wgs-84.max`: [ 100.0, 80.0 ] } }'
    end

    context 'with a String' do
      let(:obj) { 'test' }

      it 'returns the Cypher options representation' do
        expect(action).to be_eql(%('test'))
      end
    end

    context 'with a flat Array' do
      let(:obj) { ['test', 1.9235, 2, true, nil] }

      it 'returns the Cypher options representation' do
        expect(action).to be_eql(%([ 'test', 1.9235, 2, true ]))
      end
    end

    context 'with a flat Hash' do
      let(:obj) { { symbol: true, 'string' => 1.234 } }

      it 'returns the Cypher options representation' do
        expect(action).to be_eql(%({ `symbol`: true, `string`: 1.234 }))
      end
    end

    context 'with a complex nested structure' do
      it 'returns the Cypher options representation' do
        expect(action).to be_eql(cypher_opts)
      end
    end
  end

  describe '.resolve_cypher' do
    let(:action) { described_class.resolve_cypher(cypher, **args) }

    describe 'Cypher without parameters and none given' do
      let(:cypher) { 'CREATE (n:User)' }
      let(:args) { {} }

      it 'returns the untouched input string' do
        expect(action).to be_eql(cypher)
      end
    end

    describe 'Cypher with parameters and none given' do
      let(:cypher) { 'CREATE (n:User { name: $name })' }
      let(:args) { {} }

      it 'returns the untouched input string' do
        expect(action).to be_eql(cypher)
      end
    end

    describe 'Cypher with parameters and parameters given (balanced)' do
      let(:cypher) { 'CREATE (n:User { name: $name })' }
      let(:args) { { name: 'Peter' } }

      it 'returns the resolved string' do
        expect(action).to be_eql('CREATE (n:User { name: "Peter" })')
      end
    end

    describe 'Cypher with parameters and parameters given (unbalanced)' do
      let(:cypher) { 'CREATE (n:User { name: $name, email: $email })' }
      let(:args) { { email: 'peter@example.com' } }

      it 'returns the resolved string' do
        expect(action).to \
          be_eql('CREATE (n:User { name: $name, email: "peter@example.com" })')
      end
    end
  end

  describe '.cypher_logging_color' do
    let(:action) { described_class.cypher_logging_color(cypher) }

    context 'with a transaction begin statement' do
      let(:cypher) { 'BEGIN' }

      it 'returns magenta' do
        expect(action).to be_eql(:magenta)
      end
    end

    context 'with a create statement' do
      let(:cypher) { 'CREATE (n:User { name: $name })' }

      it 'returns green' do
        expect(action).to be_eql(:green)
      end
    end

    context 'with a merge statement' do
      let(:cypher) { 'MERGE (n:User { name: $name })' }

      it 'returns yellow' do
        expect(action).to be_eql(:yellow)
      end
    end

    context 'with a match/set statement' do
      let(:cypher) { 'MATCH (n:User { name: $name }) SET n.email = $email' }

      it 'returns yellow' do
        expect(action).to be_eql(:yellow)
      end
    end

    context 'with a match/delete statement' do
      let(:cypher) { 'MATCH (n:User { name: $name }) DELETE n' }

      it 'returns red' do
        expect(action).to be_eql(:red)
      end
    end

    context 'with a match/remove statement' do
      let(:cypher) { 'MATCH (n:User { name: $name }) REMOVE n.email' }

      it 'returns red' do
        expect(action).to be_eql(:red)
      end
    end

    context 'with a transaction commit statement' do
      let(:cypher) { 'COMMIT' }

      it 'returns green' do
        expect(action).to be_eql(:green)
      end
    end

    context 'with a transaction rollback statement' do
      let(:cypher) { 'ROLLBACK' }

      it 'returns red' do
        expect(action).to be_eql(:red)
      end
    end

    context 'with a match statement' do
      let(:cypher) { 'MATCH (n:User { name: $name }) RETURN n.email' }

      it 'returns light blue' do
        expect(action).to be_eql(:light_blue)
      end
    end
  end
end
