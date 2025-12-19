# frozen_string_literal: true

module Boltless
  module Extensions
    # A top-level gem-module extension add helpers and utilites.
    module Utilities
      extend ActiveSupport::Concern

      class_methods do
        # Build an Cypher query string with unsafe user inputs. The inputs
        # will be replaced with their escaped/prepared equivalents. This is
        # handy in cases where user inputs cannot be passed as Cypher
        # parameters (eg.  +$subject+) like node labels or relationship
        # types.
        #
        # Replacements must be referenced like this: +%<subject_label>s+ in
        # the Cypher string template.
        #
        # We support various replacement/preparation strategies. Name the
        # replacement keys like this:
        #
        #   * +*_label(s?)+ will cast to string, camelize it and
        #     escapes if needed
        #   * +*_type(s?)+ will cast to string, underscore+upcase it and
        #     escapes if needed
        #   * +*_str(s?)+ will cast to string and escapes with double quotes
        #
        # All the replacements also work with multiple values (sets/arrays).
        # The correct concatenation is guaranteed.
        #
        # @see https://bit.ly/3atOivN neo4j Cypher expressions
        # @see https://bit.ly/3RktlEa +WHERE properties(d) = $props+
        # @param replacements [Hash{Symbol,String => Mixed}] the
        #   inline-replacements
        # @yield the given block result will be used as Cypher string
        #   template
        # @return [String] the built Cypher query
        def build_cypher(**replacements)
          # Process the given replacements in order to prevent Cypher
          # injections from user given values
          replacements = replacements
                         .stringify_keys
                         .each_with_object({}) do |(key, val), memo|
            val = prepare_label(val) if key.match?(/_labels?$|^labels?$/)
            val = prepare_type(val) if key.match?(/_types?$|^types?$/)
            val = prepare_string(val) if key.match?(/_strs?$/)
            memo[key.to_sym] = val
          end

          # Then evaluate the given block to get the Cypher template
          # which should be interpolated with the replacements
          format(yield.to_s, replacements).lines.map do |line|
            line.split('//').first.rstrip.then do |processed|
              processed.empty? ? nil : processed
            end
          end.compact.join("\n")
        end

        # Prepare the given input(s) as node label for injection-free Cypher.
        #
        # @param inputs [Array<#to_s>] the input object(s) to prepare as label
        # @return [String] the prepared and concatenated string
        # @raise [ArgumentError] when no inputs are given, or only +nil+
        def prepare_label(*inputs)
          list = inputs.map { |itm| Array(itm) }.flatten.compact
          raise ArgumentError, "Bad labels: #{inputs.inspect}" if list.empty?

          list.map do |input|
            res = input.to_s.underscore.gsub('-', '_').camelcase
            res.match?(/[^a-z0-9]/i) ? "`#{res}`" : res
          end.sort.uniq.join(':')
        end

        # Prepare the given input as relationship tyep for
        # injection-free Cypher.
        #
        # @param inputs [Array<#to_s>] the input object(s) to prepare as type
        # @return [String] the prepared string
        # @raise [ArgumentError] when no inputs are given, or only +nil+
        def prepare_type(*inputs)
          list = inputs.map { |itm| Array(itm) }.flatten.compact
          raise ArgumentError, "Bad types: #{inputs.inspect}" if list.empty?

          list.map do |input|
            res = input.to_s.underscore.gsub('-', '_').upcase
            res.match?(/[^a-z0-9_]/i) ? "`#{res}`" : res
          end.sort.uniq.join('|')
        end

        # Prepare the given input as escaped string for injection-free Cypher.
        #
        # @param inputs [Array<#to_s>] the input object(s) to prepare
        #   as string
        # @return [String] the prepared string
        def prepare_string(*inputs)
          inputs = inputs.map { |itm| Array(itm) }.flatten.compact
          return %("") if inputs.empty?

          inputs.map do |input|
            "\"#{input.to_s.gsub('"', '\"')}\""
          end.uniq.join(', ')
        end

        # Generate a neo4j specific options data format from the given object.
        #
        # @param obj [Mixed] the object to convert accordingly
        # @return [String] the string representation for neo4j
        def to_options(obj)
          # We keep nil, as it is
          return if obj.nil?

          # We have to escape all string input values with single quotes
          return %('#{obj}') if obj.is_a? String

          # We have to walk through array values and assemble
          # a resulting string
          if obj.is_a? Array
            list = obj.map { |elem| to_options(elem) }.compact
            return %([ #{list.join(', ')} ])
          end

          # We keep non-hash values (eg. boolean, integer, etc) as they are
          # and use their Ruby string representation accordingly
          return obj.to_s unless obj.is_a? Hash

          # Hashes require specialized key quotation with backticks
          res = obj.map { |key, value| %(`#{key}`: #{to_options(value)}) }
          %({ #{res.join(', ')} })
        end

        # Resolve the given Cypher statement with all parameters
        # for debugging.
        #
        # @param cypher [String] the Cypher query to perform
        # @param args [Hash{Symbol => Mixed}] additional Cypher variables
        # @return [String] the resolved Cypher statement
        def resolve_cypher(cypher, **args)
          args.reduce(cypher) do |str, (var, val)|
            str.gsub(/\$#{var}\b/) do
              val.is_a?(String) ? %("#{val}") : val.to_s
            end
          end
        end

        # Get the logging color for the given Cypher statement in order to
        # visually distinguish the queries on the log.
        #
        # @param cypher [String] the Cypher query to check
        # @return [Symbol] the ANSI color name
        def cypher_logging_color(cypher)
          cypher = cypher.to_s.downcase.lines.map(&:strip)

          # Check for transaction starts
          return :magenta if cypher.first == 'begin'

          # Check for creations/transaction commits
          return :green \
            if cypher.first == 'commit' || cypher.grep(/\s*create /).any?

          # Check for upserts/updates
          return :yellow if cypher.grep(/\s*(set|merge) /).any?

          # Check for deletions
          return :red if cypher.first == 'rollback' \
            || cypher.grep(/\s*(delete|remove) /).any?

          # Everything else, like matches
          :light_blue
        end
      end
    end
  end
end
