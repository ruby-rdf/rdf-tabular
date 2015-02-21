require 'json'
require 'json/ld'
require 'bcp47'
require 'addressable/template'

##
# CSVM Metadata processor
#
# * Extracts Metadata from file or Hash definition
# * Merges multiple Metadata definitions
# * Extract Metadata from a CSV file
# * Return table-level annotations
# * Return Column-level annotations
# * Return row iterator with column information
#
# @author [Gregg Kellogg](http://greggkellogg.net/)
module RDF::Tabular
  class Metadata
    include Utils

    # Hash representation
    attr_accessor :object

    # Inheritect properties, valid for all types
    INHERITED_PROPERTIES = {
      aboutUrl:           :uri_template,
      datatype:           :atomic,
      default:            :atomic,
      format:             :atomic,
      fractionDigits:     :atomic,
      lang:               :atomic,
      length:             :atomic,
      maxExclusive:       :atomic,
      maximum:            :atomic,
      maxInclusive:       :atomic,
      maxLength:          :atomic,
      minExclusive:       :atomic,
      minimum:            :atomic,
      minInclusive:       :atomic,
      minLength:          :atomic,
      null:               :atomic,
      propertyUrl:        :uri_template,
      separator:          :atomic,
      textDirection:      :atomic,
      totalDigits:        :atomic,
      valueUrl:           :uri_template,
    }.freeze

    # Valid datatypes
    DATATYPES = {
      anyAtomicType:      RDF::XSD.anySimpleType,
      anyURI:             RDF::XSD.anyURI,
      base64Binary:       RDF::XSD.basee65Binary,
      boolean:            RDF::XSD.boolean,
      byte:               RDF::XSD.byte,
      date:               RDF::XSD.date,
      dateTime:           RDF::XSD.dateTime,
      dateTimeDuration:   RDF::XSD.dateTimeDuration,
      dateTimeStamp:      RDF::XSD.dateTimeStamp,
      decimal:            RDF::XSD.decimal,
      double:             RDF::XSD.double,
      float:              RDF::XSD.float,
      ENTITY:             RDF::XSD.ENTITY,
      gDay:               RDF::XSD.gDay,
      gMonth:             RDF::XSD.gMonth,
      gMonthDay:          RDF::XSD.gMonthDay,
      gYear:              RDF::XSD.gYear,
      gYearMonth:         RDF::XSD.gYearMonth,
      hexBinary:          RDF::XSD.hexBinary,
      int:                RDF::XSD.int,
      integer:            RDF::XSD.integer,
      lang:               RDF::XSD.language,
      language:           RDF::XSD.language,
      long:               RDF::XSD.long,
      Name:               RDF::XSD.Name,
      NCName:             RDF::XSD.NCName,
      negativeInteger:    RDF::XSD.negativeInteger,
      nonNegativeInteger: RDF::XSD.nonNegativeInteger,
      nonPositiveInteger: RDF::XSD.nonPositiveInteger,
      normalizedString:   RDF::XSD.normalizedString,
      NOTATION:           RDF::XSD.NOTATION,
      positiveInteger:    RDF::XSD.positiveInteger,
      QName:              RDF::XSD.Qname,
      short:              RDF::XSD.short,
      string:             RDF::XSD.string,
      time:               RDF::XSD.time,
      token:              RDF::XSD.token,
      unsignedByte:       RDF::XSD.unsignedByte,
      unsignedInt:        RDF::XSD.unsignedInt,
      unsignedLong:       RDF::XSD.unsignedLong,
      unsignedShort:      RDF::XSD.unsignedShort,
      yearMonthDuration:  RDF::XSD.yearMonthDuration,

      any:                RDF::XSD.anySimpleType,
      binary:             RDF::XSD.base64Binary,
      datetime:           RDF::XSD.dateTime,
      html:               RDF.HTML,
      json:               RDF::Tabular::CSVW.JSON,
      number:             RDF::XSD.double,
      xml:                RDF.XMLLiteral,
    }

    # A name is restricted according to the following RegExp.
    # @return [RegExp]
    NAME_SYNTAX = %r(\A(?:_col|[a-zA-Z0-9])[a-zA-Z0-9\._]*\z)

    # ID of this Metadata
    # @return [RDF::URI]
    attr_reader :id

    # URL of related resource
    # @return [RDF::URI]
    attr_reader :url

    # Parent of this Metadata (TableGroup for Table, ...)
    # @return [Metadata]
    attr_reader :parent

    # Filename(s) (URI) of opened metadata, if any
    # May be plural when merged
    # @return [Array<RDF::URI>] filenames
    attr_reader :filenames

    ##
    # Attempt to retrieve the file at the specified path. If it is valid metadata, create a new Metadata object from it, otherwise, an empty Metadata object
    #
    # @param [String] path
    # @param [Hash{Symbol => Object}] options
    #   see `RDF::Util::File.open_file` in RDF.rb
    def self.open(path, options = {})
      options = options.merge(
        headers: {
          'Accept' => 'application/ld+json, application/json'
        }
      )
      path = "file:" + path unless path =~ /^\w+:/
      RDF::Util::File.open_file(path, options) do |file|
        self.new(file, options.merge(base: path, filenames: path))
      end
    end

    ##
    # Return metadata for a file, based on user-specified, embedded and path-relative locations from an input file
    # @param [IO, StringIO] input
    # @param [Hash{Symbol => Object}] options
    # @option options [Metadata, Hash, String, RDF::URI] :metadata user supplied metadata, merged on top of extracted metadata. If provided as a URL, Metadata is loade from that location
    # @option options [RDF::URI] :base
    #   The Base URL to use when expanding the document. This overrides the value of `input` if it is a URL. If not specified and `input` is not an URL, the base URL defaults to the current document URL if in a browser context, or the empty string if there is no document context.
    # @return [Metadata]
    def self.for_input(input, options = {})
      base = options[:base]

      # Use user metadata
      user_metadata = case options[:metadata]
      when Metadata then options[:metadata]
      when Hash
        Metadata.new(options[:metadata], options.merge(reason: "load user metadata: #{options[:metadata].inspect}"))
      when String, RDF::URI
        Metadata.open(options[:metadata], options.merge(reason: "load user metadata: #{options[:metadata].inspect}"))
      end

      found_metadata = []
      if !options[:no_found_metadata]
        # load link metadata, if available
        if input.respond_to?(:links) && 
          link = input.links.find_link(%w(rel describedby))
          link = RDF::URI(base).join(link.href)
          begin
            found_metadata << Metadata.open(link, options.merge(reason: "load linked metadata: #{link}")) if link
          rescue
            debug("for_input", options) {"failed to load linked metadata #{link}: #{$!}"}
          end
        end

        if base
          # Otherwise, look for metadata based on filename
          begin
            loc = "#{base}-metadata.json"
            found_metadata << Metadata.open(loc, options.merge(reason: "load found metadata: #{loc}"))
          rescue
            debug("for_input", options) {"failed to load found metadata #{loc}: #{$!}"}
          end

          # Otherwise, look for metadata in directory
          begin
            loc = RDF::URI(base).join("metadata.json")
            found_metadata << Metadata.open(loc, options.merge(reason: "load found metadata: #{loc}"))
          rescue
            debug("for_input", options) {"failed to load found metadata #{loc}: #{$!}"}
          end
        end
      end

      # Extract file metadata, and left-merge if appropriate
      # Use found metadata when parsing embedded data, but don't merge in until complete
      md, *rest = found_metadata.dup.unshift(user_metadata).compact
      parse_md = md ? md.merge(*rest) : Table.new({})
      embedded_metadata = parse_md.embedded_metadata(input, options)

      # Merge user metadata with embedded metadata 
      embedded_metadata = user_metadata.merge(embedded_metadata) if user_metadata

      # Merge embedded metadata with found
      embedded_metadata.merge(*found_metadata)
    end

    ##
    # @private
    def self.new(input, options = {})
      # Triveal case
      return input if input.is_a?(Metadata)

      context = options[:context]
      object = input

      # Only define context if input is readable, and there's no parent
      if !options[:parent] || !input.is_a?(Hash) || input.has_key?('@context')
        # Open as JSON-LD to get context
        jsonld = ::JSON::LD::API.new(input, context)

        # Set the context unless we're called with a parent
        unless options[:parent]
          context ||= ::JSON::LD::Context.new
          # If we still haven't found 'csvw', load the default context
          if !context.term_definitions.has_key?('csvw') &&
             !jsonld.context.term_definitions.has_key?('csvw')
            input.rewind if input.respond_to?(:rewind)

            # Also use context from jsonld value in addition to default
            use_context = case jsonld.value['@context']
            when Array  then %w(http://www.w3.org/ns/csvw) + jsonld.value['@context']
            when Hash then ['http://www.w3.org/ns/csvw', jsonld.value['@context']]
            else             'http://www.w3.org/ns/csvw'
            end
          
            jsonld = ::JSON::LD::API.new(input, use_context)
          end

          # If we already have a context, merge in the context from this object, otherwise, set it to this object
          context.merge!(jsonld.context)
          options = options.merge(context: context)
        end

        # Get both parsed JSON and context from jsonld
        object = jsonld.value
      end

      klass = case
        when !self.equal?(RDF::Tabular::Metadata)
          self # subclasses can be directly constructed without type dispatch
        else
          type = if options[:type]
            type = options[:type].to_sym
            raise "If provided, type must be one of :TableGroup, :Table, :Template, :Schema, :Column, :Dialect]" unless
              [:TableGroup, :Table, :Template, :Schema, :Column, :Dialect].include?(type)
            type
          end

          # Figure out type by @type
          type ||= object['@type']

          # Figure out type by site
          object_keys = object.keys.map(&:to_s)
          type ||= case
          when %w(resources).any? {|k| object_keys.include?(k)} then :TableGroup
          when %w(dialect tableSchema templates).any? {|k| object_keys.include?(k)} then :Table
          when %w(targetFormat templateFormat source).any? {|k| object_keys.include?(k)} then :Template
          when %w(columns primaryKey foreignKeys urlTemplate).any? {|k| object_keys.include?(k)} then :Schema
          when %w(name required).any? {|k| object_keys.include?(k)} then :Column
          when %w(commentPrefix delimiter doubleQuote encoding header headerColumnCount headerRowCount).any? {|k| object_keys.include?(k)} then :Dialect
          when %w(lineTerminator quoteChar skipBlankRows skipColumns skipInitialSpace skipRows trim).any? {|k| object_keys.include?(k)} then :Dialect
          end

          case type.to_s.to_sym
          when :TableGroup then RDF::Tabular::TableGroup
          when :Table then RDF::Tabular::Table
          when :Template then RDF::Tabular::Template
          when :Schema then RDF::Tabular::Schema
          when :Column then RDF::Tabular::Column
          when :Dialect then RDF::Tabular::Dialect
          else
            raise "Unkown metadata type: #{type.inspect}"
          end
        end

      md = klass.allocate
      md.send(:initialize, object, options)
      md
    end

    ##
    # Create Metadata from IO, Hash or String
    #
    # @param [Metadata, Hash, #read] input
    # @param [Hash{Symbol => Object}] options
    # @option options [:TableGroup, :Table, :Template, :Schema, :Column, :Dialect] :type
    #   Type of schema, if not set, intuited from properties
    # @option options [JSON::LD::Context] context
    #   Context used for this metadata. Taken from input if not provided
    # @option options [RDF::URI] :base
    #   The Base URL to use when expanding the document. This overrides the value of `input` if it is a URL. If not specified and `input` is not an URL, the base URL defaults to the current document URL if in a browser context, or the empty string if there is no document context.
    # @option options [Boolean] :validate
    #   Validate metadata, and raise error if invalid
    # @return [Metadata]
    def initialize(input, options = {})
      @options = options.dup
      @context = options[:context] if options[:context]
      reason = @options.delete(:reason)

      @options[:base] ||= context.base if context
      @options[:base] ||= input.base_uri if input.respond_to?(:base_uri)
      @options[:base] ||= input.filename if input.respond_to?(:filename)
      @options[:base] = RDF::URI(@options[:base])

      @options[:depth] ||= 0
      @filenames = Array(@options[:filenames]).map {|fn| RDF::URI(fn)} if @options[:filenames]
      @properties = self.class.const_get(:PROPERTIES)
      @required = self.class.const_get(:REQUIRED)

      @object = {}

      # Parent of this Metadata, if any
      @parent = @options[:parent]

      depth do
        # Input was parsed in .new
        # Metadata is object with symbolic keys
        input.each do |key, value|
          key = key.to_sym
          case key
          when :columns
            # An array of template specifications that provide mechanisms to transform the tabular data into other formats
            object[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
              colnum = parent ? dialect.skipColumns : 0  # Get dialect from Table, not Schema
              value.map do |v|
                colnum += 1
                Column.new(v, @options.merge(parent: self, context: nil, colnum: colnum))
              end
            else
              # Invalid, but preserve value
              value
            end
          when :dialect
            # If provided, dialect provides hints to processors about how to parse the referenced file to create a tabular data model.
            object[key] = case value
            when Hash   then Dialect.new(value, @options.merge(parent: self, context: nil))
            else
              # Invalid, but preserve value
              value
            end
            @type ||= :Table
          when :resources
            # An array of table descriptions for the tables in the group.
            object[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
              value.map {|v| Table.new(v, @options.merge(parent: self, context: nil))}
            else
              # Invalid, but preserve value
              value
            end
          when :tableSchema
            # An object property that provides a schema description as described in section 3.8 Schemas, for all the tables in the group. This may be provided as an embedded object within the JSON metadata or as a URL reference to a separate JSON schema document
            object[key] = case value
            when String then Schema.open(value, @options.merge(parent: self, context: nil))
            when Hash   then Schema.new(value, @options.merge(parent: self, context: nil))
            else
              # Invalid, but preserve value
              value
            end
          when :templates
            # An array of template specifications that provide mechanisms to transform the tabular data into other formats
            object[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
              value.map {|v| Template.new(v, @options.merge(parent: self, context: nil))}
            else
              # Invalid, but preserve value
              value
            end
          when :url
            # URL of CSV relative to metadata
            object[:url] = value
            @url = base.join(value)
            @context.base = @url if @context # Use as base for expanding IRIs
          when :@id
            # metadata identifier
            object[:@id] = value
            @id = base.join(value)
          else
            if @properties.has_key?(key)
              self.send("#{key}=".to_sym, value)
            else
              object[key] = value
            end
          end
        end
      end

      # Set type from @type, if present and not otherwise defined
      @type ||= object[:@type].to_sym if object[:@type]
      if reason
        debug("md#initialize") {reason}
        debug("md#initialize") {"filenames: #{filenames}"}
        debug("md#initialize") {"#{inspect}, parent: #{!@parent.nil?}, context: #{!@context.nil?}"} unless is_a?(Dialect)
      end

      validate! if options[:validate]
    end

    # Setters
    INHERITED_PROPERTIES.keys.each do |a|
      define_method("#{a}=".to_sym) do |value|
        object[a] = value.to_s =~ /^\d+/ ? value.to_i : value
      end
    end

    # Context used for this metadata. Use parent's if not defined on self.
    # @return [JSON::LD::Context]
    def context
      @context || (parent.context if parent)
    end

    # Treat `dialect` similar to an inherited property, but merge together values from Table and TableGroup
    # @return [Dialect]
    def dialect
      @dialect ||= case
      when object[:dialect] then object[:dialect]
      when parent then parent.dialect
      when is_a?(Table) || is_a?(TableGroup)
        Dialect.new({}, @options.merge(parent: self, context: nil))
      else
        raise "Can't access dialect from #{self.class} without a parent"
      end
    end

    # Set new dialect
    # @return [Dialect]
    def dialect=(value)
      # Clear cached dialect information from children
      object.values.each do |v|
        case v
        when Metadata then v.dialect = nil
        when Array then v.each {|vv| vv.dialect = nil if vv.is_a?(Metadata)}
        end
      end

      @dialect = object[:dialect] = value ? Dialect.new(value) : nil
    end

    # Type of this Metadata
    # @return [:TableGroup, :Table, :Template, :Schema, :Column]
    def type; self.class.name.split('::').last.to_sym; end

    # Base URL of metadata
    # @return [RDF::URI]
    def base; @options[:base]; end

    ##
    # Do we have valid metadata?
    def valid?
      validate!
      true
    rescue
      false
    end

    ##
    # Raise error if metadata has any unexpected properties
    # @return [self]
    def validate!
      expected_props, required_props = @properties.keys, @required

      unless is_a?(Dialect) || is_a?(Template)
        expected_props = expected_props + INHERITED_PROPERTIES.keys
      end

      # It has only expected properties (exclude metadata)
      keys = object.keys - [:"@id", :"@context"]
      keys = keys.reject {|k| k.to_s.include?(':')} unless is_a?(Dialect)
      raise "#{type} has unexpected keys: #{keys - expected_props}" unless keys.all? {|k| expected_props.include?(k)}

      # It has required properties
      raise "#{type} missing required keys: #{required_props & keys}"  unless (required_props & keys) == required_props

      # Every property is valid
      keys.each do |key|
        value = object[key]
        is_valid = case key
        when :columns
          column_names = value.map(&:name)
          value.is_a?(Array) &&
          value.all? {|v| v.is_a?(Column) && v.validate!} &&
          begin
            # The name properties of the column descriptions must be unique within a given table description.
            column_names = value.map(&:name)
            raise "Columns must have unique names" if column_names.uniq != column_names
            true
          end
        when :commentPrefix then value.is_a?(String) && value.length == 1
        when :datatype then value.is_a?(String) && DATATYPES.keys.map(&:to_s).include?(value)
        when :default then value.is_a?(String)
        when :delimiter then value.is_a?(String) && value.length == 1
        when :dialect then value.is_a?(Dialect) && value.validate!
        when :doubleQuote then %w(true false 1 0).include?(value.to_s.downcase)
        when :encoding then Encoding.find(value)
        when :foreignKeys
          # An array of foreign key definitions that define how the values from specified columns within this table link to rows within this table or other tables. A foreign key definition is a JSON object with the properties:
          value.is_a?(Array) && value.all? do |fk|
            raise "Foreign key must be an object" unless fk.is_a?(Hash)
            columns, reference = fk['columns'], fk['reference']
            raise "Foreign key missing columns and reference" unless columns && reference
            raise "Foreign key has extra entries" unless fk.keys.length == 2
            raise "Foreign key must reference columns" unless Array(columns).all? {|k| self.columns.any? {|c| c.name == k}}
            raise "Foreign key reference must be an Object" unless reference.is_a?(Hash)

            if reference.has_key?('resource')
              raise "Foreign key having a resource reference, must not have a tableSchema" if reference.has_key?('tableSchema')
              # FIXME resource is a URL of a specific resource (table) which must exist
            elsif reference.has_key?('tableSchema')
              # FIXME tableSchema is a URL of a specific schema which must exist
            end
            # FIXME: columns
            true
          end
        when :format then value.is_a?(String)
        when :header then %w(true false 1 0).include?(value.to_s.downcase)
        when :headerColumnCount, :headerRowCount
          value.is_a?(Numeric) && value.integer? && value > 0
        when :length
          # Applications must raise an error if length, maxLength or minLength are specified and the cell value is not a list (ie separator is not specified), a string or one of its subtypes, or a binary value.
          raise "Use if minLength or maxLength with length requires separator" if object[:minLength] || object[:maxLength] && !object[:separator]
          raise "Use of both length and minLength requires they be equal" unless object.fetch(:minLength, value) == value
          raise "Use of both length and maxLength requires they be equal" unless object.fetch(:maxLength, value) == value
          value.is_a?(Numeric) && value.integer? && value > 0
        when :lang then BCP47::Language.identify(value)
        when :lineTerminator then value.is_a?(String)
        when :minimum, :maximum, :minInclusive, :maxInclusive, :minExclusive, :maxExclusive
          value.is_a?(Numeric) ||
          RDF::Literal::Date.new(value).valid? ||
          RDF::Literal::Time.new(value).valid? ||
          RDF::Literal::DateTime.new(value).valid?
        when :minLength, :maxLength
          value.is_a?(Numeric) && value.integer? && value > 0
        when :name then value.is_a?(String) && name.match(NAME_SYNTAX)
        when :notes then value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
        when :null then !value.is_a?(Hash) && Array(value).all? {|v| v.is_a?(String)}
        when :aboutUrl, :propertyUrl, :valueUrl then value.is_a?(String)
        when :primaryKey
          # A column reference property that holds either a single reference to a column description object or an array of references.
          Array(value).all? do |k|
            self.columns.any? {|c| c.name == k}
          end
        when :quoteChar then value.is_a?(String) && value.length == 1
        when :required then %w(true false 1 0).include?(value.to_s.downcase)
        when :resources then value.is_a?(Array) && value.all? {|v| v.is_a?(Table) && v.validate!}
        when :tableSchema then value.is_a?(Schema) && value.validate!
        when :separator then value.nil? || value.is_a?(String) && value.length == 1
        when :skipInitialSpace then %w(true false 1 0).include?(value.to_s.downcase)
        when :skipBlankRows then %w(true false 1 0).include?(value.to_s.downcase)
        when :skipColumns then value.is_a?(Numeric) && value.integer? && value >= 0
        when :skipRows then value.is_a?(Numeric) && value.integer? && value >= 0
        when :source then %w(json rdf).include?(value)
        when :tableDirection then %w(rtl ltr default).include?(value)
        when :targetFormat, :templateFormat then RDF::URI(value).valid?
        when :templates then value.is_a?(Array) && value.all? {|v| v.is_a?(Template) && v.validate!}
        when :textDirection then %w(rtl ltr).include?(value)
        when :title then valid_natural_language_property?(value)
        when :trim then %w(true false 1 0 start end).include?(value.to_s.downcase)
        when :urlTemplate then value.is_a?(String)
        when :url then @url.valid?
        when :virtual then %w(true false 1 0).include?(value.to_s.downcase)
        when :@type then value.to_sym == type
        else
          raise "?!?! shouldn't get here for key #{key}"
        end
        raise "#{type} has invalid #{key}: #{value.inspect}" unless is_valid
      end

      self
    end

    ##
    # Determine if a natural language property is valid
    # @param [String, Array<String>, Hash{String => String}] value
    # @return [Boolean]
    def valid_natural_language_property?(value)
      value.is_a?(Hash) && value.all? do |k, v|
        Array(v).all? {|vv| vv.is_a?(String)}
      end
    end

    ##
    # Extract a new Metadata document from the file or data provided
    #
    # @param [#read, #to_s] input IO, or file path or URL
    # @param  [Hash{Symbol => Object}] options
    #   any additional options (see `RDF::Util::File.open_file`)
    # @return [Metadata] Tabular metadata
    # @see http://w3c.github.io/csvw/syntax/#parsing
    def embedded_metadata(input, options = {})
      options = options.dup
      options.delete(:context) # Don't accidentally use a passed context
      dialect = self.dialect
      # Normalize input to an IO object
      if !input.respond_to?(:read)
        return ::RDF::Util::File.open_file(input.to_s) {|f| embedded_metadata(f, options.merge(base: input.to_s))}
      end

      table = {
        "url" => (options.fetch(:base, "")),
        "@type" => "Table",
        "tableSchema" => {
          "@type" => "Schema",
          "columns" => nil
        }
      }

      # Set encoding on input
      csv = ::CSV.new(input, csv_options)
      (1..dialect.skipRows.to_i).each do
        value = csv.shift.join(dialect.delimiter)  # Skip initial lines, these form comment annotations
        # Trim value
        value.lstrip! if %w(true start).include?(dialect.trim.to_s)
        value.rstrip! if %w(true end).include?(dialect.trim.to_s)

        value = value[1..-1] if dialect.commentPrefix && value.start_with?(dialect.commentPrefix)
        table["notes"] ||= [] << value unless value.empty?
      end
      debug("embedded_metadata") {"notes: #{table["notes"].inspect}"}

      (1..dialect.headerRowCount).each do
        Array(csv.shift).each_with_index do |value, index|
          # Skip columns
          next if index < (dialect.skipColumns.to_i + dialect.headerColumnCount.to_i)

          # Trim value
          value.lstrip! if %w(true start).include?(dialect.trim.to_s)
          value.rstrip! if %w(true end).include?(dialect.trim.to_s)

          # Initialize title
          # SPEC CONFUSION: does title get an array, or concatenated values?
          columns = table["tableSchema"]["columns"] ||= []
          column = columns[index - dialect.skipColumns.to_i] ||= {
            "title" => {"und" => []},
          }
          column["title"]["und"] << value
        end
      end
      debug("embedded_metadata") {"table: #{table.inspect}"}
      input.rewind if input.respond_to?(:rewind)

      Table.new(table, options.merge(reason: "load embedded metadata: #{table['@id']}"))
    end

    ##
    # Yield each data row from the input file
    #
    # @param [:read] input
    # @yield [Row]
    def each_row(input)
      csv = ::CSV.new(input, csv_options)
      # Skip skipRows and headerRowCount
      rownum, skipped = 0, (dialect.skipRows.to_i + dialect.headerRowCount)
      (1..skipped).each {csv.shift}
      csv.each do |row|
        rownum += 1
        yield(Row.new(row, self, rownum, rownum + skipped))
      end
    end

    ##
    # Return or yield common properties (those which are CURIEs or URLS)
    #
    # @overload common_properties(subject, &block)
    #   @param [RDF::Resource] subject
    #   @yield property, value
    #   @yieldparam [String] property as a PName or URL
    #   @yieldparam [RDF::Statement] statement
    #
    # @overload common_properties()
    # @return [Hash{String => Object}] simply extracted from metadata
    def common_properties(subject = nil, &block)
      if block_given?
        raise "common_properties needs a subject when given a block" unless subject
        common = {'@id' => subject.to_s}
        each do |key, value|
          common[key.to_s] = value if key.to_s.include?(':')
        end
        ::JSON::LD::API.toRdf(common, expandContext: context, rename_bnodes: false) do |statement|
          # Fix subject reference, is a BNode with the same "name" as subject, but a different BNode.
          statement.subject = subject if subject && subject.node? && statement.subject.to_s == subject.to_s
          statement.object = RDF::Literal(statement.object.value) if statement.object.literal? && statement.object.language == :und
          yield statement
        end
      else
        object.dup.keep_if {|key, value| key.to_s.include?(':')}
      end
    end

    # Does the Metadata have any common properties?
    # @return [Boolean]
    def has_annotations?
      object.keys.any? {|k| k.to_s.include?(':')}
    end

    # Yield RDF statements after expanding property values
    #
    # @param [RDF::Resource] subject
    # @param [String] property
    # @param [Object] value
    # @yield s, p, o
    # @yieldparam [RDF::Statement] statement
    def rdf_values(subject, property, value)
      ::JSON::LD::API.toRdf({'@id' => subject.to_s, property => value}, expandContext: context, rename_bnodes: false) do |statement|
        # Fix subject reference, is a BNode with the same "name" as subject, but a different BNode.
        statement.subject = subject if subject && subject.node? && statement.subject.to_s == subject.to_s
        statement.object = RDF::Literal(statement.object.value) if statement.object.literal? && statement.object.language == :und
        yield statement
      end
    end

    # Merge metadata into this a copy of this metadata
    # @param [Array<Metadata>] metadata
    # @return [Metadata]
    def merge(*metadata)
      return self if metadata.empty?
      # If the top-level object of any of the metadata files are table descriptions, these are treated as if they were table group descriptions containing a single table description (ie having a single resource property whose value is the same as the original table description).
      this = case self
      when TableGroup then self.dup
      when Table
        if self.is_a?(Table) && self.parent
          self.parent
        else
          content = {"@type" => "TableGroup", "resources" => [self]}
          content['@context'] = object.delete(:@context) if object[:@context]
          ctx = @context
          self.remove_instance_variable(:@context) if self.instance_variables.include?(:@context) 
          tg = TableGroup.new(content, context: ctx, filenames: @filenames)
          @parent = tg  # Link from parent
          tg
        end
      else self.dup
      end

      # Merge all passed metadata into this
      metadata.reduce(this) do |memo, md|
        md = case md
        when TableGroup then md
        when Table
          if md.parent
            md.parent
          else
            content = {"@type" => "TableGroup", "resources" => [md]}
            ctx = md.context
            content['@context'] = md.object.delete(:@context) if md.object[:@context]
            md.remove_instance_variable(:@context) if md.instance_variables.include?(:@context) 
            tg = TableGroup.new(content, context: ctx, filenames: md.filenames)
            md.instance_variable_set(:@parent, tg)  # Link from parent
            tg
          end
        else
          md
        end

        raise "Can't merge #{memo.class} with #{md.class}" unless memo.class == md.class

        memo.merge!(md)
      end
    end

    # Merge metadata into self
    def merge!(metadata)
      raise "Merging non-equivalent metadata types: #{self.class} vs #{metadata.class}" unless self.class == metadata.class

      depth do
        # Merge filenames
        if @filenames || metadata.filenames
          @filenames = Array(@filenames) | Array(metadata.filenames)
        end

        # Expand A (this) and B (metadata) values into normal form
        [self, metadata].each do |md|
          md.each do |key, value|
            md[key] = case @properties[key]
            when :link
              md.base.join(value)
            when :object
              case key
              when :notes then Array(value)
              else value
              end
            when :natural_language
              value.is_a?(Hash) ? value : {(md.default_language || 'und') => Array(value)}
            else
              if key.to_s.include?(':')
                # Expand value relative to context
                ::JSON::LD::API.expand({key => value}, expandContext: md.context).first.values.first
              else
                value
              end
            end
          end
        end

        @dialect = nil  # So that it is re-built when needed
        # Merge each property from metadata into self
        metadata.each do |key, value|
          case key
          when :"@context"
            # Merge contexts
            @context = @context ? metadata.context.merge(@context) : metadata.context

            # Use defined representation
            this_ctx = object[key].is_a?(Array) ? object[key] : [object[key]].compact
            metadata_ctx = metadata[key].is_a?(Array) ? metadata[key] : [metadata[key]].compact
            this_object = this_ctx.detect {|v| v.is_a?(Hash)} || {}
            this_uri = this_ctx.select {|v| v.is_a?(String)}
            metadata_object = metadata_ctx.detect {|v| v.is_a?(Hash)} || {}
            metadata_uri = metadata_ctx.select {|v| v.is_a?(String)}
            merged_object = metadata_object.merge(this_object)
            merged_object = nil if merged_object.empty?
            object[key] = this_uri + (metadata_uri - this_uri) + ([merged_object].compact)
            object[key] = object[key].first if object[key].length == 1
          when :@id, :@type then object[key] ||= value
          else
            begin
              case @properties[key]
              when :array
                # If the property is an array property, the way in which values are merged depends on the property; see the relevant property for this definition.
                object[key] = case object[key]
                when nil then []
                when Hash then [object[key]]  # Shouldn't happen if well formed
                else object[key]
                end

                value = [value] if value.is_a?(Hash)
                case key
                when :resources
                  # When an array of table descriptions B is imported into an original array of table descriptions A, each table description within B is combined into the original array A by:
                  value.each do |t|
                    if ta = object[key].detect {|e| e.url == t.url}
                      # if there is a table description with the same url in A, the table description from B is imported into the matching table description in A
                      ta.merge!(t)
                    else
                      # otherwise, the table description from B is appended to the array of table descriptions A
                      t = t.dup
                      t.instance_variable_set(:@parent, self)
                      object[key] << t
                    end
                  end
                when :templates
                  # SPEC CONFUSION: differing templates with same @id?
                  # When an array of template specifications B is imported into an original array of template specifications A, each template specification within B is combined into the original array A by:
                  value.each do |t|
                    if ta = object[key].detect {|e| e.targetFormat == t.targetFormat && e.templateFormat == t.templateFormat}
                      # if there is a template specification with the same targetFormat and templateFormat in A, the template specification from B is imported into the matching template specification in A
                      ta.merge!(t)
                    else
                      # otherwise, the template specification from B is appended to the array of template specifications A
                      t = t.dup
                      t.instance_variable_set(:@parent, self) if self
                      object[key] << t
                    end
                  end
                when :columns
                  # When an array of column descriptions B is imported into an original array of column descriptions A, each column description within B is combined into the original array A by:
                  Array(value).each_with_index do |t, index|
                    ta = object[key][index]
                    if ta && ta[:name] && ta[:name] == t[:name] 
                      debug("merge!: columns") {"index: #{index}, name=#{t[:name] }"}
                      # if there is a column description at the same index within A and that column description has the same name, the column description from B is imported into the matching column description in A
                      ta.merge!(t)
                    elsif ta && ta[:title] && t[:title] && (
                      ta[:title].any? {|lang, values| !(Array(t[:title][lang]) & values).empty?} ||
                      !(Array(ta[:title]['und']) & t[:title].values.flatten.compact).empty? ||
                      !(Array(t[:title]['und']) & ta[:title].values.flatten.compact).empty?)
                      debug("merge!: columns") {"index: #{index}, title=#{t.title}"}
                      # otherwise, if there is a column description at the same index within A with a title that is also a title in A, considering the language of each title where und matches a value in any language, the column description from B is imported into the matching column description in A.
                      ta.merge!(t)
                    elsif ta.nil?
                      debug("merge!: columns") {"index: #{index}, nil"}
                      # SPEC SUGGESTION:
                      # If there is no column description at the same index within A, then the column description is taken from that index of B.
                      t = t.dup
                      t.instance_variable_set(:@parent, self) if self
                      object[key][index] = t
                    else
                      debug("merge!: columns") {"index: #{index}, ignore"}
                      # otherwise, the column description is ignored
                    end
                  end
                when :foreignKeys
                  # When an array of foreign key definitions B is imported into an original array of foreign key definitions A, each foreign key definition within B which does not appear within A is appended to the original array A.
                  # SPEC CONFUSION: If definitions vary only a little, they should probably be merged (e.g. common properties).
                  object[key] = object[key] + (metadata[key] - object[key])
                end
              when :link, :uri_template, :column_reference then object[key] ||= value
              when :object
                case key
                when :notes
                  # If the property accepts arrays, the result is an array of objects or strings: those from A followed by those from B that were not already a value in A.
                  a = object[key] || []
                  object[key] = (a + value).uniq
                else
                  # if the property only accepts single objects
                  if object[key].is_a?(String) || value.is_a?(String)
                    # if the value of the property in A is a string or the value from B is a string then the value from A overrides that from B
                    object[key] ||= value
                  elsif object[key].is_a?(Metadata)
                    # otherwise (if both values as objects) the objects are merged as described here
                    object[key].merge!(value)
                  elsif object[key].is_a?(Hash)
                    # otherwise (if both values as objects) the objects are merged as described here
                    object[key].merge!(value)
                  else
                    value = value.dup
                    value.instance_variable_set(:@parent, self) if self
                    object[key] = value
                  end
                end
              when :natural_language
                # If the property is a natural language property, the result is an object whose properties are language codes and where the values of those properties are arrays. The suitable language code for the values is either explicit within the existing value or determined through the default language in the metadata document; if it can't be determined the language code und should be used. The arrays should provide the values from A followed by those from B that were not already a value in A.
                a = object[key] || {}
                b = value
                debug("merge!: natural_language") {
                  "A: #{a.inspect}, B: #{b.inspect}"
                }
                b.each do |k, v|
                  a[k] = Array(a[k]) + (Array(b[k]) - Array(a[k]))
                end
                # eliminate titles with no language where the same string exists with a language
                if a.has_key?("und")
                  a["und"] = a["und"].reject do |v|
                    a.any? {|lang, values| lang != 'und' && values.include?(v)}
                  end
                  a.delete("und") if a["und"].empty?
                end
                object[key] = a
              else
                # If the property is an atomic property, then
                case key.to_s
                when "null"
                  # otherwise the result is an array of values: those from A followed by those from B that were not already a value in A.
                  object[key] = Array(object[key]) + (Array[value] - Array[object[key]])
                when /:/
                  object[key] = (Array(object[key]) + value).uniq
                else
                  # if the property only accepts single values, the value from A overrides that from B;
                  object[key] ||= value
                end
              end
            end
          end
        end
      end

      debug("merge!") {self.inspect}
      self
    end

    def inspect
      self.class.name + object.inspect
    end

    # Proxy to @object
    def [](key); object[key]; end
    def []=(key, value); object[key] = value; end
    def each(&block); object.each(&block); end
    def ==(other)
      object == (other.is_a?(Hash) ? other : other.object)
    end
    def to_json(args=nil); object.to_json(args); end

  protected

    # When setting a natural language property, always put in language-map form
    # @param [Symbol] prop
    # @param [Hash{String => String, Array<String>}, Array<String>, String] value
    # @return [Hash{String => Array<String>}]
    def set_nl(prop, value)
      object[prop] = case value
      when String then {(context.default_language || 'und') => [value]}
      when Array then {(context.default_language || 'und') => value}
      else value
      end
    end

    def inherited_property_value(method)
      # Inherited properties
      object.fetch(method.to_sym) do
        return parent.send(method) if parent
        case method.to_sym
        when :null, :default then ''
        when :textDirection then :ltr
        when :propertyUrl then "{#_name}"
        else nil
        end
      end
    end
  private
    # Options passed to CSV.new based on dialect
    def csv_options
      {
        col_sep: dialect.delimiter,
        row_sep: dialect.lineTerminator,
        quote_char: dialect.quoteChar,
        encoding: dialect.encoding
      }
    end

    class DebugContext
      include Utils
      def initialize(*args, &block)
        @options = {}
        debug(*args, &block)
      end
    end
    def self.debug(*args, &block)
      DebugContext.new(*args, &block)
    end
  end

  class TableGroup < Metadata
    PROPERTIES = {
     :"@type"           => :atomic,
     resources:            :array,
     tableSchema:          :object,
     tableDirection:       :atomic,
     dialect:              :object,
     templates:            :array,
    }.freeze
    REQUIRED = [].freeze

    # Setters
    PROPERTIES.each do |a, type|
      next if a == :dialect
      define_method("#{a}=".to_sym) do |value|
        case type
        when :natural_language
          set_nl(a, value)
        else
          object[a] = value.to_s =~ /^\d+/ ? value.to_i : value
        end
      end
    end

    # Does the Metadata or any descendant have any common properties
    # @return [Boolean]
    def has_annotations?
      super || resources.any? {|t| t.has_annotations? }
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      if INHERITED_PROPERTIES.has_key?(method.to_sym)
        inherited_property_value(method.to_sym)
      else
        PROPERTIES.has_key?(method.to_sym) ? object[method.to_sym] : super
      end
    end

    ##
    # Iterate over all resources
    # @yield [Table]
    def each_resource
      resources.map(&:url).each do |url|
        yield for_table(url)
      end
    end

    ##
    # Return the metadata for a specific table, re-basing context as necessary
    #
    # @param [String] url of the table
    # @return [Table]
    def for_table(url)
      table = resources.detect {|t| t.url == url}
      # Set document base for this table for resolving URLs
      table.instance_variable_set(:@context, context.dup)
      table.context.base = url
      table
    end
  end

  class Table < Metadata
    PROPERTIES = {
      url:                   :link,
      :"@type"            => :atomic,
      tableSchema:           :object,
      notes:                 :object,
      tableDirection:        :atomic,
      templates:             :array,
      title:                 :natural_language,
      dialect:               :object,
    }.freeze
    REQUIRED = [:url].freeze

    # Setters
    PROPERTIES.each do |a, type|
      next if a == :dialect
      define_method("#{a}=".to_sym) do |value|
        case type
        when :natural_language
          set_nl(a, value)
        else
          object[a] = value.to_s =~ /^\d+/ ? value.to_i : value
        end
      end
    end

    # Does the Metadata or any descendant have any common properties
    # @return [Boolean]
    def has_annotations?
      super || tableSchema && tableSchema.has_annotations?
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      if INHERITED_PROPERTIES.has_key?(method.to_sym)
        inherited_property_value(method.to_sym)
      else
        PROPERTIES.has_key?(method.to_sym) ? object[method.to_sym] : super
      end
    end
  end

  class Template < Metadata
    PROPERTIES = {
      url:            :link,
     :"@type"      => :atomic,
      targetFormat:   :link,
      templateFormat: :link,
      title:          :natural_language,
      source:         :atomic,
    }.freeze
    REQUIRED = %w(targetFormat templateFormat).map(&:to_sym).freeze

    # Setters
    PROPERTIES.each do |a, type|
      define_method("#{a}=".to_sym) do |value|
        case type
        when :natural_language
          set_nl(a, value)
        else
          object[a] = value.to_s =~ /^\d+/ ? value.to_i : value
        end
      end
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      PROPERTIES.has_key?(method.to_sym) ? object[method.to_sym] : super
    end
  end

  class Schema < Metadata
    PROPERTIES = {
      :"@type"   => :atomic,
      columns:      :array,
      primaryKey:   :column_reference,
      foreignKeys:  :array,
    }.freeze
    REQUIRED = [].freeze

    # Setters
    PROPERTIES.each do |a, type|
      define_method("#{a}=".to_sym) do |value|
        case type
        when :natural_language
          set_nl(a, value)
        else
          object[a] = value.to_s =~ /^\d+/ ? value.to_i : value
        end
      end
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      if INHERITED_PROPERTIES.has_key?(method.to_sym)
        inherited_property_value(method.to_sym)
      else
        PROPERTIES.has_key?(method.to_sym) ? object[method.to_sym] : super
      end
    end
  end

  class Column < Metadata
    PROPERTIES = {
      :"@type"   => :atomic,
      name:         :atomic,
      title:        :natural_language,
      required:     :atomic,
      virtual:      :atomic,
    }.freeze
    REQUIRED = [].freeze

    # Column number set on initialization
    # @return [Integer] 1-based colnum number
    def colnum; @options.fetch(:colnum, 0); end

    # Does the Metadata or any descendant have any common properties
    # @return [Boolean]
    def has_annotations?
      super || columns.any? {|c| c.has_annotations? }
    end

    # Setters
    PROPERTIES.each do |a, type|
      define_method("#{a}=".to_sym) do |value|
        case type
        when :natural_language
          set_nl(a, value)
        else
          object[a] = value.to_s =~ /^\d+/ ? value.to_i : value
        end
      end
    end

    # Return or create a name for the column from title, if it exists
    def name
      object[:name] ||= if title && (ts = title[context.default_language || 'und'])
        n = Array(ts).first
        n0 = URI.encode(n[0,1], /[^a-zA-Z0-9]/)
        n1 = URI.encode(n[1..-1], /[^\w\.]/)
        "#{n0}#{n1}"
      end || "_col.#{colnum}"
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      if INHERITED_PROPERTIES.has_key?(method.to_sym)
        inherited_property_value(method.to_sym)
      else
        PROPERTIES.has_key?(method.to_sym) ? object[method.to_sym] : super
      end
    end
  end

  class Dialect < Metadata
    # Defaults for dialects
    DIALECT_DEFAULTS = {
      commentPrefix:      nil,
      delimiter:          ",".freeze,
      doubleQuote:        true,
      encoding:           "utf-8".freeze,
      header:             true,
      headerColumnCount:  0,
      headerRowCount:     1,
      lineTerminator:     :auto, # SPEC says "\r\n"
      quoteChar:          '"',
      skipBlankRows:      false,
      skipColumns:        0,
      skipInitialSpace:   false,
      skipRows:           0,
      trim:               false
    }.freeze

    PROPERTIES = {
      :@id             => :link,
      :"@type"         => :atomic,
      commentPrefix:      :atomic,
      delimiter:          :atomic,
      doubleQuote:        :atomic,
      encoding:           :atomic,
      header:             :atomic,
      headerColumnCount:  :atomic,
      headerRowCount:     :atomic,
      lineTerminator:     :atomic,
      quoteChar:          :atomic,
      skipBlankRows:      :atomic,
      skipColumns:        :atomic,
      skipInitialSpace:   :atomic,
      skipRows:           :atomic,
      trim:               :atomic,
    }.freeze

    REQUIRED = [].freeze

    # Setters
    PROPERTIES.keys.each do |a|
      define_method("#{a}=".to_sym) do |value|
        object[a] = value.to_s =~ /^\d+/ ? value.to_i : value
      end
    end

    # escape character
    # @return [String]
    def escape_character
      self.doubleQuote ? '"' : '\\'
    end

    # default for headerRowCount is zero if header is false
    # @return [Integer]
    def headerRowCount
      object.fetch(:headerRowCount, self.header ? 1 : 0)
    end

    # default for trim comes from skipInitialSpace
    # @return [Boolean, String]
    def trim
      object.fetch(:trim, self.skipInitialSpace ? 'start' : false)
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      if DIALECT_DEFAULTS.has_key?(method.to_sym)
        # As set, or with default
        object.fetch(method.to_sym, DIALECT_DEFAULTS[method.to_sym])
      else
        super
      end
    end
  end

  # Wraps each resulting row
  class Row
    # Class for returning values
    Cell = Struct.new(:metadata, :raw, :column, :sourceColumn, :aboutUrl, :propertyUrl, :valueUrl, :value) do
      def set_urls(mapped_values)
        %w(aboutUrl propertyUrl valueUrl).each do |prop|
          if v = metadata.send(prop.to_sym)
            t = Addressable::Template.new(v)
            mapped = t.expand(mapped_values).to_s
            url = metadata.context.expand_iri(mapped, documentRelative: true)
            self.send("#{prop}=".to_sym, url)
          end
        end
      end

      def to_s; value.to_s; end
    end

    # URI or BNode of this row, after expanding `uriTemplate`
    # @return [RDF::Resource] resource
    attr_reader :resource

    # Row values, hashed by `name`
    attr_reader :values

    # Row number of this row
    # @return [Integer]
    attr_reader :row

    # Row number of this row from the original source
    # @return [Integer]
    attr_reader :sourceRow

    ##
    # @param [Array<Array<String>>] row
    # @param [Metadata] metadata for Table
    # @param [Integer] rownum 1-based row number
    # @return [Row]
    def initialize(row, metadata, rownum, source_rownum)
      @row = rownum
      @sourceRow = source_rownum
      @values = []
      skipColumns = metadata.dialect.skipColumns.to_i + metadata.dialect.headerColumnCount.to_i

      # Create values hash
      # SPEC CONFUSION: are values pre-or-post conversion?
      map_values = {"_row" => rownum, "_sourceRow" => (metadata.dialect.skipRows + metadata.dialect.headerRowCount)}

      # SPEC SUGGESTION:
      # Create columns if no columns were ever set; this would be the case when headerRowCount is zero, and nothing was set from explicit metadata
      create_columns = metadata.tableSchema.columns.nil?
      columns = metadata.tableSchema.columns ||= []

      # Make sure that the row length is at least as long as the number of column definitions, to implicitly include virtual columns
      columns.each_with_index {|c, index| row[index] ||= c.null}
      row.each_with_index do |value, index|
        next if index < skipColumns

        # create column if necessary
        if create_columns && !columns[index - skipColumns]
          columns[index - skipColumns] = Column.new({}, parent: metadata.tableSchema, context: nil, colnum: index + 1)
        end

        column = columns[index - skipColumns]

        @values << cell = Cell.new(column, value, index + 1 - skipColumns, index + 1)

        # Trim value
        if %w(string anyAtomicType any).include?(column.datatype)
          value.lstrip! if %w(true start).include?(metadata.dialect.trim.to_s)
          value.rstrip! if %w(true end).include?(metadata.dialect.trim.to_s)
        else
          # unless the datatype is string or anyAtomicType or any, strip leading and trailing whitespace from the string value
          value.strip!
        end

        # if the resulting string is an empty string, apply the remaining steps to the string given by the default property
        value = column.default if value.empty?

        cell_values = column.separator ? value.split(column.separator) : [value]

        cell_values = cell_values.map do |v|
          v.strip! unless %w(string anyAtomicType any).include?(column.datatype)
          case
          when v == column.null then nil
          when v.to_s.empty? then metadata.default
          when column.datatype
            # XXX validate the string based on the datatype, using the format property if one is specified, as described below, and then against the constraints described in section 3.11 Datatypes; if there are any errors, add them to the list of errors for the cell; the resulting value is typed as a string with the language provided by the lang property
            RDF::Literal(v, datatype: metadata.context.expand_iri(column.datatype, vocab: true))
          else
            RDF::Literal(v, language: column.lang)
          end
        end.compact

        cell.value = (column.separator ? cell_values : cell_values.first)

        map_values[columns[index].name] =  (column.separator ? cell_values.map(&:to_s) : cell_values.first.to_s)
      end

      # Map URLs for row
      @values.each_with_index do |cell, index|
        mapped_values = map_values.merge(
          "_name" => URI.decode(cell.metadata.name),
          "_column" => cell.column,
          "_sourceColumn" => cell.sourceColumn
        )
        cell.set_urls(mapped_values)

        # Row resource set from first cell, or a new Blank Node
        @resource ||= cell.aboutUrl || RDF::Node.new
        cell.aboutUrl ||= @resource # Use default
      end
    end
  end
end
