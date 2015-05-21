# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/spec/format'

describe RDF::Tabular::Format do
  it_behaves_like 'an RDF::Format' do
    let(:format_class) {RDF::Tabular::Format}
  end

  describe ".for" do
    formats = [
      :tabular,
      'etc/doap.csv',
      {:file_name      => 'etc/doap.csv'},
      {:file_extension => 'csv'},
      {:content_type   => 'text/csv'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        expect(RDF::Tabular::Format).to include RDF::Format.for(arg)
      end
    end
  end

  describe "#to_sym" do
    specify {expect(described_class.to_sym).to eq :tabular}
  end
end
