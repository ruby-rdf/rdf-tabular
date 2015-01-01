$:.unshift(File.expand_path("..", __FILE__))
require 'rdf' # @see http://rubygems.org/gems/rdf
begin
  require 'byebug'  # REMOVE ME
rescue LoadError
end

module RDF
  ##
  # **`RDF::CSV`** is a CSV extension for RDF.rb.
  #
  # @see http://w3c.github.io/csvw/
  #
  # @author [Gregg Kellogg](http://greggkellogg.net/)
  module CSV
    require 'rdf/csv/format'
    autoload :CSVW,     'rdf/csv/csvw'
    autoload :JSON,     'rdf/csv/literal'
    autoload :Metadata, 'rdf/csv/metadata'
    autoload :Reader,   'rdf/csv/reader'
    autoload :VERSION,  'rdf/csv/version'
  end
end