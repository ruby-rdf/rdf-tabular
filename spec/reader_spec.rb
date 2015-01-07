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
      "tree-ops.csv" => "tree-ops.ttl",
      "country-codes-and-names.csv" => "country-codes-and-names.ttl",
    }.each do |csv, ttl|
      it csv do
        about = RDF::URI("http://example.org").join(csv)
        input = File.expand_path("../data/#{csv}", __FILE__)
        result = File.expand_path("../data/#{ttl}", __FILE__)
        graph = RDF::Graph.load(input, format: :tabular, base_uri: about, noProv: true)
        expect(graph).to be_equivalent_graph(RDF::Graph.load(result, base_uri: about), debug: RDF::Tabular.debug, about: about)
      end
    end
  end

  context "Provenance" do
    {
      "tree-ops.csv" => "tree-ops.ttl",
      "country-codes-and-names.csv" => "country-codes-and-names.ttl",
    }.each do |csv, ttl|
      it csv do
        about = RDF::URI("http://example.org").join(csv)
        input = File.expand_path("../data/#{csv}", __FILE__)
        result = File.expand_path("../data/#{ttl}", __FILE__)
        graph = RDF::Graph.load(input, format: :tabular, base_uri: about, noProv: true)
        expect(graph).to be_equivalent_graph(RDF::Graph.load(result, base_uri: about), debug: RDF::Tabular.debug, about: about)
      end
    end
  end
end
