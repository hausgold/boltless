# frozen_string_literal: true

module Boltless
  # A lightweight result row, used for convenient result data access.
  #
  # rubocop:disable Lint/StructNewOverride -- because we have an own
  #   implementation for +#values+
  ResultRow = Struct.new(:result, :values, :meta, :graph) do
    # A simple shortcut to easily access the row columns
    delegate :columns, to: :result

    # Return the value of the requested key. When the given key is unknown, we
    # just return +nil+. The given key is normalized to its Symbol form, in
    # order to allow performant indifferent hash access.
    #
    # @param key [Symbol, String] the key to fetch the value for
    # @return [Mixed] the value for the given key
    def [](key)
      # When the requested key was not found, we return +nil+, no need to
      # perform the actual lookup
      return unless (idx = columns.index(key.to_sym))

      # Otherwise return the value from the slot
      values[idx]
    end

    # A convenience shortcut for the first value of the row. This comes in very
    # handy for single-value/single-row Cypher statements like +RETURN date()
    # AS date+.
    #
    # @return [Mixed] the first value of the row
    def value
      values.first
    end

    # Return the assembled row as Ruby hash.
    #
    # *Heads up!* This method is quite costly (time and heap memory) on large
    # result sets, as it merges the column data with the row data in order to
    # return an assembled hash. Use with caution.
    #
    # @return [Hash{Symbol => Mixed}] the mapped result row
    def to_h
      columns.zip(values).to_h
    end

    # Returns a JSON hash representation the result row. This works like
    # +#to_h+ but the resulting hash uses string keys instead.
    #
    # @return [Hash{String => Mixed}] the JSON hash representation
    def as_json(*)
      columns.map(&:to_s).zip(values).to_h
    end

    # We allow direct enumration access to our row data,
    # this allows direct counting, plucking etc
    include Enumerable

    # Calls the user given block once for each key/columns of the row, passing
    # the key-value pair as parameters. If no block is given, an enumerator is
    # returned instead.
    #
    # @param block [Proc] the block which is called for each result row
    # @yieldparam [Symbol] a row column/key
    # @yieldparam [Mixed] a row value for the column/key
    # @return [Array<Boltless::ResultRow>] the result rows array itself
    def each
      columns.each_with_index do |column, idx|
        yield(column, values[idx])
      end
    end
    alias_method :each_pair, :each

    # Pretty print the result row structure in a meaningful way.
    #
    # @param pp [PP] a pretty printer instance to use
    def pretty_print(pp)
      pp.object_group(self) do
        pp.breakable
        %i[columns values meta graph].each_with_index do |key, idx|
          pp.text("#{key}=")
          pp.pp(send(key))
          pp.comma_breakable if idx < 3
        end
      end
    end
    alias_method :inspect, :pretty_inspect
  end
  # rubocop:enable Lint/StructNewOverride
end
