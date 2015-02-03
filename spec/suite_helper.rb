$:.unshift "."
require 'spec_helper'
require 'rdf/turtle'
require 'json/ld'
require 'open-uri'

# For now, override RDF::Utils::File.open_file to look for the file locally before attempting to retrieve it
module RDF::Util
  module File
    REMOTE_PATH = "http://w3c.github.io/csvw/"
    LOCAL_PATH = ::File.expand_path("../w3c-csvw", __FILE__) + '/'

    ##
    # Override to use Patron for http and https, Kernel.open otherwise.
    #
    # @param [String] filename_or_url to open
    # @param  [Hash{Symbol => Object}] options
    # @option options [Array, String] :headers
    #   HTTP Request headers.
    # @return [IO] File stream
    # @yield [IO] File stream
    def self.open_file(filename_or_url, options = {}, &block)
      case filename_or_url.to_s
      when /^file:/
        path = filename_or_url[5..-1]
        Kernel.open(path.to_s, &block)
      when %r{^(#{REMOTE_PATH}|http://www.w3.org/ns/csvw)}
        begin
          #puts "attempt to open #{filename_or_url} locally"
          localpath = case filename_or_url.to_s
          when 'http://www.w3.org/ns/csvw' then ::File.join(LOCAL_PATH, "ns/csvw.jsonld")
          else filename_or_url.to_s.sub(REMOTE_PATH, LOCAL_PATH)
          end
          response = begin
            ::File.open(localpath)
          rescue Errno::ENOENT
            Kernel.open(filename_or_url.to_s, "r:utf-8", 'Accept' => "application/ld+json, application/json, text/csv")
          end
          document_options = {
            base_uri:     RDF::URI(filename_or_url),
            charset:      Encoding::UTF_8,
            code:         200,
            headers:      {}
          }
          #puts "use #{filename_or_url} locally"
          document_options[:headers][:content_type] = case filename_or_url.to_s
          when /\.csv$/   then 'text/csv'
          when /\.json$/   then 'application/json'
          when /\.jsonld$/ then 'application/ld+json'
          else                  'unknown'
          end

          document_options[:headers][:content_type] = response.content_type if response.respond_to?(:content_type)
          # For overriding content type from test data
          document_options[:headers][:content_type] = options[:contentType] if options[:contentType]

          # For overriding Link header from test data
          document_options[:headers][:link] = options[:httpLink] if options[:httpLink]

          remote_document = RDF::Util::File::RemoteDocument.new(response.read, document_options)
          if block_given?
            yield remote_document
          else
            remote_document
          end
        end
      else
        Kernel.open(filename_or_url.to_s, "r:utf-8", &block)
      end
    end
  end
end

module Fixtures
  module SuiteTest
    BASE = "http://w3c.github.io/csvw/tests/"
    FRAME = JSON.parse(%q({
      "@context": {
        "xsd": "http://www.w3.org/2001/XMLSchema#",
        "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
        "mf": "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#",
        "mq": "http://www.w3.org/2001/sw/DataAccess/tests/test-query#",
        "csvt": "http://w3c.github.io/csvw/tests/vocab#",

        "id": "@id",
        "type": "@type",
        "action":  {"@id": "mf:action", "@type": "@id"},
        "approval":  {"@id": "csvt:approval", "@type": "@id"},
        "comment": "rdfs:comment",
        "contentType": "csvt:contentType",
        "data": {"@id": "mq:data", "@type": "@id"},
        "entries": {"@id": "mf:entries", "@type": "@id", "@container": "@list"},
        "httpLink": "csvt:httpLink",
        "metadata": {"@id": "csvt:metadata", "@type": "@id"},
        "name": "mf:name",
        "noProv": {"@id": "csvt:noProv", "@type": "xsd:boolean"},
        "option": "csvt:option",
        "result": {"@id": "mf:result", "@type": "@id"}
      },
      "@type": "mf:Manifest",
      "entries": {}
    }))
 
    class Manifest < JSON::LD::Resource
      def self.open(file)
        #puts "open: #{file}"
        prefixes = {}
        g = RDF::Repository.load(file, format:  :ttl)
        JSON::LD::API.fromRDF(g) do |expanded|
          JSON::LD::API.frame(expanded, FRAME) do |framed|
            yield Manifest.new(framed['@graph'].first)
          end
        end
      end

      # @param [Hash] json framed JSON-LD
      # @return [Array<Manifest>]
      def self.from_jsonld(json)
        json['@graph'].map {|e| Manifest.new(e)}
      end

      def entries
        # Map entries to resources
        attributes['entries'].map {|e| Entry.new(e)}
      end
    end
 
    class Entry < JSON::LD::Resource
      attr_accessor :debug
      attr_accessor :metadata

      def id
        attributes['id']
      end

      def base
        action
      end

      # Alias data and query
      def input
        @input ||= RDF::Util::File.open_file(action) {|f| f.read}
      end

      def expected
        @expected ||= RDF::Util::File.open_file(result) {|f| f.read}
      end
      
      def evaluate?
        type.include?("To")
      end
      
      def sparql?
        type.include?("Sparql")
      end

      def rdf?
        type.include?("Rdf")
      end

      def json?
        type.include?("Json")
      end

      def syntax?
        type.include?("Syntax")
      end

      def positive_test?
        !negative_test?
      end
      
      def negative_test?
        type.include?("Negative")
      end

      def reader_options
        res = {}
        res[:noProv] = option['noProv'] == 'true' if option && option.has_key?('noProv')
        res[:metadata] = option['metadata'] if option && option.has_key?('metadata')
        res[:httpLink] = httpLink if attributes['httpLink']
        res[:contentType] = contentType if attributes['contentType']
        res
      end
    end
  end
end
