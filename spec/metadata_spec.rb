# coding: utf-8
$:.unshift "."
require 'spec_helper'

describe RDF::CSV::Metadata do
  before(:each) do
    WebMock.stub_request(:get, "https://example.org/countries.csv").
      to_return(body: File.read(File.expand_path("../data/countries.csv", __FILE__)),
                status: 200,
                headers: { 'Content-Type' => 'text.csv'})
    WebMock.stub_request(:get, "http://example.org/schema/senior-roles.json").
      to_return(body: File.read(File.expand_path("../data/senior-roles.json", __FILE__)),
                status: 200,
                headers: { 'Content-Type' => 'application/json'})
    WebMock.stub_request(:get, "http://example.org/schema/junior-roles.json").
      to_return(body: File.read(File.expand_path("../data/junior-roles.json", __FILE__)),
                status: 200,
                headers: { 'Content-Type' => 'application/json'})
    WebMock.stub_request(:get, "http://www.w3.org/ns/csvw").
      to_return(body: File.read(File.expand_path("../w3c-csvw/ns/csvw.jsonld", __FILE__)),
                status: 200,
                headers: { 'Content-Type' => 'application/ld+json'})
  end

  shared_examples "inherited properties" do |allowed = true|
    {
      null: {
        valid: ["foo"],
        invalid: [1, true, nil]
      },
      language: {
        valid: %w(en en-US),
        invalid: %w(1 foo)
      },
      "text-direction" => {
        valid: %w(rtl ltr),
        invalid: %w(foo default)
      },
      separator: {
        valid: [nil] + %w(, a | :),
        invalid: [1, false] + %w(foo ::)
      },
      default: {
        valid: ["foo"],
        invalid: [1, true, nil]
      },
      format: {
        valid: ["^foo$", "Y|N"],
        invalid: [nil]
      },
      datatype: {
        valid: %w(anySimpleType string token language Name NCName boolean gYear number binary datetime any xml html json),
        invalid: [nil, 1, true, "foo"]
      },
      length: {
        valid: [1, 10, "1", "10"],
        invalid: [-1, 0, "foo", true]
      },
      minLength: {
        valid: [1, 10, "1", "10"],
        invalid: [-1, 0, "foo", true]
      },
      maxLength: {
        valid: [1, 10, "1", "10"],
        invalid: [-1, 0, "foo", true]
      },
      minimum: {
        valid: [-10, 0, 10, "1", "10", "2015-01-01", "2015-01-01T00:00:00Z", "00:00:00"],
        invalid: ["foo", true]
      },
      maximum: {
        valid: [-10, 0, 10, "1", "10", "2015-01-01", "2015-01-01T00:00:00Z", "00:00:00"],
        invalid: ["foo", true]
      },
      minInclusive: {
        valid: [-10, 0, 10, "1", "10", "2015-01-01", "2015-01-01T00:00:00Z", "00:00:00"],
        invalid: ["foo", true]
      },
      maxInclusive: {
        valid: [-10, 0, 10, "1", "10", "2015-01-01", "2015-01-01T00:00:00Z", "00:00:00"],
        invalid: ["foo", true]
      },
      minExclusive: {
        valid: [-10, 0, 10, "1", "10", "2015-01-01", "2015-01-01T00:00:00Z", "00:00:00"],
        invalid: ["foo", true]
      },
      maxExclusive: {
        valid: [-10, 0, 10, "1", "10", "2015-01-01", "2015-01-01T00:00:00Z", "00:00:00"],
        invalid: ["foo", true]
      }
    }.each do |prop, params|
      context prop.to_s do
        if allowed
          it "validates" do
            params[:valid].each do |v|
              subject.send("#{prop}=".to_sym, v)
              expect(subject).to be_valid
            end
          end
          it "invalidates" do
            params[:invalid].each do |v|
              subject.send("#{prop}=".to_sym, v)
              expect(subject).not_to be_valid
            end
          end
        else
          it "does not allow" do
            params[:valid].each do |v|
              subject.send("#{prop}=".to_sym, v)
              expect(subject).not_to be_valid
            end
          end
        end
      end
    end
  end

  shared_examples "common properties" do |allowed = true|
    let(:valid) {%w(dc:description dcat:keyword http://schema.org/copyrightHolder)}
    let(:invalid) {%w(foo bar:baz)}
    if allowed
      it "allows defined prefixed names and absolute URIs" do
        valid.each do |v|
          subject[v.to_sym] = "foo"
          expect(subject).to be_valid
        end
      end

      it "Does not allow unknown prefxies or unprefixed names" do
        invalid.each do |v|
          subject[v.to_sym] = "foo"
          expect(subject).not_to be_valid
        end
      end
    else
      it "Does not allow defined prefixed names and absolute URIs" do
        (valid + invalid).each do |v|
          subject[v.to_sym] = "foo"
          expect(subject).not_to be_valid
        end
      end
    end
  end

  describe "Column" do
    subject {described_class.new({"name" => "foo"}, base: RDF::URI("http://example.org/base"))}
    specify {is_expected.to be_valid}
    it_behaves_like("inherited properties")
    it_behaves_like("common properties")

    it "detects invalid names" do
      [1, true, nil, "_foo"].each {|v| expect(described_class.new("name" => v)).not_to be_valid}
    end

    it "detects absence of name" do
      expect(described_class.new("@type" => "Column")).not_to be_valid
    end

    its(:type) {is_expected.to eql :Column}

    {
      title: {
        valid: ["foo", %w(foo bar), {"en" => "foo", "de" => "bar"}],
        invalid: [1, true, nil, {"en" => ["foo"]}]
      },
      required: {
        valid: [true, false, 1, 0, "true", "false", "TrUe", "fAlSe", "1", "0"],
        invalid: [nil, "foo"],
      },
      predicateUrl: {
        valid: [RDF::URI("http://example.org/")],
        invalid: [1, "foo", RDF::URI("foo")]
      }
    }.each do |prop, params|
      context prop.to_s do
        it "validates" do
          params[:valid].each do |v|
            subject.send("#{prop}=".to_sym, v)
            expect(subject).to be_valid
          end
        end
        it "invalidates" do
          params[:invalid].each do |v|
            subject.send("#{prop}=".to_sym, v)
            expect(subject).not_to be_valid
          end
        end
      end
    end
  end

  describe "Schema" do
    subject {described_class.new({"@type" => "Schema"}, base: RDF::URI("http://example.org/base"))}
    specify {is_expected.to be_valid}
    it_behaves_like("inherited properties")
    it_behaves_like("common properties")
    its(:type) {is_expected.to eql :Schema}

    describe "columns" do
      let(:column) {{"name" => "foo"}}
      subject {described_class.new({"columns" => []}, base: RDF::URI("http://example.org/base"))}
      specify {is_expected.to be_valid}

      its(:type) {is_expected.to eql :Schema}

      it "allows empty columns" do
        expect(subject).to be_valid
      end

      it "allows a valid column" do
        v = described_class.new({"columns" => [column]}, base: RDF::URI("http://example.org/base"))
        expect(v).to be_valid
      end

      it "is invalid with an invalid column" do
        v = described_class.new({"columns" => [{"name" => nil}]}, base: RDF::URI("http://example.org/base"))
        expect(v).not_to be_valid
      end

      it "is invalid with an non-unique columns" do
        v = described_class.new({"columns" => [column, column]}, base: RDF::URI("http://example.org/base"))
        expect(v).not_to be_valid
      end
    end

    describe "primaryKey" do
      let(:column) {{"name" => "foo"}}
      let(:column2) {{"name" => "bar"}}
      subject {described_class.new({"columns" => [column], "primaryKey" => column["name"]}, base: RDF::URI("http://example.org/base"))}
      specify {is_expected.to be_valid}

      its(:type) {is_expected.to eql :Schema}

      it "is invalid if referenced column does not exist" do
        subject[:columns] = []
        expect(subject).not_to be_valid
      end

      it "is valid with multiple names" do
        v = described_class.new({
          "columns" => [column, column2],
          "primaryKey" => [column["name"], column2["name"]]},
          base: RDF::URI("http://example.org/base"))
        expect(v).to be_valid
      end

      it "is invalid with multiple names if any column missing" do
        v = described_class.new({
          "columns" => [column],
          "primaryKey" => [column["name"], column2["name"]]},
          base: RDF::URI("http://example.org/base"))
        expect(v).not_to be_valid
      end
    end

    describe "foreignKeys" do
      it "FIXME"
    end

    {
      urlTemplate: {
        valid: ["http://example.org/example.csv#row={_row}", "http://example.org/tree/{on%2Dstreet}/{GID}", "#row={_row}"],
        invalid: [1, true, nil, %w(foo bar)]
      },
    }.each do |prop, params|
      context prop.to_s do
        it "validates" do
          params[:valid].each do |v|
            subject.send("#{prop}=".to_sym, v)
            expect(subject).to be_valid
          end
        end
        it "invalidates" do
          params[:invalid].each do |v|
            subject.send("#{prop}=".to_sym, v)
            expect(subject).not_to be_valid
          end
        end
      end
    end
  end

  describe "Template" do
    let(:targetFormat) {"http://example.org/targetFormat"}
    let(:templateFormat) {"http://example.org/templateFormat"}
    subject {described_class.new({"targetFormat" => targetFormat, "templateFormat" => templateFormat}, base: RDF::URI("http://example.org/base"))}
    specify {is_expected.to be_valid}
    it_behaves_like("inherited properties", false)
    it_behaves_like("common properties")
    its(:type) {is_expected.to eql :Template}

    it "FIXME"
  end

  describe "Dialect" do
    subject {described_class.new({"@type" => "Dialect"}, base: RDF::URI("http://example.org/base"))}
    specify {is_expected.to be_valid}
    it_behaves_like("inherited properties", false)
    it_behaves_like("common properties", false)
    its(:type) {is_expected.to eql :Dialect}

    described_class.const_get(:DIALECT_DEFAULTS).each do |p, v|
      context "#{p}" do
        it "retrieves #{v.inspect} by default" do
          expect(subject.send(p)).to eql v
        end

        it "retrieves set value" do
          subject[p] = "foo"
          expect(subject.send(p)).to eql "foo"
        end
      end
    end
  end

  describe "Table" do
    subject {described_class.new({"@id" => "http://example.org/table.csv", "@type" => "Table"}, base: RDF::URI("http://example.org/base"))}
    specify {is_expected.to be_valid}      
    it_behaves_like("inherited properties")
    it_behaves_like("common properties")
    its(:type) {is_expected.to eql :Table}

    it "FIXME"
  end

  describe "TableGroup" do
    let(:table) {{"@id" => "http://example.org/table.csv", "@type" => "Table"}}
    subject {described_class.new({"resources" => [table]}, base: RDF::URI("http://example.org/base"))}
    specify {is_expected.to be_valid}
    
    it_behaves_like("inherited properties")
    it_behaves_like("common properties")
    its(:type) {is_expected.to eql :TableGroup}

    it "FIXME"
  end

  context "parses example metadata" do
    Dir.glob(File.expand_path("../data/*.json", __FILE__)).each do |filename|
      context filename do
        specify {expect {RDF::CSV::Metadata.open(filename)}.not_to raise_error}
      end
    end
  end

  context "inherited properties" do
    let(:table) {{"@id" => "http://example.org/table.csv", "schema" => {"@type" => "Schema"}, "@type" => "Table"}}
    subject {described_class.new(table, base: RDF::URI("http://example.org/base"))}

    it "inherits properties from parent" do
      subject.language = "en"
      expect(subject.schema.language).to eql "en" 
    end

    it "overrides properties in parent" do
      subject.language = "en"
      subject.schema.language = "de"
      expect(subject.schema.language).to eql "de" 
    end
  end

  describe ".open" do
    context "validates example metadata" do
      Dir.glob(File.expand_path("../data/*.json", __FILE__)).each do |filename|
        context filename do
          specify do
            expect{RDF::CSV::Metadata.open(filename).validate!}.not_to raise_error
          end
        end
      end
    end
  end

  describe "#embedded_metadata" do
    subject {described_class.new({"@type" => "Table"}, base: RDF::URI("http://example.org/base"))}
    {
      "with defaults" => {
        input: "https://example.org/countries.csv",
        result: %({
          "@id": "https://example.org/countries.csv",
          "@type": "Table",
          "schema": {
            "@type": "Schema",
            "columns": [{
              "name": "countryCode",
              "title": "countryCode",
              "predicateUrl": "#countryCode"
            }, {
              "name": "latitude",
              "title": "latitude",
              "predicateUrl": "#latitude"
            }, {
              "name": "longitude",
              "title": "longitude",
              "predicateUrl": "#longitude"
            }, {
              "name": "name",
              "title": "name",
              "predicateUrl": "#name"
            }]
          }
        })
      }
    }.each do |name, props|
      it name do
        byebug
        metadata = props[:metadata] ? subject.merge(props[:metadata]) : subject
        result = metadata.embedded_metadata(props[:input])
        expect(result.to_json).to eq props[:result]
      end
    end
  end

  describe "#each_row" do
  end

  describe "#common_properties" do
  end

  describe "#rdf_values" do
  end

  describe "#merge" do
  end

  describe RDF::CSV::Metadata::Row do
    describe "#initialize" do
    end

    describe "#rownum" do
    end

    describe "#resource" do
    end

    describe "#values" do
    end
  end
end
