# frozen_string_literal: true

module Boltless
  # A lightweight struct representation of a single result
  # object from the neo4j HTTP API.
  Result = Struct.new(:columns, :rows, :stats) do
    # Build a mapped result structure from the given raw result hash.
    #
    # @param hash [Hash{Symbol => Mixed}] the raw neo4j result hash
    #   for a single statement
    # @return [Boltless::Result] the lightweight mapped result structure
    def self.from(hash)
      # We setup an empty result struct first
      cols = hash[:columns].map(&:to_sym)
      Result.new(cols, [], hash[:stats]).tap do |res|
        # Then we re-map each row from the given hash
        res.rows = hash[:data].map do |datum|
          ResultRow.new(res, datum[:row], datum[:meta], datum[:graph])
        end
      end
    end

    # We allow direct enumration access to our rows,
    # this allows direct counting, plucking etc
    include Enumerable

    # Yields each row of the result. This is the foundation to the +Enumerable+
    # interface, so all its methods (eg. +#count+, etc) are available with
    # this. If no block is given, an Enumerator is returned.
    #
    # @param block [Proc] the block which is called for each result row
    # @yieldparam [Boltless::ResultRow] a single result row
    # @return [Array<Boltless::ResultRow>] the result rows array itself
    def each(&block)
      rows.each(&block)
    end

    # A shortcut to access the result rows.
    delegate :to_a, to: :rows

    # A convenience shortcut for the first row of the result, and its first
    # value. This comes in very handy for single-value/single-row Cypher
    # statements like +RETURN date() AS date+. Or probing Cypher statements
    # like +MATCH (n:User { name: $name }) RETURN 1 LIMIT 1+.
    #
    # @return [Mixed] the first value of the first result row
    def value
      rows.first.values.first
    end

    # A convenience method to access all mapped result rows as hashes.
    #
    # *Heads up!* This method is quite costly (time and heap memory) on large
    # result sets, as it merges the column data with the row data in order to
    # return an assembled hash. Use with caution. (Pro Tip: Iterate over the
    # rows and +pluck/[]+ the result keys you are interested in, instead of the
    # "grab everything" style)
    #
    # @return [Array<Hash{Symbol => Mixed}>] the mapped result rows
    def values
      rows.map(&:to_h)
    end

    # Pretty print the result structure in a meaningful way.
    #
    # @param pp [PP] a pretty printer instance to use
    #
    # rubocop:disable Metrics/MethodLength -- because of the pretty printing
    #   logic
    # rubocop:disable Metrics/AbcSize -- dito
    def pretty_print(pp)
      pp.object_group(self) do
        pp.breakable
        pp.text('columns=')
        pp.pp(columns)
        pp.comma_breakable

        pp.text('rows=')
        if rows.count > 1
          pp.group(1, '[', ']') do
            pp.pp(first)
            pp.comma_breakable
            pp.text("[+#{rows.count - 1} ..]")
          end
        else
          pp.pp(rows)
        end
        pp.comma_breakable

        pp.text('stats=')
        pp.pp(stats)
      end
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize
    alias_method :inspect, :pretty_inspect
  end
end
