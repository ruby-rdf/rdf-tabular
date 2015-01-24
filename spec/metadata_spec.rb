# coding: utf-8
$:.unshift "."
require 'spec_helper'

describe RDF::Tabular::Metadata do
  before(:each) do
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
    WebMock.stub_request(:get, "http://www.w3.org/ns/csvw").
      to_return(body: File.read(File.expand_path("../w3c-csvw/ns/csvw.jsonld", __FILE__)),
                status: 200,
                headers: { 'Content-Type' => 'application/ld+json'})
    @debug = []
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

  describe RDF::Tabular::Column do
    subject {described_class.new({"name" => "foo"}, base: RDF::URI("http://example.org/base"), debug: @debug)}
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

  describe RDF::Tabular::Schema do
    subject {described_class.new({}, base: RDF::URI("http://example.org/base", debug: @debug))}
    specify {is_expected.to be_valid}
    it_behaves_like("inherited properties")
    it_behaves_like("common properties")
    its(:type) {is_expected.to eql :Schema}

    describe "columns" do
      let(:column) {{"name" => "foo"}}
      subject {described_class.new({"columns" => []}, base: RDF::URI("http://example.org/base", debug: @debug))}
      specify {is_expected.to be_valid}

      its(:type) {is_expected.to eql :Schema}

      it "allows empty columns" do
        expect(subject).to be_valid
      end

      it "allows a valid column" do
        v = described_class.new({"columns" => [column]}, base: RDF::URI("http://example.org/base", debug: @debug))
        expect(v).to be_valid
      end

      it "is invalid with an invalid column" do
        v = described_class.new({"columns" => [{"name" => nil}]}, base: RDF::URI("http://example.org/base", debug: @debug))
        expect(v).not_to be_valid
      end

      it "is invalid with an non-unique columns" do
        v = described_class.new({"columns" => [column, column]}, base: RDF::URI("http://example.org/base", debug: @debug))
        expect(v).not_to be_valid
      end
    end

    describe "primaryKey" do
      let(:column) {{"name" => "foo"}}
      let(:column2) {{"name" => "bar"}}
      subject {described_class.new({"columns" => [column], "primaryKey" => column["name"]}, base: RDF::URI("http://example.org/base", debug: @debug))}
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
          base: RDF::URI("http://example.org/base"),
          debug: @debug)
        expect(v).to be_valid
      end

      it "is invalid with multiple names if any column missing" do
        v = described_class.new({
          "columns" => [column],
          "primaryKey" => [column["name"], column2["name"]]},
          base: RDF::URI("http://example.org/base",
          debug: @debug))
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

  describe RDF::Tabular::Template do
    let(:targetFormat) {"http://example.org/targetFormat"}
    let(:templateFormat) {"http://example.org/templateFormat"}
    subject {described_class.new({"targetFormat" => targetFormat, "templateFormat" => templateFormat}, base: RDF::URI("http://example.org/base"), debug: @debug)}
    specify {is_expected.to be_valid}
    it_behaves_like("inherited properties", false)
    it_behaves_like("common properties")
    its(:type) {is_expected.to eql :Template}

    it "FIXME"
  end

  describe RDF::Tabular::Dialect do
    subject {described_class.new({}, base: RDF::URI("http://example.org/base", debug: @debug))}
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

  describe RDF::Tabular::Table do
    subject {described_class.new({"@id" => "http://example.org/table.csv"}, base: RDF::URI("http://example.org/base"), debug: @debug)}
    specify {is_expected.to be_valid}      
    it_behaves_like("inherited properties")
    it_behaves_like("common properties")
    its(:type) {is_expected.to eql :Table}

    it "FIXME"
  end

  describe RDF::Tabular::TableGroup do
    let(:table) {{"@id" => "http://example.org/table.csv"}}
    subject {described_class.new({"resources" => [table]}, base: RDF::URI("http://example.org/base"), debug: @debug)}
    specify {is_expected.to be_valid}
    
    it_behaves_like("inherited properties")
    it_behaves_like("common properties")
    its(:type) {is_expected.to eql :TableGroup}

    it "FIXME"
  end

  context "parses example metadata" do
    Dir.glob(File.expand_path("../data/*.json", __FILE__)).each do |filename|
      next if filename =~ /-result.json/
      context filename do
        specify {expect {RDF::Tabular::Metadata.open(filename)}.not_to raise_error}
      end
    end
  end

  context "inherited properties" do
    let(:table) {{"@id" => "http://example.org/table.csv", "schema" => {"@type" => "Schema"}, "@type" => "Table"}}
    subject {described_class.new(table, base: RDF::URI("http://example.org/base"), debug: @debug)}

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
        next if filename =~ /-result.json/
        context filename do
          specify do
            md = RDF::Tabular::Metadata.open(filename, debug: @debug)
            expect(md.valid?).to produce(true, @debug)
            expect(md).to be_valid
          end
        end
      end
    end
  end

  describe ".from_input" do
    it "FIXME"
  end

  describe ".new" do
    context "intuits subclass" do
      {
        ":type TableGroup" => [{}, {type: :TableGroup}, RDF::Tabular::TableGroup],
        ":type Table" => [{}, {type: :Table}, RDF::Tabular::Table],
        ":type Template" => [{}, {type: :Template}, RDF::Tabular::Template],
        ":type Schema" => [{}, {type: :Schema}, RDF::Tabular::Schema],
        ":type Column" => [{}, {type: :Column}, RDF::Tabular::Column],
        ":type Dialect" => [{}, {type: :Dialect}, RDF::Tabular::Dialect],
        "@type TableGroup" => [{"@type" => "TableGroup"}, RDF::Tabular::TableGroup],
        "@type Table" => [{"@type" => "Table"}, RDF::Tabular::Table],
        "@type Template" => [{"@type" => "Template"}, RDF::Tabular::Template],
        "@type Schema" => [{"@type" => "Schema"}, RDF::Tabular::Schema],
        "@type Column" => [{"@type" => "Column"}, RDF::Tabular::Column],
        "@type Dialect" => [{"@type" => "Dialect"}, RDF::Tabular::Dialect],
        "resources TableGroup" => [{"resources" => []}, RDF::Tabular::TableGroup],
        "dialect Table" => [{"dialect" => {}}, RDF::Tabular::Table],
        "schema Table" => [{"schema" => {}}, RDF::Tabular::Table],
        "templates Table" => [{"templates" => []}, RDF::Tabular::Table],
        "targetFormat Template" => [{"targetFormat" => "foo"}, RDF::Tabular::Template],
        "templateFormat Template" => [{"templateFormat" => "foo"}, RDF::Tabular::Template],
        "source Template" => [{"source" => "foo"}, RDF::Tabular::Template],
        "columns Schema" => [{"columns" => []}, RDF::Tabular::Schema],
        "primaryKey Schema" => [{"primaryKey" => "foo"}, RDF::Tabular::Schema],
        "foreignKeys Schema" => [{"foreignKeys" => []}, RDF::Tabular::Schema],
        "urlTemplate Schema" => [{"urlTemplate" => "foo"}, RDF::Tabular::Schema],
        "predicateUrl Column" => [{"predicateUrl" => "foo"}, RDF::Tabular::Column],
        "commentPrefix Dialect" => [{"commentPrefix" => "#"}, RDF::Tabular::Dialect],
        "delimiter Dialect" => [{"delimiter" => ","}, RDF::Tabular::Dialect],
        "doubleQuote Dialect" => [{"doubleQuote" => true}, RDF::Tabular::Dialect],
        "encoding Dialect" => [{"encoding" => "utf-8"}, RDF::Tabular::Dialect],
        "header Dialect" => [{"header" => true}, RDF::Tabular::Dialect],
        "headerColumnCount Dialect" => [{"headerColumnCount" => 0}, RDF::Tabular::Dialect],
        "headerRowCount Dialect" => [{"headerRowCount" => 1}, RDF::Tabular::Dialect],
        "lineTerminator Dialect" => [{"lineTerminator" => "\r\n"}, RDF::Tabular::Dialect],
        "quoteChar Dialect" => [{"quoteChar" => "\""}, RDF::Tabular::Dialect],
        "skipBlankRows Dialect" => [{"skipBlankRows" => true}, RDF::Tabular::Dialect],
        "skipColumns Dialect" => [{"skipColumns" => 0}, RDF::Tabular::Dialect],
        "skipInitialSpace Dialect" => [{"skipInitialSpace" => "start"}, RDF::Tabular::Dialect],
        "skipRows Dialect" => [{"skipRows" => 1}, RDF::Tabular::Dialect],
        "trim Dialect" => [{"trim" => true}, RDF::Tabular::Dialect],
      }.each do |name, args|
        it name do
          klass = args.pop
          expect(described_class.new(*args)).to be_a(klass)
        end
      end
    end
  end

  describe "#embedded_metadata" do
    subject {described_class.new({"@type" => "Table"}, base: RDF::URI("http://example.org/base"), debug: @debug)}
    {
      "with defaults" => {
        input: "https://example.org/countries.csv",
        result: %({
          "@id": "https://example.org/countries.csv",
          "@type": "Table",
          "schema": {
            "@type": "Schema",
            "columns": [
              {"title": "countryCode"},
              {"title": "latitude"},
              {"title": "longitude"},
              {"title": "name"}
            ]
          }
        })
      },
      "with skipRows" => {
        input: "https://example.org/countries.csv",
        metadata: %({
          "@type": "Table",
          "dialect": {"skipRows": 1}
        }),
        result: %({
          "@id": "https://example.org/countries.csv",
          "@type": "Table",
          "schema": {
            "@type": "Schema",
            "columns": [
              {"title": "AD"},
              {"title": "42.546245"},
              {"title": "1.601554"},
              {"title": "Andorra"}
            ]
          },
          "notes": ["countryCode,latitude,longitude,name"]
        })
      },
      "with @language" => {
        input: "https://example.org/tree-ops.csv",
        metadata: %({
          "@context": {"@language": "en"},
          "@type": "Table"
        }),
        result: %({
          "@context": {"@language": "en"},
          "@id": "https://example.org/tree-ops.csv",
          "@type": "Table",
          "schema": {
            "@type": "Schema",
            "columns": [
              {"title": "GID"},
              {"title": "On Street"},
              {"title": "Species"},
              {"title": "Trim Cycle"},
              {"title": "Inventory Date"}
            ]
          },
          "language": "en"
        })
      },
    }.each do |name, props|
      it name do
        metadata = if props[:metadata]
          described_class.new(JSON.parse(props[:metadata]), base: RDF::URI("http://example.org/base"), debug: @debug)
        end

        metadata = metadata ? subject.merge(metadata).resources.first : subject
        result = metadata.embedded_metadata(props[:input])
        expect(result.to_json(JSON_STATE)).to produce(::JSON.parse(props[:result]).to_json(JSON_STATE), @debug)
      end
    end
  end

  describe "#each_row" do
    subject {
      described_class.new(JSON.parse(%({
        "@id": "https://example.org/countries.csv",
        "@type": "Table",
        "schema": {
          "@type": "Schema",
          "columns": [{
            "name": "countryCode",
            "title": "countryCode",
            "predicateUrl": "https://example.org/countries.csv#countryCode"
          }, {
            "name": "latitude",
            "title": "latitude",
            "predicateUrl": "https://example.org/countries.csv#latitude"
          }, {
            "name": "longitude",
            "title": "longitude",
            "predicateUrl": "https://example.org/countries.csv#longitude"
          }, {
            "name": "name",
            "title": "name",
            "predicateUrl": "https://example.org/countries.csv#name"
          }]
        }
      })), base: RDF::URI("http://example.org/base"), debug: @debug)
    }
    let(:input) {RDF::Util::File.open_file("https://example.org/countries.csv")}

    specify {expect {|b| subject.each_row(input, &b)}.to yield_control.exactly(3)}

    it "returns consecutive row numbers" do
      nums = subject.to_enum(:each_row, input).map(&:rownum)
      expect(nums).to eql([2, 3, 4])
    end

    it "returns resources BNode resources" do
      resources = subject.to_enum(:each_row, input).map(&:resource)
      expect(resources).to include(RDF::Node, RDF::Node, RDF::Node, RDF::Node)
    end

    it "returns resources values" do
      values = subject.to_enum(:each_row, input).map(&:values)
      expect(values).to produce([
        %w(AD 42.546245 1.601554 Andorra),
        %w(AE 23.424076 53.847818) << "United Arab Emirates",
        %w(AF 33.93911 67.709953 Afghanistan),
      ], @debug)
    end
  end

  describe "#common_properties" do
    it "FIXME"
  end

  describe "#merge" do
    {
      "two tables with same id" => {
        A: %({
          "@type": "Table",
          "@id": "http://example.org/table"
        }),
        B: [%({
          "@type": "Table",
          "@id": "http://example.org/table"
        })],
        R: %({
          "@type": "TableGroup",
          "resources": [{
            "@type": "Table",
            "@id": "http://example.org/table"
          }]
        })
      },
      "two tables with different id" => {
        A: %({
          "@type": "Table",
          "@id": "http://example.org/table1"
        }),
        B: [%({
          "@type": "Table",
          "@id": "http://example.org/table2"
        })],
        R: %({
          "@type": "TableGroup",
          "resources": [{
            "@type": "Table",
            "@id": "http://example.org/table1"
          }, {
            "@type": "Table",
            "@id": "http://example.org/table2"
          }]
        })
      },
      "table and table-group" => {
        A: %({
          "@type": "Table",
          "@id": "http://example.org/table1"
        }),
        B: [%({
          "@type": "TableGroup",
          "resources": [{
            "@type": "Table",
            "@id": "http://example.org/table2"
          }]
        })],
        R: %({
          "@type": "TableGroup",
          "resources": [{
            "@type": "Table",
            "@id": "http://example.org/table1"
          }, {
            "@type": "Table",
            "@id": "http://example.org/table2"
          }]
        })
      },
      "table-group and table" => {
        A: %({
          "@type": "TableGroup",
          "resources": [{
            "@type": "Table",
            "@id": "http://example.org/table1"
          }]
        }),
        B: [%({
          "@type": "Table",
          "@id": "http://example.org/table2"
        })],
        R: %({
          "@type": "TableGroup",
          "resources": [{
            "@type": "Table",
            "@id": "http://example.org/table1"
          }, {
            "@type": "Table",
            "@id": "http://example.org/table2"
          }]
        })
      },
      "table-group and two tables" => {
        A: %({
          "@type": "TableGroup",
          "resources": [{
            "@type": "Table",
            "@id": "http://example.org/table1"
          }]
        }),
        B: [%({
          "@type": "Table",
          "@id": "http://example.org/table2",
          "dc:label": "foo"
        }), %({
          "@type": "Table",
          "@id": "http://example.org/table2",
          "dc:label": "bar"
        })],
        R: %({
          "@type": "TableGroup",
          "resources": [{
            "@type": "Table",
            "@id": "http://example.org/table1"
          }, {
            "@type": "Table",
            "@id": "http://example.org/table2",
            "dc:label": [
              {"@value": "foo"},
              {"@value": "bar"}
            ]
          }]
        })
      },
    }.each do |name, props|
      it name do
        a = described_class.new(::JSON.parse(props[:A]))
        b = props[:B].map {|md| described_class.new(::JSON.parse(md))}
        r = described_class.new(::JSON.parse(props[:R]))
        expect(a.merge(*b)).to produce(r, @debug)
      end
    end

    %w(Template Schema Template Column Dialect).each do |t|
      it "does not merge into a #{t}" do
        a = described_class.new({}, type: t.to_sym)
        b = described_class.new({}, type: :TableGroup)
        expect {a.merge(b)}.to raise_error
      end

      it "does not merge from a #{t}" do
        a = described_class.new({}, type: :TableGroup)
        b = described_class.new({}, type: t.to_sym)
        expect {a.merge(b)}.to raise_error
      end
    end
  end

  describe "#merge!" do
    {
      "@context different language" => {
        A: %({"@context": {"@language": "en"}, "@type": "Table"}),
        B: %({"@context": {"@language": "de"}, "@type": "Table"}),
        R: %({"@context": {"@language": "en"}, "@type": "Table"})
      },
      "@context different base" => {
        A: %({"@context": {"@base": "http://example.org/foo"}, "@type": "Table"}),
        B: %({"@context": {"@base": "http://example.org/bar"}, "@type": "Table"}),
        R: %({"@context": {"@base": "http://example.org/foo"}, "@type": "Table"})
      },
      "@context mixed language and base" => {
        A: %({"@context": {"@language": "en"}, "@type": "Table"}),
        B: %({"@context": {"@base": "http://example.org/bar"}, "@type": "Table"}),
        R: %({"@context": {"@language": "en", "@base": "http://example.org/bar"}, "@type": "Table"})
      },
      "@context with different URI and objects" => {
        A: %({"@context": ["http://www.w3.org/ns/csvw", {"@language": "en"}], "@type": "Table"}),
        B: %({"@context": ["http://www.w3.org/ns/csvw/", {"@base": "http://example.org/foo"}], "@type": "Table"}),
        R: %({"@context": [
            "http://www.w3.org/ns/csvw",
            "http://www.w3.org/ns/csvw/",
            {"@language": "en", "@base": "http://example.org/foo"}
          ], "@type": "Table"})
      },
      "TableGroup with and without @id" => {
        A: %({"@id": "http://example.org/foo", "resources": [], "@type": "TableGroup"}),
        B: %({"resources": [], "@type": "TableGroup"}),
        R: %({"@id": "http://example.org/foo", "resources": [], "@type": "TableGroup"})
      },
      "TableGroup with and without @type" => {
        A: %({"resources": []}),
        B: %({"resources": [], "@type": "TableGroup"}),
        R: %({"resources": [], "@type": "TableGroup"})
      },
      "TableGroup with matching resources" => {
        A: %({"resources": [{"@id": "http://example.org/foo", "dc:title": "foo"}]}),
        B: %({"resources": [{"@id": "http://example.org/foo", "dc:description": "bar"}]}),
        R: %({"resources": [{
          "@id": "http://example.org/foo",
          "dc:title": "foo",
          "dc:description": [{"@value": "bar"}]
        }]})
      },
      "TableGroup with differing resources" => {
        A: %({"resources": [{"@id": "http://example.org/foo", "dc:title": "foo"}]}),
        B: %({"resources": [{"@id": "http://example.org/bar", "dc:description": "bar"}]}),
        R: %({
          "resources": [
            {"@id": "http://example.org/foo", "dc:title": "foo"},
            {"@id": "http://example.org/bar", "dc:description": "bar"}
          ]})
      },
      "Table with schemas always takes A" => {
        A: %({
          "@type": "Table",
          "@id": "http://example.com/foo",
          "schema": {"columns": [{"name": "foo"}]}
        }),
        B: %({
          "@type": "Table",
          "@id": "http://example.com/foo",
          "schema": {"columns": [{"name": "bar"}]}
        }),
        R: %({
          "@type": "Table",
          "@id": "http://example.com/foo",
          "schema": {"columns": [{"name": "foo"}]}
        }),
      },
      "Table with table-direction always takes A" => {
        A: %({"@type": "Table", "@id": "http://example.com/foo", "table-direction": "ltr"}),
        B: %({"@type": "Table", "@id": "http://example.com/foo", "table-direction": "rtl"}),
        R: %({"@type": "Table", "@id": "http://example.com/foo", "table-direction": "ltr"}),
      },
      "Table with dialect merges A and B" => {
        A: %({"@type": "Table", "@id": "http://example.com/foo", "dialect": {"encoding": "utf-8"}}),
        B: %({"@type": "Table", "@id": "http://example.com/foo", "dialect": {"skipRows": 0}}),
        R: %({"@type": "Table", "@id": "http://example.com/foo", "dialect": {"encoding": "utf-8", "skipRows": 0}}),
      },
      "Table with equivalent templates uses A" => {
        A: %({
          "@type": "Table",
          "@id": "http://example.com/foo",
          "templates": [{
            "@id": "http://example.com/foo",
            "targetFormat": "http://example.com/target",
            "templateFormat": "http://example.com/template",
            "source": "json"
          }]
        }),
        B: %({
          "@type": "Table",
          "@id": "http://example.com/foo",
          "templates": [{
            "@id": "http://example.com/foo",
            "targetFormat": "http://example.com/target",
            "templateFormat": "http://example.com/template",
            "source": "html"
          }]
        }),
        R: %({
          "@type": "Table",
          "@id": "http://example.com/foo",
          "templates": [{
            "@id": "http://example.com/foo",
            "targetFormat": "http://example.com/target",
            "templateFormat": "http://example.com/template",
            "source": "json"
          }]
        }),
      },
      "Table with differing templates appends B to A" => {
        A: %({
          "@type": "Table",
          "@id": "http://example.com/foo",
          "templates": [{
            "@id": "http://example.com/foo",
            "targetFormat": "http://example.com/target",
            "templateFormat": "http://example.com/template"
          }]
        }),
        B: %({
          "@type": "Table",
          "@id": "http://example.com/foo",
          "templates": [{
            "@id": "http://example.com/bar",
            "targetFormat": "http://example.com/targetb",
            "templateFormat": "http://example.com/templateb"
          }]
        }),
        R: %({
          "@type": "Table",
          "@id": "http://example.com/foo",
          "templates": [{
            "@id": "http://example.com/foo",
            "targetFormat": "http://example.com/target",
            "templateFormat": "http://example.com/template"
          }, {
            "@id": "http://example.com/bar",
            "targetFormat": "http://example.com/targetb",
            "templateFormat": "http://example.com/templateb"
          }]
        }),
      },
      "Table with common properties merges A and B" => {
        A: %({"@type": "Table", "@id": "http://example.com/foo", "rdfs:label": "foo"}),
        B: %({"@type": "Table", "@id": "http://example.com/foo", "rdfs:label": "bar"}),
        R: %({
          "@type": "Table",
          "@id": "http://example.com/foo",
          "rdfs:label": [
            {"@value": "foo"},
            {"@value": "bar"}
          ]
        }),
      },
      "Table with common properties in different languages merges A and B" => {
        A: %({
          "@context": {"@language": "en"},
          "@type": "Table",
          "@id": "http://example.com/foo",
          "rdfs:label": "foo"
        }),
        B: %({
          "@context": {"@language": "fr"},
          "@type": "Table",
          "@id": "http://example.com/foo",
          "rdfs:label": "foo"
        }),
        R: %({
          "@context": {"@language": "en"},
          "@type": "Table",
          "@id": "http://example.com/foo",
          "rdfs:label": [
            {"@value": "foo", "@language": "en"},
            {"@value": "foo", "@language": "fr"}
          ]
        }),
      },
      "Schema with matching columns merges A and B" => {
        A: %({"@type": "Schema", "columns": [{"name": "foo", "required": true}]}),
        B: %({"@type": "Schema", "columns": [{"name": "foo", "required": false}]}),
        R: %({"@type": "Schema", "columns": [{"name": "foo", "required": true}]}),
      },
      "Schema with differing columns takes A" => {
        A: %({"@type": "Schema", "columns": [{"name": "foo"}]}),
        B: %({"@type": "Schema", "columns": [{"name": "bar"}]}),
        R: %({"@type": "Schema", "columns": [{"name": "foo"}]}),
      },
      "Schema with matching column titles" => {
        A: %({"@type": "Schema", "columns": [{"title": "Foo"}]}),
        B: %({"@type": "Schema", "columns": [{"name": "foo", "title": "Foo"}]}),
        R: %({"@type": "Schema", "columns": [{"name": "foo", "title": {"und": "Foo"}}]}),
      },
      "Schema with primaryKey always takes A" => {
        A: %({"@type": "Schema", "primaryKey": "foo"}),
        B: %({"@type": "Schema", "primaryKey": "bar"}),
        R: %({"@type": "Schema", "primaryKey": "foo"}),
      },
      "Schema with matching foreignKey uses A" => {
        A: %({"@type": "Schema", "columns": [{"name": "foo"}], "foreignKeys": [{"columns": "foo", "reference": {"columns": "foo"}}]}),
        B: %({"@type": "Schema", "columns": [{"name": "foo"}], "foreignKeys": [{"columns": "foo", "reference": {"columns": "foo"}}]}),
        R: %({"@type": "Schema", "columns": [{"name": "foo"}], "foreignKeys": [{"columns": "foo", "reference": {"columns": "foo"}}]}),
      },
      "Schema with differing foreignKey uses A and B" => {
        A: %({"@type": "Schema", "columns": [{"name": "foo"}, {"name": "bar"}], "foreignKeys": [{"columns": "foo", "reference": {"columns": "foo"}}]}),
        B: %({"@type": "Schema", "columns": [{"name": "foo"}, {"name": "bar"}], "foreignKeys": [{"columns": "bar", "reference": {"columns": "bar"}}]}),
        R: %({"@type": "Schema", "columns": [{"name": "foo"}, {"name": "bar"}], "foreignKeys": [{"columns": "foo", "reference": {"columns": "foo"}}, {"columns": "bar", "reference": {"columns": "bar"}}]}),
      },
      "Schema with urlTemplate always takes A" => {
        A: %({"@type": "Schema", "urlTemplate": "foo"}),
        B: %({"@type": "Schema", "urlTemplate": "bar"}),
        R: %({"@type": "Schema", "urlTemplate": "foo"}),
      },
    }.each do |name, props|
      it name do
        WebMock.stub_request(:get, "http://www.w3.org/ns/csvw/").
          to_return(body: File.read(File.expand_path("../w3c-csvw/ns/csvw.jsonld", __FILE__)),
                    status: 200,
                    headers: { 'Content-Type' => 'application/ld+json'})
        a = described_class.new(::JSON.parse(props[:A]), debug: @debug)
        b = described_class.new(::JSON.parse(props[:B]))
        r = described_class.new(::JSON.parse(props[:R]))
        m = a.merge!(b)
        expect(m).to produce(r, @debug)
        expect(a).to equal m
      end
    end

    %w(TableGroup Table Template Schema Template Column Dialect).each do |ta|
      %w(TableGroup Table Template Schema Template Column Dialect).each do |tb|
        next if ta == tb
        it "does not merge #{tb} into #{ta}" do
          a = described_class.new({}, type: ta.to_sym)
          b = described_class.new({}, type: tb.to_sym)
          expect {a.merge!(b)}.to raise_error
        end
      end
    end
  end
end
