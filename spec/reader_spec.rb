# coding: utf-8
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/spec/reader'

describe RDF::Tabular::Reader do
  let!(:doap) {File.expand_path("../../etc/doap.ttl", __FILE__)}
  let!(:doap_count) {File.open(doap).each_line.to_a.length}

  before(:each) do
    @reader = RDF::Tabular::Reader.new(StringIO.new(""), base_uri: "file:#{File.expand_path("..", __FILE__)}")

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

  context "HTTP Headers" do
    before(:each) {
      allow_any_instance_of(RDF::Tabular::Dialect).to receive(:embedded_metadata).and_return(RDF::Tabular::Table.new({}))
      allow_any_instance_of(RDF::Tabular::Metadata).to receive(:each_row).and_yield(RDF::Statement.new)
    }
    it "sets delimiter to TAB in dialect given text/tsv" do
      input = double("input", content_type: "text/tsv", headers: {content_type: "text/tsv"}, charset: nil)
      expect_any_instance_of(RDF::Tabular::Dialect).to receive(:separator=).with("\t")
      RDF::Tabular::Reader.new(input) {|r| r.each_statement {}}
    end
    it "sets header to false in dialect given header=absent" do
      input = double("input", content_type: "text/csv", headers: {content_type: "text/csv;header=absent"}, charset: nil)
      expect_any_instance_of(RDF::Tabular::Dialect).to receive(:header=).with(false)
      RDF::Tabular::Reader.new(input) {|r| r.each_statement {}}
    end
    it "sets encoding to ISO-8859-4 in dialect given charset=ISO-8859-4" do
      input = double("input", content_type: "text/csv", headers: {content_type: "text/csv;charset=ISO-8859-4"}, charset: "ISO-8859-4")
      expect_any_instance_of(RDF::Tabular::Dialect).to receive(:encoding=).with("ISO-8859-4")
      RDF::Tabular::Reader.new(input) {|r| r.each_statement {}}
    end
    it "sets lang to de in metadata given Content-Language=de" do
      input = double("input", content_type: "text/csv", headers: {content_language: "de"}, charset: nil)
      expect_any_instance_of(RDF::Tabular::Metadata).to receive(:lang=).with("de")
      RDF::Tabular::Reader.new(input) {|r| r.each_statement {}}
    end
    it "does not set lang with two languages in metadata given Content-Language=de, en" do
      input = double("input", content_type: "text/csv", headers: {content_language: "de, en"}, charset: nil)
      expect_any_instance_of(RDF::Tabular::Metadata).not_to receive(:lang=)
      RDF::Tabular::Reader.new(input) {|r| r.each_statement {}}
    end
  end

  context "non-file input" do
    let(:expected) {
      JSON.parse(%({
        "table": [
          {
            "url": "http://example.org/default-metadata",
            "row": [
              {
                "url": "http://example.org/default-metadata#row=2",
                "rownum": 1,
                "describes": [
                  {
                    "country": "AD",
                    "name": "Andorra"
                  }
                ]
              },
              {
                "url": "http://example.org/default-metadata#row=3",
                "rownum": 2,
                "describes": [
                  {
                    "country": "AF",
                    "name": "Afghanistan"
                  }
                ]
              },
              {
                "url": "http://example.org/default-metadata#row=4",
                "rownum": 3,
                "describes": [
                  {
                    "country": "AI",
                    "name": "Anguilla"
                  }
                ]
              },
              {
                "url": "http://example.org/default-metadata#row=5",
                "rownum": 4,
                "describes": [
                  {
                    "country": "AL",
                    "name": "Albania"
                  }
                ]
              }
            ]
          }
        ]
      }))
    }
    {
      StringIO: StringIO.new(File.read(File.expand_path("../data/country-codes-and-names.csv", __FILE__))),
      ArrayOfArrayOfString: CSV.new(File.open(File.expand_path("../data/country-codes-and-names.csv", __FILE__))).to_a,
      String: File.read(File.expand_path("../data/country-codes-and-names.csv", __FILE__)),
    }.each do |name, input|
      it name do
        RDF::Tabular::Reader.new(input, noProv: true, debug: @debug) do |reader|
          expect(JSON.parse(reader.to_json)).to produce(expected,
            debug: @debug,
            result: expected,
            noProv: true,
            metadata: reader.metadata
          )
        end
      end
    end
  end

  context "Test Files" do
    test_files = {
      "tree-ops.csv" => "tree-ops-standard.ttl",
      "tree-ops.csv-metadata.json" => "tree-ops-standard.ttl",
      "tree-ops-ext.json" => "tree-ops-ext-standard.ttl",
      "tree-ops-virtual.json" => "tree-ops-virtual-standard.ttl",
      "country-codes-and-names.csv" => "country-codes-and-names-standard.ttl",
      "countries.json" => "countries-standard.ttl",
      "countries.csv" => "countries.csv-standard.ttl",
      "roles.json" => "roles-standard.ttl",
    }
    context "#each_statement" do
      test_files.each do |csv, ttl|
        context csv do
          let(:about) {RDF::URI("http://example.org").join(csv)}
          let(:input) {File.expand_path("../data/#{csv}", __FILE__)}

          it "standard mode" do
            expected = File.expand_path("../data/#{ttl}", __FILE__)
            RDF::Reader.open(input, format: :tabular, base_uri: about, noProv: true, validate: true, debug: @debug) do |reader|
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

          it "minimal mode" do
            json = ttl.sub("-standard.ttl", "-minimal.json")
            expected = File.expand_path("../data/#{json}", __FILE__)

            RDF::Reader.open(input, format: :tabular, base_uri: about, minimal: true, debug: @debug) do |reader|
              expect(JSON.parse(reader.to_json)).to produce(
                JSON.parse(File.read(expected)),
                debug: @debug,
                id: about,
                action: about,
                result: expected,
                minimal: true,
                metadata: reader.metadata
              )
            end
          end

          it "ADT mode", skip: true do
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
          [ prov:wasGeneratedBy [
              a prov:Activity;
              prov:wasAssociatedWith <http://rubygems.org/gems/rdf-tabular>;
              prov:startedAtTime ?start;
              prov:endedAtTime ?end;
              prov:qualifiedUsage [
                a prov:Usage ;
                prov:entity <http://example.org/country-codes-and-names.csv> ;
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
      "countries.json" => %(
        PREFIX csvw: <http://www.w3.org/ns/csvw#>
        PREFIX prov: <http://www.w3.org/ns/prov#>
        PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
        ASK WHERE {
          [ prov:wasGeneratedBy [
              a prov:Activity;
              prov:wasAssociatedWith <http://rubygems.org/gems/rdf-tabular>;
              prov:startedAtTime ?start;
              prov:endedAtTime ?end;
              prov:qualifiedUsage [
                a prov:Usage ;
                prov:entity <http://example.org/countries.csv>, <http://example.org/country_slice.csv>;
                prov:hadRole csvw:csvEncodedTabularData
              ], [
                a prov:Usage ;
                prov:entity <http://example.org/countries.json> ;
                prov:hadRole csvw:tabularMetadata
              ];
            ]
          ]
          FILTER (
            DATATYPE(?start) = xsd:dateTime &&
            DATATYPE(?end) = xsd:dateTime
          )
        }
      )
    }.each do |file, query|
      it file do
        about = RDF::URI("http://example.org").join(file)
        input = File.expand_path("../data/#{file}", __FILE__)
        graph = RDF::Graph.load(input, format: :tabular, base_uri: about, debug: @debug)

        expect(graph).to pass_query(query, debug: @debug, id: about, action: about)
      end
    end
  end
end
