module RDF::CSV
  ##
  # Tabular Data/CSV format specification.
  #
  # @example Obtaining a CSV format class
  #     RDF::Format.for(:csv)            #=> RDF::CSV::Format
  #     RDF::Format.for(:tsv)            #=> RDF::CSV::Format
  #     RDF::Format.for("etc/foaf.csv")
  #     RDF::Format.for("etc/foaf.tsv")
  #     RDF::Format.for(:file_name      => "etc/foaf.csv")
  #     RDF::Format.for(:file_name      => "etc/foaf.tsv")
  #     RDF::Format.for(:file_extension => "csv")
  #     RDF::Format.for(:file_extension => "tsv")
  #     RDF::Format.for(:content_type   => "text/csv")
  #     RDF::Format.for(:content_type   => "text/tab-separated-values")
  #
  # @example Obtaining serialization format MIME types
  #     RDF::Format.content_types      #=> {"text/csv" => [RDF::CSV::Format]}
  #
  # @example Obtaining serialization format file extension mappings
  #     RDF::Format.file_extensions    #=> {:csv => "text/csv"}
  #
  # @see http://www.w3.org/TR/rdf-testcases/#ntriples
  class Format < RDF::Format
    content_type     'text/csv',
                     extensions: [:csv, :tsv],
                     alias: 'text/tab-separated-values'
    content_encoding 'utf-8'

    reader { RDF::CSV::Reader }

    ##
    # Sample detection to see if it matches JSON-LD
    #
    # Use a text sample to detect the format of an input file. Sub-classes implement
    # a matcher sufficient to detect probably format matches, including disambiguating
    # between other similar formats.
    #
    # @param [String] sample Beginning several bytes (~ 1K) of input.
    # @return [Boolean]
    def self.detect(sample)
      !!sample.match(/^(?:(?:\w )+,(?:\w ))$/)
    end
  end
end
