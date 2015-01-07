require 'rdf'

module RDF::Tabular
  ##
  # A Tabular Data to RDF parser in Ruby.
  #
  # @author [Gregg Kellogg](http://greggkellogg.net/)
  class Reader < RDF::Reader
    format Format
    include Utils

    # Metadata associated with the CSV
    #
    # @return [Metadata]
    attr_reader :metadata

    ##
    # Input open to read
    # @return [:read]
    attr_reader :input

    ##
    # Open a CSV file or URI. Also attempts to load relevant metadata
    #
    # @param  [String, #to_s] filename
    # @param  [Hash{Symbol => Object}] options
    #   @see `RDF::Reader.open` in RDF.rb and `#initialize`
    # @option options [Boolean] :noProv Do not output provenance information
    # @yield  [reader]
    # @yieldparam  [RDF::Tabular::Reader] reader
    # @yieldreturn [void] ignored
    def self.open(filename, options = {}, &block)
      Util::File.open_file(filename, options) do |file|
        # load link metadata, if available
        options = {base: filename, path: filename}.merge(options)

        metadata = options[:metadata]
        metadata ||= if file.respond_to?(:links)
          link = file.links.find_link(%w(rel describedby))
          Metadata.open(link, options)
        end

        # Otherwise, look for metadata based on filename
        metadata ||= Metadata.open("#{File.basename(filename)}-metadata.json", options)

        # Otherwise, look for metadata in directory
        metadata ||= Metadata.open(RDF::URI(filename).join("metadata.json"), options)

        # Return an open CSV with possible block
        RDF::Tabular::Reader.new(file, options.merge(metadata: metadata), &block)
      end
    end

    ##
    # Initializes the RDF::Tabular Reader instance.
    #
    # @param  [Util::File::RemoteDoc, IO, StringIO, Array<Array<String>>]       input
    #   An opened file possibly JSON Metadata,
    #   or an Array used as an internalized array of arrays
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
        @options[:base] ||= input.base_uri if input.respond_to?(:base_uri)

        @input = input.is_a?(String) ? StringIO.new(input) : input

        # If input is JSON, then the input is the metadata
        if @options[:base] =~ /\.json(?:ld)?$/ ||
           @input.respond_to?(:content_type) && @input.content_type =~ %r(application/(?:ld+)json)
          @input = Metadata.new(@input, options)
        end

        # Use either passed metadata, or create an empty one to start
        @metadata = options.fetch(:metadata, Table.new({}, options))

        # Extract file metadata, and left-merge if appropriate
        unless @input.is_a?(Metadata)
          embedded_metadata = @metadata.embedded_metadata(@input, @options)
          @metadata = embedded_metadata.merge(@metadata)
        end

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

        start_time = Time.now

        # Construct metadata from that passed from file open, along with information from the file.
        if input.is_a?(Metadata)
          # Get Metadata to invoke and open referenced files
          case input.type
          when :TableGroup
            table_group = Node.new
            add_statement(0, table_group, RDF.type, CSVW.TableGroup)

            # Common Properties
            input.common_properties.each do |prop, value|
              pred = input.context.expand_iri(prop)
              add_statement(0, table_group, pred, value)
            end

            input.resources.each do |table|
              add_statement(0, table_group, CSVW.table, table.id + "#table")
              Reader.new(table.id, options.merge(metadata: table)).each_statemenet(&block)
            end
          when :Table
            Reader.new(input.id, options.merge(metadata: table)).each_statemenet(&block)
          else
            raise "Opened inappropriate metadata type: #{input.type}"
          end
          return
        end

        # Output Table-Level RDF triples
        # SPEC FIXME: csvw:Table, not csv:Table
        table_resource = metadata.id + "#table"
        add_statement(0, table_resource, RDF.type, CSVW.Table)

        # Distribution
        distribution = RDF::Node.new
        add_statement(0, table_resource, RDF::DCAT.distribution, distribution)
        add_statement(0, distribution, RDF.type, RDF::DCAT.Distribution)
        add_statement(0, distribution, RDF::DCAT.downloadURL, metadata.id)

        # Output table common properties
        metadata.common_properties.each do |prop, value|
          pred = metadata.context.expand_iri(prop)
          add_statement(0, table_resource, pred, value)
        end

        # Column metadata
        metadata.schema.columns.each do |column|
          pred = column.predicateUrl

          # SPEC FIXME: Output csvw:Column, if set
          add_statement(0, pred, RDF.type, RDF.Property)

          # Titles
          column.rdf_values(:title, column.title) {|v| add_statement(0, pred, RDF::RDFS.label, v)}

          # Common Properties
          column.common_properties.each do |prop, value|
            pred = column.context.expand_iri(prop)
            add_statement(0, table_group, pred, value)
          end
        end

        # Input is file containing CSV data.
        # Output ROW-Level statements
        metadata.each_row(input) do |row|
          # Output row-level metadata
          add_statement(row.rownum, table_resource, CSVW.row, row.resource)
          row.values.each_with_index do |value, index|
            column = metadata.schema.columns[index]
            Array(value).each do |v|
              add_statement(row.rownum, row.resource, column.predicateUrl, v)
            end
          end
        end

        # Provenance
        unless @options[:noProv]
          activity = RDF::Node.new
          add_statement(0, table_resource, RDF::PROV.activity, activity)
          add_statement(0, activity, RDF.type, RDF::PROV.Activity)
          add_statement(0, activity, RDF::PROV.startedAtTime, RDF::Literal::DateTime.new(start_time))
          add_statement(0, activity, RDF::PROV.endedAtTime, RDF::Literal::DateTime.new(Time.now))

          csv_path = @options[:path] ||
                     (@input.filename if @input.respond_to?(:filename)) ||
                     (@input.path if @input.respond_to?(:path))

          if csv_path && !@input.is_a?(Metadata)
            usage = RDF::Node.new
            add_statement(0, activity, RDF::PROV.qualifiedUsage, usage)
            add_statement(0, usage, RDF.type, RDF::PROV.Usage)
            add_statement(0, usage, RDF::PROV.Entity, RDF::URI(csv_path))
            # FIXME: needs to be defined in vocabulary
            add_statement(0, usage, RDF::PROV.hadRole, CSVW.to_uri + "csvEncodedTabularData")
          end

          if @metadata.filename && @metadata != @input
            usage = RDF::Node.new
            add_statement(0, activity, RDF::PROV.qualifiedUsage, usage)
            add_statement(0, usage, RDF.type, RDF::PROV.Usage)
            add_statement(0, usage, RDF::PROV.Entity, RDF::URI(@input.filename))
            # FIXME: needs to be defined in vocabulary
            add_statement(0, usage, RDF::PROV.hadRole, CSVW.to_uri + "tabularMetadata")
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

    private
    ##
    # add a statement, object can be literal or URI or bnode
    #
    # @param [Nokogiri::XML::Node, any] node XML Node or string for showing context
    #
    # @param [URI, BNode] subject the subject of the statement
    # @param [URI] predicate the predicate of the statement
    # @param [URI, BNode, Literal] object the object of the statement
    # @return [Statement] Added statement
    # @raise [ReaderError] Checks parameter types and raises if they are incorrect if parsing mode is _validate_.
    def add_statement(node, subject, predicate, object)
      statement = RDF::Statement.new(subject, predicate, object)
      raise RDF::ReaderError, "#{statement.inspect} is invalid" if validate? && statement.invalid?
      debug(node) {"statement: #{RDF::NTriples.serialize(statement)}"}
      @callback.call(statement)
    end

  end
end

