# coding: utf-8
$:.unshift "."
require 'spec_helper'

describe RDF::CSV::Metadata do
  before(:each) do
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

  describe ".new" do
    context "parses example metadata" do
      Dir.glob(File.expand_path("../data/*.json", __FILE__)).each do |filename|
        context filename do
          specify {expect {RDF::CSV::Metadata.open(filename)}.not_to raise_error}
        end
      end
    end

    context "validates example metadata" do
      Dir.glob(File.expand_path("../data/*.json", __FILE__)).each do |filename|
        context filename do
          specify do
            expect{RDF::CSV::Metadata.open(filename).validate!}.not_to raise_error
          end
        end
      end
    end

    shared_examples "inherited properties" do
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
        }
      }.each do |prop, params|
        context prop.to_s do
          it "validates" do
            params[:valid].each do |v|
              subject[prop.to_sym] = v
              expect(subject).to be_valid
            end
          end
          it "invalidates" do
            params[:invalid].each do |v|
              subject[prop.to_sym] = v
              expect(subject).not_to be_valid
            end
          end
        end
      end
    end

    describe "Column" do
      subject {described_class.new({"name" => "foo"}, base: RDF::URI("http://example.org/base"))}
      specify {is_expected.to be_valid}
      it_behaves_like("inherited properties")

      it "detects invalid names" do
        [1, true, nil, "_foo"].each {|v| expect(described_class.new("name" => v)).not_to be_valid}
      end

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
              subject[prop] = v
              expect(subject).to be_valid
            end
          end
          it "invalidates" do
            params[:invalid].each do |v|
              subject[prop] = v
              expect(subject).not_to be_valid
            end
          end
        end
      end
    end
  end
end
