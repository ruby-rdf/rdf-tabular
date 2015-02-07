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
  class Metadata < Hash
    include Utils

    # Inheritect properties, valid for all types
    INHERITED_PROPERTIES = {
      null:               :atomic,
      lang:               :atomic,
      :"text-direction" =>:atomic,
      separator:          :atomic,
      default:            :atomic,
      format:             :atomic,
      datatype:           :atomic,
      aboutUrl:           :uri_template,
      propertyUrl:        :uri_template,
      valueUrl:           :uri_template,
      length:             :atomic,
      minLength:          :atomic,
      maxLength:          :atomic,
      minimum:            :atomic,
      maximum:            :atomic,
      minInclusive:       :atomic,
      maxInclusive:       :atomic,
      minExclusive:       :atomic,
      maxExclusive:       :atomic,
    }.freeze

    # Valid datatypes
    DATATYPES = {
      anySimpleType:      RDF::XSD.anySimpleType,
      string:             RDF::XSD.string,
      normalizedString:   RDF::XSD.normalizedString,
      token:              RDF::XSD.token,
      language:           RDF::XSD.language,
      Name:               RDF::XSD.Name,
      NCName:             RDF::XSD.NCName,
      lang:               RDF::XSD.language,
      boolean:            RDF::XSD.boolean,
      decimal:            RDF::XSD.decimal,
      integer:            RDF::XSD.integer,
      nonPositiveInteger: RDF::XSD.nonPositiveInteger,
      negativeInteger:    RDF::XSD.negativeInteger,
      long:               RDF::XSD.long,
      int:                RDF::XSD.int,
      short:              RDF::XSD.short,
      byte:               RDF::XSD.byte,
      nonNegativeInteger: RDF::XSD.nonNegativeInteger,
      unsignedLong:       RDF::XSD.unsignedLong,
      unsignedInt:        RDF::XSD.unsignedInt,
      unsignedShort:      RDF::XSD.unsignedShort,
      unsignedByte:       RDF::XSD.unsignedByte,
      positiveInteger:    RDF::XSD.positiveInteger,
      float:              RDF::XSD.float,
      double:             RDF::XSD.double,
      dateTime:           RDF::XSD.dateTime,
      time:               RDF::XSD.time,
      date:               RDF::XSD.date,
      gYearMonth:         RDF::XSD.gYearMonth,
      gYear:              RDF::XSD.gYear,
      gMonthDay:          RDF::XSD.gMonthDay,
      gDay:               RDF::XSD.gDay,
      gMonth:             RDF::XSD.gMonth,
      hexBinary:          RDF::XSD.hexBinary,
      base64Binary:       RDF::XSD.basee65Binary,
      anyURI:             RDF::XSD.anyURI,

      number:             RDF::XSD.double,
      binary:             RDF::XSD.base64Binary,
      datetime:           RDF::XSD.dateTime,
      any:                RDF::XSD.anySimpleType,
      xml:                RDF.XMLLiteral,
      html:               RDF.HTML,
      json:               RDF::Tabular::CSVW.json,
    }

    # A name is restricted according to the following RegExp.
    # @return [RegExp]
    NAME_SYNTAX = %r(\A[a-zA-Z0-9][a-zA-Z0-9\._]*\z)

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

      # Only define context if input is readable, or there's no parent
      if !options[:parent] || !input.is_a?(Hash) || input.has_key?('@context')
        # Open as JSON-LD to get context
        jsonld = ::JSON::LD::API.new(input, context)

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

      # Input was parsed in .new
      object = input

      # Parent of this Metadata, if any
      @parent = @options[:parent]

      depth do
        # Metadata is object with symbolic keys
        object.each do |key, value|
          key = key.to_sym
          case key
          when :columns
            # An array of template specifications that provide mechanisms to transform the tabular data into other formats
            self[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
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
            self[key] = case value
            when Hash   then Dialect.new(value, @options.merge(parent: self, context: nil))
            else
              # Invalid, but preserve value
              value
            end
            @type ||= :Table
          when :resources
            # An array of table descriptions for the tables in the group.
            self[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
              value.map {|v| Table.new(v, @options.merge(parent: self, context: nil))}
            else
              # Invalid, but preserve value
              value
            end
          when :tableSchema
            # An object property that provides a schema description as described in section 3.8 Schemas, for all the tables in the group. This may be provided as an embedded object within the JSON metadata or as a URL reference to a separate JSON schema document
            self[key] = case value
            when String then Schema.open(value, @options.merge(parent: self, context: nil))
            when Hash   then Schema.new(value, @options.merge(parent: self, context: nil))
            else
              # Invalid, but preserve value
              value
            end
          when :templates
            # An array of template specifications that provide mechanisms to transform the tabular data into other formats
            self[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
              value.map {|v| Template.new(v, @options.merge(parent: self, context: nil))}
            else
              # Invalid, but preserve value
              value
            end
          when :url
            # URL of CSV relative to metadata
            # XXX: base from @context, or location of last loaded metadata, or CSV itself. Need to keep track of file base when loading and merging
            self[:url] = value
            @url = base.join(value)
          when :@id
            # metadata identifier
            self[:@id] = value
            @id = base.join(value)
          else
            if @properties.has_key?(key)
              self.send("#{key}=".to_sym, value)
            else
              self[key] = value
            end
          end
        end
      end

      # Set type from @type, if present and not otherwise defined
      @type ||= self[:@type].to_sym if self[:@type]
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
        self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
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
      when self[:dialect]
        if is_a?(Table) && parent && parent[:dialect]
          self[:dialect].merge(parent[:dialect]) # Prioritize self
        else
          self[:dialect]
        end
      when parent then parent.dialect
      when is_a?(Table) || is_a?(TableGroup)
        Dialect.new({}, @options.merge(parent: self, context: nil))
      else
        raise "Can't access dialect from #{self.class} without a parent"
      end
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
      keys = self.keys - [:"@id", :"@context"]
      keys = keys.reject {|k| k.to_s.include?(':')} unless is_a?(Dialect)
      raise "#{type} has unexpected keys: #{keys - expected_props}" unless keys.all? {|k| expected_props.include?(k)}

      # It has required properties
      raise "#{type} missing required keys: #{required_props & keys}"  unless (required_props & keys) == required_props

      # Every property is valid
      keys.each do |key|
        value = self[key]
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
          raise "Use if minLength or maxLength with length requires separator" if self[:minLength] || self[:maxLength] && !self[:separator]
          raise "Use of both length and minLength requires they be equal" unless self.fetch(:minLength, value) == value
          raise "Use of both length and maxLength requires they be equal" unless self.fetch(:maxLength, value) == value
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
        when :null then value.is_a?(String)
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
        when :"table-direction" then %w(rtl ltr default).include?(value)
        when :targetFormat, :templateFormat then RDF::URI(value).valid?
        when :templates then value.is_a?(Array) && value.all? {|v| v.is_a?(Template) && v.validate!}
        when :"text-direction" then %w(rtl ltr).include?(value)
        when :title then valid_natural_language_property?(value)
        when :trim then %w(true false 1 0 start end).include?(value.to_s.downcase)
        when :urlTemplate then value.is_a?(String)
        when :url then @url.valid?
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
          next if index < dialect.skipColumns.to_i

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
      # Skip skipRows and headerRows
      rownum = dialect.skipRows.to_i + dialect.headerRowCount
      (1..rownum).each {csv.shift}
      csv.each do |row|
        rownum += 1
        yield(Row.new(row, self, rownum))
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
        ::JSON::LD::API.toRdf(common, expandContext: context) do |statement|
          # Fix subject reference, which is a hack relying upon the JSON-LD naming scheme
          statement.subject = subject if subject && subject.node? && statement.subject.to_s == "_:b0"
          statement.object = RDF::Literal(statement.object.value) if statement.object.literal? && statement.object.language == :und
          yield statement
        end
      else
        self.dup.keep_if {|key, value| key.to_s.include?(':')}
      end
    end

    # Does the Metadata have any common properties?
    # @return [Boolean]
    def has_annotations?
      self.keys.any? {|k| k.to_s.include?(':')}
    end

    # Yield RDF statements after expanding property values
    #
    # @param [RDF::Resource] subject
    # @param [String] property
    # @param [Object] value
    # @yield s, p, o
    # @yieldparam [RDF::Statement] statement
    def rdf_values(subject, property, value)
      ::JSON::LD::API.toRdf({'@id' => subject.to_s, property => value}, expandContext: context) do |statement|
        # Fix subject reference, which is a hack relying upon the JSON-LD naming scheme
        statement.subject = subject if subject.node? && statement.subject.to_s == "_:b0"
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
          content['@context'] = self.delete(:@context) if self[:@context]
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
            content['@context'] = md.delete(:@context) if md[:@context]
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

        @dialect = nil  # So that it is re-built when needed
        # Merge each property from metadata into self
        metadata.each do |key, value|
          case key
          when :"@context"
            # Merge contexts
            @context = @context ? metadata.context.merge(@context) : metadata.context

            # Use defined representation
            this_ctx = self[key].is_a?(Array) ? self[key] : [self[key]].compact
            metadata_ctx = metadata[key].is_a?(Array) ? metadata[key] : [metadata[key]].compact
            this_object = this_ctx.detect {|v| v.is_a?(Hash)} || {}
            this_uri = this_ctx.select {|v| v.is_a?(String)}
            metadata_object = metadata_ctx.detect {|v| v.is_a?(Hash)} || {}
            metadata_uri = metadata_ctx.select {|v| v.is_a?(String)}
            merged_object = metadata_object.merge(this_object)
            merged_object = nil if merged_object.empty?
            self[key] = this_uri + (metadata_uri - this_uri) + ([merged_object].compact)
            self[key] = self[key].first if self[key].length == 1
          when :@id, :@type then self[key] ||= value
          else
            begin
              case @properties[key]
              when :array
                # If the property is an array property, the way in which values are merged depends on the property; see the relevant property for this definition.
                self[key] = case self[key]
                when nil then []
                when Hash then [self[key]]  # Shouldn't happen if well formed
                else self[key]
                end

                value = [value] if value.is_a?(Hash)
                case key
                when :resources
                  # When an array of table descriptions B is imported into an original array of table descriptions A, each table description within B is combined into the original array A by:
                  value.each do |t|
                    if ta = self[key].detect {|e| e.url == t.url}
                      # if there is a table description with the same url in A, the table description from B is imported into the matching table description in A
                      ta.merge!(t)
                    else
                      # otherwise, the table description from B is appended to the array of table descriptions A
                      t = t.dup
                      t.instance_variable_set(:@parent, self)
                      self[key] << t
                    end
                  end
                when :templates
                  # SPEC CONFUSION: differing templates with same @id?
                  # When an array of template specifications B is imported into an original array of template specifications A, each template specification within B is combined into the original array A by:
                  value.each do |t|
                    if ta = self[key].detect {|e| e.targetFormat == t.targetFormat && e.templateFormat == t.templateFormat}
                      # if there is a template specification with the same targetFormat and templateFormat in A, the template specification from B is imported into the matching template specification in A
                      ta.merge!(t)
                    else
                      # otherwise, the template specification from B is appended to the array of template specifications A
                      t = t.dup
                      t.instance_variable_set(:@parent, self) if self
                      self[key] << t
                    end
                  end
                when :columns
                  # When an array of column descriptions B is imported into an original array of column descriptions A, each column description within B is combined into the original array A by:
                  Array(value).each_with_index do |t, index|
                    ta = self[key][index]
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
                      self[key][index] = t
                    else
                      debug("merge!: columns") {"index: #{index}, ignore"}
                      # otherwise, the column description is ignored
                    end
                  end
                when :foreignKeys
                  # When an array of foreign key definitions B is imported into an original array of foreign key definitions A, each foreign key definition within B which does not appear within A is appended to the original array A.
                  # SPEC CONFUSION: If definitions vary only a little, they should probably be merged (e.g. common properties).
                  self[key] = self[key] + (metadata[key] - self[key])
                end
              when :link
                # If the property is a link property, then if the property only accepts single values, the value from A overrides that from B, otherwise the result is an array of links: those from A followed by those from B that were not already a value in A.
                # SPEC CONFUSION: What is an example of such a property?
                self[key] ||= value
              when :uri_template, :column_reference then self[key] ||= value
              when :object
                case key
                when :notes
                  # If the property accepts arrays, the result is an array of objects or strings: those from A followed by those from B that were not already a value in A.
                  a = case self[key]
                  when Array then self[key]
                  when Hash then [self[key]]
                  else Array(self[key])
                  end
                  b = case value
                  when Array then value
                  when Hash then [value]
                  else Array(value)
                  end
                  self[key] = a + b
                else
                  # if the property only accepts single objects
                  if self[key].is_a?(String) || value.is_a?(String)
                    # if the value of the property in A is a string or the value from B is a string then the value from A overrides that from B
                    self[key] ||= value
                  elsif self[key].is_a?(Hash)
                    # otherwise (if both values as objects) the objects are merged as described here
                    self[key].merge!(value)
                  else
                    value = value.dup
                    value.instance_variable_set(:@parent, self) if self
                    self[key] = value
                  end
                end
              when :natural_language
                # If the property is a natural language property, the result is an object whose properties are language codes and where the values of those properties are arrays. The suitable language code for the values is either explicit within the existing value or determined through the default language in the metadata document; if it can't be determined the language code und should be used. The arrays should provide the values from A followed by those from B that were not already a value in A.
                a = self[key] || {}
                b = value
                debug("merge!: natural_language") {
                  "A: #{a.inspect}, B: #{b.inspect}"
                }
                b.each do |k, v|
                  a[k] = Array(a[k]) + (Array(b[k]) - Array(a[k]))
                end
                # SPEC SUGGESTION: eliminate titles with no language where the same string exists with a language
                if a.has_key?("und")
                  a["und"] = a["und"].reject do |v|
                    a.any? {|lang, values| lang != 'und' && values.include?(v)}
                  end
                  a.delete("und") if a["und"].empty?
                end
                self[key] = a
              else
                # If the property is an atomic property, then
                case key.to_s
                when "null"
                  # otherwise the result is an array of values: those from A followed by those from B that were not already a value in A.
                  self[key] = Array(self[key]) + (Array[value] - Array[self[key]])
                when /:/
                  # If the property is a common property, the result is an array containing values from A followed by values from B not already in A. Values are first expanded using the @context of A or B respectively
                  a = self[key] ? ::JSON::LD::API.expand({key => self[key]}, expandContext: self.context).
                    first.values.first : []

                  b = ::JSON::LD::API.expand({key => metadata[key]}, expandContext: metadata.context).
                    first.values.first

                  self[key] = a + (b - a)
                else
                  # if the property only accepts single values, the value from A overrides that from B;
                  self[key] ||= value
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
      self.class.name + super
    end

  protected

    # When setting a natural language property, always put in language-map form
    # @param [Symbol] prop
    # @param [Hash{String => String, Array<String>}, Array<String>, String] value
    # @return [Hash{String => Array<String>}]
    def set_nl(prop, value)
      self[prop] = case value
      when String then {(context.default_language || 'und') => [value]}
      when Array then {(context.default_language || 'und') => value}
      else value
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
     :"table-direction" => :atomic,
     dialect:              :object,
     templates:            :array,
    }.freeze
    REQUIRED = [].freeze

    # Setters
    PROPERTIES.each do |a, type|
      define_method("#{a}=".to_sym) do |value|
        case type
        when :natural_language
          set_nl(a, value)
        else
          self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
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
        # Inherited properties
        self.fetch(method.to_sym, parent ? parent.send(method) : nil)
      else
        PROPERTIES.has_key?(method.to_sym) ? self[method.to_sym] : super
      end
    end

    ##
    # Return the metadata for a specific table, re-basing context as necessary
    #
    # @param [String] url of the table
    # @return [Table]
    def for_table(url)
      resources.detect {|t| t.url == url}
    end
  end

  class Table < Metadata
    PROPERTIES = {
      url:                   :link,
      :"@type"            => :atomic,
      tableSchema:           :object,
      notes:                 :object,
      :"table-direction"  => :atomic,
      templates:             :array,
      title:                 :natural_language,
      dialect:               :object,
    }.freeze
    REQUIRED = [:url].freeze

    # Setters
    PROPERTIES.each do |a, type|
      define_method("#{a}=".to_sym) do |value|
        case type
        when :natural_language
          set_nl(a, value)
        else
          self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
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
        # Inherited properties
        self.fetch(method.to_sym, parent ? parent.send(method) : nil)
      else
        PROPERTIES.has_key?(method.to_sym) ? self[method.to_sym] : super
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
          self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
        end
      end
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      PROPERTIES.has_key?(method.to_sym) ? self[method.to_sym] : super
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
          self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
        end
      end
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      if INHERITED_PROPERTIES.has_key?(method.to_sym)
        # Inherited properties
        self.fetch(method.to_sym, parent ? parent.send(method) : nil)
      else
        PROPERTIES.has_key?(method.to_sym) ? self[method.to_sym] : super
      end
    end
  end

  class Column < Metadata
    PROPERTIES = {
      :"@type"   => :atomic,
      name:         :atomic,
      title:        :natural_language,
      required:     :atomic,
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
          self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
        end
      end
    end

    # Return the inherited, or default propertyUrl as a URI template
    def propertyUrl
      self.fetch(:propertyUrl) do
        parent && parent.propertyUrl ? parent.propertyUrl : "{#_name}"
      end
    end

    # Return or create a name for the column from title, if it exists
    def name
      self[:name] ||= if title && (ts = title[context.default_language || 'und'])
        n = Array(ts).first
        n0 = URI.encode(n[0,1], /[^a-zA-Z0-9]/)
        n1 = URI.encode(n[1..-1], /[^\w\.]/)
        "#{n0}#{n1}"
      end || "_col.#{colnum}"
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      if INHERITED_PROPERTIES.has_key?(method.to_sym)
        # Inherited properties
        self.fetch(method.to_sym, parent ? parent.send(method) : nil)
      else
        PROPERTIES.has_key?(method.to_sym) ? self[method.to_sym] : super
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
      headerColumnnCount: 0,
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
      headerColumnnCount: :atomic,
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
        self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
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
      self.fetch(:headerRowCount, self.header ? 1 : 0)
    end

    # default for trim comes from skipInitialSpace
    # @return [Boolean, String]
    def trim
      self.fetch(:trim, self.skipInitialSpace ? 'start' : false)
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      if DIALECT_DEFAULTS.has_key?(method.to_sym)
        # As set, or with default
        self.fetch(method.to_sym, DIALECT_DEFAULTS[method.to_sym])
      else
        super
      end
    end
  end

  # Wraps each resulting row
  class Row
    # Class for returning values
    Cell = Struct.new(:column, :raw, :aboutUrl, :propertyUrl, :valueUrl, :value) do
      def set_urls(url, mapped_values)
        %w(aboutUrl propertyUrl valueUrl).each do |prop|
          if v = column.send(prop.to_sym)
            t = Addressable::Template.new(v)
            self.send("#{prop}=".to_sym, url.join(t.expand(mapped_values)))
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
    attr_reader :rownum

    ##
    # @param [Array<Array<String>>] row
    # @param [Metadata] metadata for Table
    # @param [Integer] rownum 1-based row number
    # @return [Row]
    def initialize(row, metadata, rownum)
      @rownum = rownum
      @values = []
      skipColumns = metadata.dialect.skipColumns

      # Create values hash
      # SPEC CONFUSION: are values pre-or-post conversion?
      map_values = {"_row" => rownum}

      # SPEC SUGGESTION:
      # Create columns if no columns were ever set; this would be the case when headerRowCount is zero, and nothing was set from explicit metadata
      create_columns = metadata.tableSchema.columns.nil?
      columns = metadata.tableSchema.columns ||= []
      row.each_with_index do |value, index|
        next if index < skipColumns

        # create column if necessary
        if create_columns && !columns[index - skipColumns]
          columns[index - skipColumns] = Column.new({}, parent: metadata.tableSchema, context: nil, colnum: index + 1)
        end

        column = columns[index - skipColumns]

        @values << cell = Cell.new(column, value)

        # Trim value
        value.lstrip! if %w(true start).include?(metadata.dialect.trim.to_s)
        value.rstrip! if %w(true end).include?(metadata.dialect.trim.to_s)
        value.strip! if %w(string anySimpleType any).include?(column.datatype.to_s)

        cell_values = column.separator ? value.split(column.separator) : [value]

        cell_values = cell_values.map do |v|
          case
          when v == column.null then nil
          when v.to_s.empty? then metadata.dialect.default
          when column.datatype
            # FIXME: use of format in extracting information
            RDF::Literal(v, datatype: metadata.context.expand_iri(column.datatype, vocab: true))
          else
            RDF::Literal(v, language: column.lang)
          end
        end.compact

        cell.value = (column.separator ? cell_values : cell_values.first)

        map_values[columns[index].name] =  (column.separator ? cell_values.map(&:to_s) : cell_values.first.to_s)
      end

      # Map URLs for row
      @values.each do |cell|
        mapped_values = map_values.merge("_name" => URI.decode(cell[:column].name))
        cell.set_urls(metadata.url, mapped_values)

        # Row resource set from first cell, or a new Blank Node
        @resource ||= cell.aboutUrl || RDF::Node.new
        cell.aboutUrl ||= @resource # Use default
      end
    end
  end
end
