#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'boltless'
require 'benchmark'

Boltless.configure do |conf|
  conf.base_url = 'http://172.17.0.4:7474'
end

Benchmark.bm do |x|
  cycles = 150

  cypher = <<~CYPHER
    MATCH (n:User { id: $subject }) -[:ROLE*]-> () -[r:READ]-> (o)
    WITH
      o.id AS id,
      null AS all,
      r.through AS through,
      r.condition_keys AS keys,
      r.condition_values AS values
    RETURN DISTINCT id, all, through, keys, values
  CYPHER

  x.report('.transaction (raw results)') do
    cycles.times do
      Boltless.transaction(raw_results: true) do |tx|
        tx.run(cypher, subject: '2d07b107-2a11-436e-a66d-6e0e0272d78e')
      end.first[:data].count
    end
  end

  x.report('.transaction') do
    cycles.times do
      Boltless.transaction(raw_results: false) do |tx|
        tx.run(cypher, subject: '2d07b107-2a11-436e-a66d-6e0e0272d78e')
      end.first.count
    end
  end
end

# == Old hard-mapping
#                            user     system      total        real
# .transaction (raw results) 66.999341  22.444895  89.444236 (227.354975)
# .transaction               133.277385  23.208360 156.485745 (291.491150)
#
# .transaction (raw results) avg(real/150) 1.51569s
# .transaction               avg(real/150) 1.94327s (1.3x slower)

# == New lazy mapping
#                            user     system      total        real
# .transaction (raw results) 67.460811  22.520042  89.980853 (229.456833)
# .transaction               73.468645  22.909531  96.378176 (237.652516)
#
# .transaction (raw results) avg(real/150) 1.52971222s
# .transaction               avg(real/150) 1.58435011s (±1.0x same-ish)
