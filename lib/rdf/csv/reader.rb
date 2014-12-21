require 'rdf'

module RDF::CSV
  ##
  # A Tabular Data to RDF parser in Ruby.
  #
  # @author [Gregg Kellogg](http://greggkellogg.net/)
  class Reader < RDF::Reader
    format Format

    # Metadata associated with the CSV
    #
    # @return [Metadata]
    attr_reader :metadata

    ##
    # Open a CSV file or URI. Also attempts to load relevant metadata
    #
    # @param  [String, #to_s] filename
    # @param  [Hash{Symbol => Object}] options
    #   see `RDF::Util::File.open_file` in RDF.rb
    # @yield  [reader]
    # @yieldparam  [RDF::CSV::Reader] reader
    # @yieldreturn [void] ignored
    def self.open(filename, options = {}, &block)
      Util::File.open_file(filename, options) do |file|
        # load link metadata, if available
        metadata = if file.respond_to?(:links)
          link = file.links.find_link(%w(rel describedby))
          Metadata.open(link, options)
        end

        # Otherwise, look for metadata based on filename
        metadata ||= Metadata.open("#{filename}-metadata.json", options)

        # Otherwise, look for metadata in directory
        metadata ||= Metadata.open(RDF::URI(filename).join("metadata.json"), options)

        if metadata
          # Merge options
          metadata.merge!(options[:metadata]) if options[:metadata]
        else
          # Just use options
          metadata = options[:metadata]
        end

        # Return an open CSV with possible block
        RDF::CSV::Reader.new(file, options.merge(metadata: metadata), &block)
      end
    end

    ##
    # Initializes the RDF::CSV Reader instance.
    #
    # @param  [IO, File, String]       input
    # @param  [Hash{Symbol => Object}] options
    #   any additional options (see `RDF::Reader#initialize`)
    # @option options [Metadata, Hash] :metadata extracted when file opened
    # @option options [Metadata, Hash] :user_metadata user supplied metadata, merged on top of extracted metadata
    # @yield  [reader] `self`
    # @yieldparam  [RDF::Reader] reader
    # @yieldreturn [void] ignored
    # @raise [RDF::ReaderError] if the CSV document cannot be loaded
    def initialize(input = $stdin, options = {}, &block)
      options[:base_uri] ||= options[:base]
      super do
        @options[:base] ||= base_uri.to_s if base_uri
        # Construct metadata from that passed from file open, along with information from the file.
        @metadata = Metadata.new(options[:metadata]).table_data(base_uri, input)

        # Merge any user-supplied metadata
        # SPEC CONFUSION: Note issue described in https://github.com/w3c/csvw/issues/76#issuecomment-65914880
        @metadata.merge(Metadata.new(options[:user_metadata])) if options[:user_metadata]
        @doc = input.respond_to?(:read) ? input : StringIO.new(input.to_s)

        if block_given?
          case block.arity
            when 0 then instance_eval(&block)
            else block.call(self)
          end
        end
      end
    end

    ##
    # @private
    # @see   RDF::Reader#each_statement
    def each_statement(&block)
      if block_given?
        @callback = block

        # Output Table-Level RDF triples
        # SPEC FIXME: csvw:Table, not csv:Table
        add_triple(0, RDF::URI(metadata.id), RDF.type, CSVW.Table) if metadata.type?

        # Output other table-level metadata
        # SPEC AMBIGUITY(2RDF):
        #   output all optional properties in DC space? (they're typically defined in CSVM space)
        #   output all namespaced properties?
        #   output all non-namespaced properties which aren't specifically defined in CSVM in DC space?
        # We assume to only output namesspaced-properties
        metadata.expanded_annotation_properties.each do |prop, values|
          Array(value).each do |v|
            # Assume prop and value(s) are in RDF form? or expand here?
            add_triple(0, metadata.uri, RDF::URI(prop), v)
          end
        end

        # SPEC CONFUSION(2RDF):
        #   Where to output column-level, vs. cell-level metadata?
        metadata.columns.each do |column|
          # SPEC FIXME: Output csvw:Column, if set
          add_triple(0, RDF::URI(column.uri), RDF.type, CSVW.Column) if column.type?
          column.expanded_annotation_properties.each do |prop, values|
            Array(value).each do |v|
              # Assume prop and value(s) are in RDF form? or expand here?
              add_triple(0, RDF::URI(column.uri), RDF::URI(prop), v)
            end
          end
        end

        # Output Cell-Level RDF triples
        metadata.rows.each do |row|
          # Output row-level metadata
          add_triple(row.rownum, RDF::URI(row.uri), CSVW.row, RDF::Literal::Integer(row.rownum))
          add_triple(row.rownum, RDF::URI(row.uri), RDF.type, CSVW.Row) if row.type?
          row.columns.each_with_index do |column|
            add_triple("#{row.rownum}", RDF::URI(row.uri), RDF::URI(column.uri), column.rdf_value)
          end
        end
      end
      enum_for(:each_statement)
    end

    ##
    # @private
    # @see   RDF::Reader#each_triple
    def each_triple(&block)
      if block_given?
        each_statement do |statement|
          block.call(*statement.to_triple)
        end
      end
      enum_for(:each_triple)
    end
  end
end

