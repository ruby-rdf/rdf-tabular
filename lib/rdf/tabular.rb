$:.unshift(File.expand_path("..", __FILE__))
require 'rdf' # @see http://rubygems.org/gems/rdf
begin
  require 'byebug'  # REMOVE ME
rescue LoadError
end
require 'csv'

module RDF
  ##
  # **`RDF::Tabular`** is a Tabular/CSV extension for RDF.rb.
  #
  # @see http://w3c.github.io/csvw/
  #
  # @author [Gregg Kellogg](http://greggkellogg.net/)
  module Tabular
    require 'rdf/tabular/format'
    require 'rdf/tabular/utils'
    autoload :Column,     'rdf/tabular/metadata'
    autoload :CSVW,       'rdf/tabular/csvw'
    autoload :Dialect,    'rdf/tabular/metadata'
    autoload :JSON,       'rdf/tabular/literal'
    autoload :Metadata,   'rdf/tabular/metadata'
    autoload :Reader,     'rdf/tabular/reader'
    autoload :Schema,     'rdf/tabular/metadata'
    autoload :Table,      'rdf/tabular/metadata'
    autoload :TableGroup, 'rdf/tabular/metadata'
    autoload :Template,   'rdf/tabular/metadata'
    autoload :VERSION,    'rdf/tabular/version'

    def self.debug; @debug; end
    def self.debug=(value); @debug = value.is_a?(Array) ? value : StringIO.new; end
  end
end