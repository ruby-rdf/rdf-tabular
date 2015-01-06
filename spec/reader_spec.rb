# coding: utf-8
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/reader'

describe RDF::Tabular::Reader do
  let!(:doap) {File.expand_path("../../etc/doap.ttl", __FILE__)}
  let!(:doap_count) {File.open(doap).each_line.to_a.length}

  before(:each) do
    @reader = RDF::Tabular::Reader.new(StringIO.new(""))
    RDF::Tabular.debug = []
  end
  
  # @see lib/rdf/spec/reader.rb in rdf-spec
  #include RDF_Reader

  it "should be discoverable" do
    readers = [
      RDF::Reader.for(:tabular),
      RDF::Reader.for("etc/doap.csv"),
      RDF::Reader.for(file_name:      "etc/doap.csv"),
      RDF::Reader.for(file_extension: "csv"),
      RDF::Reader.for(content_type:   "text/csv"),
    ]
    readers.each { |reader| expect(reader).to eq RDF::Tabular::Reader }
  end

  context "Test Files" do
    {
      "tree-ops CSV" => {
        input: File.expand_path("../data/tree-ops.csv", __FILE__),
        result: File.expand_path("../data/tree-ops.ttl", __FILE__),
      }
    }.each do |name, props|
      it name do
        graph = RDF::Graph.load(props[:input], format: :tabular)
        expect(graph).to be_equivalent_graph(RDF::Graph.load(props[:result]), debug: RDF::Tabular.debug, about: props[:input])
      end
    end
  end
end
