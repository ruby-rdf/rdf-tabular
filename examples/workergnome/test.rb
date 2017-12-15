require "linkeddata"
graph = RDF::Graph.load("archive.csv", minimal: true, logger: STDERR)
puts graph.dump(:ttl)