# frozen_string_literal: true

module Boltless
  # A shallow interface object to collect multiple Cypher statements. We have
  # an explicit different interface (+#add+ instead or +#run+) from a regular
  # transaction to clarify that we just collect statements without running them
  # directly. As a result no subsequent statement can access the results of a
  # previous statement within this collection.
  #
  # Effectively, we wrap just multiple statements for a single HTTP API/Cypher
  # transaction API request.
  #
  # @see https://bit.ly/3zRGAEo
  class StatementCollector
    # We allow to read our collected details
    attr_reader :statements

    # We allow to access helpful utilities straight from here
    delegate :build_cypher, :prepare_label, :prepare_type, :prepare_string,
             :to_options, :resolve_cypher,
             to: Boltless

    # Setup a new statement collector instance.
    #
    # @return [Boltless::StatementCollector] the new instance
    def initialize
      @statements = []
    end

    # Add a new statement to the collector.
    #
    # @param cypher [String] the Cypher statement to run
    # @param args [Hash{Symbol => Mixed}] the additional Cypher parameters
    # @return [StatementCollector] we return ourself, for method chaining
    def add(cypher, **args)
      @statements << Request.statement_payload(cypher, **args)
      self
    end
  end
end
