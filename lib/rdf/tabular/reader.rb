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
      super do
        # Base would be how we are to take this
        @options[:base] ||= base_uri.to_s if base_uri
        @options[:base] ||= input.base_uri if input.respond_to?(:base_uri)
        @options[:base] ||= input.path if input.respond_to?(:path)
        @options[:base] ||= input.filename if input.respond_to?(:filename)
        @options[:depth] ||= 0

        debug("Reader#initialize") {"input: #{input.inspect}, base: #{@options[:base]}"}
        depth do
          # load link metadata, if available
          metadata = nil
          metadata ||= if input.respond_to?(:links) && !@options[:no_found_metadata]
            link = input.links.find_link(%w(rel describedby))
            Metadata.open(link, options)
          end

          # For testing purposes, act as if a link header was provided with option
          metadata ||= if md = @options[:httpLink].to_s.match(/^.*<[^>]+>/) && !@options[:no_found_metadata]
            link = md[1]
            Metadata.open(link, options)
          end

          @input = input.is_a?(String) ? StringIO.new(input) : input

          # If input is JSON, then the input is the metadata
          if @options[:base] =~ /\.json(?:ld)?$/ ||
             @input.respond_to?(:content_type) && @input.content_type =~ %r(application/(?:ld+)json)
            @input = Metadata.new(@input, @options)
          end

          # Use user metadata
          user_metadata = options[:metadata]

          if @options[:base] && !@input.is_a?(Metadata) && !@options[:no_found_metadata]
            # Otherwise, look for metadata based on filename
            metadata ||= Metadata.open("#{@options[:base]}-metadata.json", @options) rescue nil

            # Otherwise, look for metadata in directory
            metadata ||= Metadata.open(RDF::URI(@options[:base]).join("metadata.json"), @options) rescue nil
          end

          # Extract file metadata, and left-merge if appropriate
          unless @input.is_a?(Metadata)
            # Use found metadata when parsing embedded data, but don't merge in until complete
            parse_md = user_metadata && metadata ?
                       user_metadata.merge(metadata) :
                       (user_metadata || metadata || Table.new({}))
            embedded_metadata = parse_md.embedded_metadata(@input, @options)

            @metadata = user_metadata ? user_metadata.merge(embedded_metadata) : embedded_metadata
            @metadata = @metadata.merge(metadata) if metadata
          end

          # If metadata is a TableGroup, get metadata for this table
          @metadata = @metadata.for_table(@options[:base]) if @metadata.is_a?(TableGroup)

          debug("Reader#initialize") {"input: #{input}, metadata: #{metadata}"}

          if block_given?
            case block.arity
              when 0 then instance_eval(&block)
              else block.call(self)
            end
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
          debug("each_statement: metadata") {input.inspect}
          depth do
            # Get Metadata to invoke and open referenced files
            case input.type
            when :TableGroup
              table_group = Node.new
              add_statement(0, table_group, RDF.type, CSVW.TableGroup)

              # Common Properties
              input.common_properties(table_group) do |statement|
                add_statement(0, statement)
              end

              input.resources.each do |table|
                add_statement(0, table_group, CSVW.table, table.id + "#table")
                Reader.open(table.id, options.merge(format: :tabular, metadata: table, base: table.id, no_found_metadata: true)) do |r|
                  r.each_statement(&block)
                end
              end
            when :Table
              Reader.open(input.id, options.merge(format: :tabular, metadata: input, base: input.id, no_found_metadata: true)) do |r|
                r.each_statement(&block)
              end
            else
              raise "Opened inappropriate metadata type: #{input.type}"
            end
          end
          return
        end

        # Output Table-Level RDF triples
        table_resource = metadata.id + "#table"
        add_statement(0, table_resource, RDF.type, CSVW.Table)

        # Distribution
        distribution = RDF::Node.new
        add_statement(0, table_resource, RDF::DCAT.distribution, distribution)
        add_statement(0, distribution, RDF.type, RDF::DCAT.Distribution)
        add_statement(0, distribution, RDF::DCAT.downloadURL, metadata.id)

        # Output table common properties
        metadata.common_properties(table_resource) do |statement|
          add_statement(0, statement)
        end

        # Column metadata
        metadata.schema.columns.compact.each do |column|
          pred = column.predicateUrl

          # SPEC FIXME: Output csvw:Column, if set
          add_statement(0, pred, RDF.type, RDF.Property)

          # Titles
          column.rdf_values(pred, "title", column.title) do |statement|
            # Make sure to use column language, not that from the context
            statement.object = RDF::Literal(statement.object.value, language: column.language) if statement.object.literal?
            statement.predicate = RDF::RDFS.label if statement.predicate == CSVW.title
            add_statement(0, statement)
          end

          # Common Properties
          column.common_properties(pred) do |statement|
            add_statement(0, statement)
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

          csv_path = @options[:base]

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
    # @overload add_statement(lineno, statement)
    #   Add a statement, object can be literal or URI or bnode
    #   @param [String] lineno
    #   @param [RDF::Statement] statement
    #   @yield [RDF::Statement]
    #   @raise [ReaderError] Checks parameter types and raises if they are incorrect if parsing mode is _validate_.
    #
    # @overload add_statement(lineno, subject, predicate, object)
    #   Add a triple
    #   @param [URI, BNode] subject the subject of the statement
    #   @param [URI] predicate the predicate of the statement
    #   @param [URI, BNode, Literal] object the object of the statement
    #   @raise [ReaderError] Checks parameter types and raises if they are incorrect if parsing mode is _validate_.
    def add_statement(node, *args)
      statement = args[0].is_a?(RDF::Statement) ? args[0] : RDF::Statement.new(*args)
      raise RDF::ReaderError, "#{statement.inspect} is invalid" if validate? && statement.invalid?
      debug(node) {"statement: #{RDF::NTriples.serialize(statement)}".chomp}
      @callback.call(statement)
    end

  end
end

