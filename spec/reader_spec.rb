# coding: utf-8
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/reader'

describe RDF::Tabular::Reader do
  let!(:doap) {File.expand_path("../../etc/doap.ttl", __FILE__)}
  let!(:doap_count) {File.open(doap).each_line.to_a.length}

  before(:each) do
    @reader = RDF::Tabular::Reader.new(StringIO.new(""))

    WebMock.stub_request(:any, %r(.*example.org.*)).
      to_return(lambda {|request|
        file = request.uri.to_s.split('/').last
        content_type = case file
        when /\.json/ then 'application/json'
        when /\.csv/  then 'text/csv'
        else 'text/plain'
        end

        case file
        when "metadata.json", "country-codes-and-names.csv-metadata.json"
          {status: 401}
        else
          {
            body: File.read(File.expand_path("../data/#{file}", __FILE__)),
            status: 200,
            headers: {'Content-Type' => content_type}
          }
        end
      })

    @debug = []
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
    test_files = {
      "tree-ops.csv" => "tree-ops-standard.ttl",
      "tree-ops.csv-metadata.json" => "tree-ops-standard.ttl",
      "tree-ops-ext.json" => "tree-ops-ext-standard.ttl",
      "tree-ops-virtual.json" => "tree-ops-virtual-standard.ttl",
      "country-codes-and-names.csv" => "country-codes-and-names-standard.ttl",
      "countries.json" => "countries-standard.ttl",
      "roles.json" => "roles-standard.ttl",
    }
    context "#each_statement" do
      test_files.each do |csv, ttl|
        context csv do
          let(:about) {RDF::URI("http://example.org").join(csv)}
          let(:input) {File.expand_path("../data/#{csv}", __FILE__)}
          it "standard mode" do
            expected = File.expand_path("../data/#{ttl}", __FILE__)
            RDF::Reader.open(input, format: :tabular, base_uri: about, noProv: true, debug: @debug) do |reader|
              graph = RDF::Graph.new << reader
              graph2 = RDF::Graph.load(expected, base_uri: about)
              expect(graph).to be_equivalent_graph(graph2,
                                                   debug: @debug,
                                                   id: about,
                                                   action: about,
                                                   result: expected,
                                                   metadata: reader.metadata)
            end
          end

          it "minimal mode" do
            ttl = ttl.sub("standard", "minimal")
            expected = File.expand_path("../data/#{ttl}", __FILE__)
            RDF::Reader.open(input, format: :tabular, base_uri: about, minimal: true, debug: @debug) do |reader|
              graph = RDF::Graph.new << reader
              graph2 = RDF::Graph.load(expected, base_uri: about)
              expect(graph).to be_equivalent_graph(graph2,
                                                   debug: @debug,
                                                   id: about,
                                                   action: about,
                                                   result: expected,
                                                   metadata: reader.metadata)
            end
          end
        end
      end
    end

    describe "#to_json" do
      test_files.each do |csv, ttl|
        context csv do
          let(:about) {RDF::URI("http://example.org").join(csv)}
          let(:input) {File.expand_path("../data/#{csv}", __FILE__)}
          it "standard mode" do
            json = ttl.sub("-standard.ttl", "-standard.json")
            expected = File.expand_path("../data/#{json}", __FILE__)

            RDF::Reader.open(input, format: :tabular, base_uri: about, noProv: true, debug: @debug) do |reader|
              expect(JSON.parse(reader.to_json)).to produce(
                JSON.parse(File.read(expected)),
                debug: @debug,
                id: about,
                action: about,
                result: expected,
                noProv: true,
                metadata: reader.metadata
              )
            end
          end

          it "ADT mode", pending: true do
            json = ttl.sub("-standard.ttl", "-atd.json")
            expected = File.expand_path("../data/#{json}", __FILE__)

            RDF::Reader.open(input, format: :tabular, base_uri: about, noProv: true, debug: @debug) do |reader|
              expect(JSON.parse(reader.to_json(atd: true))).to produce(
                JSON.parse(File.read(expected)),
                debug: @debug,
                id: about,
                action: about,
                result: expected,
                noProv: true,
                metadata: reader.metadata
              )
            end
          end
        end
      end
    end
  end

  context "Provenance" do
    {
      "country-codes-and-names.csv" => %(
        PREFIX csvw: <http://www.w3.org/ns/csvw#>
        PREFIX prov: <http://www.w3.org/ns/prov#>
        PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
        ASK WHERE {
          [ prov:activity [
              a prov:Activity;
              prov:startedAtTime ?start;
              prov:endedAtTime ?end;
              prov:qualifiedUsage [
                a prov:Usage ;
                prov:Entity ?csv ;
                prov:hadRole csvw:csvEncodedTabularData
              ];
            ]
          ]
          FILTER (
            DATATYPE(?start) = xsd:dateTime &&
            DATATYPE(?end) = xsd:dateTime
          )
        }
      ),
    }.each do |csv, query|
      it csv do
        about = RDF::URI("http://example.org").join(csv)
        input = File.expand_path("../data/#{csv}", __FILE__)
        graph = RDF::Graph.load(input, format: :tabular, base_uri: about, debug: @debug)

        expect(graph).to pass_query(query, debug: @debug, id: about)
      end
    end
  end
end
