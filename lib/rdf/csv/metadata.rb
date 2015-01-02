require 'json'
require 'json/ld'
require 'bcp47'

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
module RDF::CSV
  class Metadata < Hash
    # Possible properties for a TableGroup
    TABLE_GROUP_PROPERTIES = %w(
      @id @type resources schema table-direction dialect templates
    ).map(&:to_sym).freeze
    # Required properties for a TableGroup
    TABLE_GROUP_REQUIRED = [].freeze

    # Possible properties for a Table
    TABLE_PROPERTIES = %w(
      @id @type schema notes table-direction templates dialect
    ).map(&:to_sym).freeze
    # Required properties for a Table
    TABLE_REQUIRED = [:@id].freeze

    # Possible properties for a Template
    TEMPLATE_PROPERTIES = %w(
      @id @type targetFormat templateFormat title source
    ).map(&:to_sym).freeze
    # Required properties for a Template
    TEMPLATE_REQUIRED = %w(targetFormat templateFormat).map(&:to_sym).freeze

    # Possible properties for a Schema
    SCHEMA_PROPERTIES = %w(
      @id @type columns primaryKey foreignKeys urlTemplate
    ).map(&:to_sym).freeze
    # Required properties for a Schema
    SCHEMA_REQUIRED = [].freeze

    # Possible properties for a Column
    COLUMN_PROPERTIES = %w(
      @id @type name title required predicateUrl
    ).map(&:to_sym).freeze
    # Required properties for a Column
    COLUMN_REQUIRED = [:name].freeze

    # Inheritect properties, valid for all types
    INHERITED_PROPERTIES = %w(
      null language text-direction separator default format datatype
      length minLength maxLength minimum maximum
      minInclusive maxInclusive minExclusive maxExclusive
    ).map(&:to_sym).freeze

    # Defaults for dialects
    DIALECT_DEFAULTS = {
      commentPrefix:      nil,
      delimiter:          ",".freeze,
      doubleQuote:        true,
      encoding:           "utf-8".freeze,
      header:             true,
      headerColumnnCount: 0,
      headerRowCount:     1,
      lineTerminator:     %r(\r?\n), # SPEC says "\r\n"
      quoteChar:          '"',
      skipBlankRows:      false,
      skipColumns:        0,
      skipInitialSpace:   false,
      skipRows:           0,
      trim:               false,
      :"@type" =>         nil
    }.freeze

    NON_INHERITED_PROPERTIES = (
      TABLE_GROUP_PROPERTIES +
      TABLE_PROPERTIES +
      TEMPLATE_PROPERTIES +
      SCHEMA_PROPERTIES +
      COLUMN_PROPERTIES +
      DIALECT_DEFAULTS.keys -
      %w(@id @type table-direction).map(&:to_sym)
    ).freeze

    # Valid datatypes
    DATATYPES = {
      anySimpleType: RDF::XSD.anySimpleType,
      string: RDF::XSD.string,
      normalizedString: RDF::XSD.normalizedString,
      token: RDF::XSD.token,
      language: RDF::XSD.language,
      Name: RDF::XSD.Name,
      NCName: RDF::XSD.NCName,
      boolean: RDF::XSD.boolean,
      decimal: RDF::XSD.decimal,
      integer: RDF::XSD.integer,
      nonPositiveInteger: RDF::XSD.nonPositiveInteger,
      negativeInteger: RDF::XSD.negativeInteger,
      long: RDF::XSD.long,
      int: RDF::XSD.int,
      short: RDF::XSD.short,
      byte: RDF::XSD.byte,
      nonNegativeInteger: RDF::XSD.nonNegativeInteger,
      unsignedLong: RDF::XSD.unsignedLong,
      unsignedInt: RDF::XSD.unsignedInt,
      unsignedShort: RDF::XSD.unsignedShort,
      unsignedByte: RDF::XSD.unsignedByte,
      positiveInteger: RDF::XSD.positiveInteger,
      float: RDF::XSD.float,
      double: RDF::XSD.double,
      duration: RDF::XSD.duration,
      dateTime: RDF::XSD.dateTime,
      time: RDF::XSD.time,
      date: RDF::XSD.date,
      gYearMonth: RDF::XSD.gYearMonth,
      gYear: RDF::XSD.gYear,
      gMonthDay: RDF::XSD.gMonthDay,
      gDay: RDF::XSD.gDay,
      gMonth: RDF::XSD.gMonth,
      hexBinary: RDF::XSD.hexBinary,
      base64Binary: RDF::XSD.basee65Binary,
      anyURI: RDF::XSD.anyURI,

      number: RDF::XSD.double,
      binary: RDF::XSD.base64Binary,
      datetime: RDF::XSD.dateTime,
      any: RDF::XSD.anySimpleType,
      xml: RDF.XMLLiteral,
      html: RDF.HTML,
      json: RDF::CSV::CSVW.json
    }

    # Type of this Metadata
    # @return [:TableGroup, :Table, :Template, :Schema, :Column]
    attr_reader :type

    # Parent of this Metadata (TableGroup for Table, ...)
    # @return [Metadata]
    attr_reader :parent

    # Context used for this metadata
    # @return [JSON::LD::Context]
    attr_reader :context

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
      RDF::Util::File.open_file(path, options) {|file| Metadata.new(file, options.merge(base: path))}
    end

    # Create Metadata from IO, Hash or String
    #
    # @param [Metadata, Hash, #read, #to_s] input
    # @param [Hash{Symbol => Object}] options
    # @option options [:TableGroup, :Table, :Template, :Schema, :Column] :type
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
      @context = options.fetch(:context, ::JSON::LD::Context.new(options))

      # Triveal case
      return input if input.is_a?(Metadata)

      # Open as JSON-LD to get context
      jsonld = ::JSON::LD::API.new(input, context)
      if context.empty? && jsonld.context.empty?
        input.rewind if input.respond_to?(:rewind)
        jsonld = ::JSON::LD::API.new(input, 'http://www.w3.org/ns/csvw')
      end

      # Get both parsed JSON and context from jsonld
      object = jsonld.value

      # If we already have a context, merge in the context from this object, otherwise, set it to this object
      @context.merge!(jsonld.context)

      if options[:type]
        @type = options[:type]
        raise "If provided, type must be one of :TableGroup, :Table, :Template, :Schema, :Column]" unless
          [:TableGroup, :Table, :Template, :Schema, :Column].include?(@type)
      end

      # Parent of this Metadata, if any
      @parent = options[:parent]

      # Metadata is object with symbolic keys
      object.each do |key, value|
        key = key.to_sym
        case key
        when :columns
          # An array of template specifications that provide mechanisms to transform the tabular data into other formats
          @type ||= :Schema
          self[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
            value.map {|v| Metadata.new(v, @options.merge(type: :Column, parent: self, context: context))}
          else
            # Invalid, but preserve value
            value
          end
        when :dialect
          # If provided, dialect provides hints to processors about how to parse the referenced file to create a tabular data model.
          @type ||= :Table unless object.has_key?('resources')
          self[key] = case value
          when Hash   then Metadata.new(value, @options.merge(type: :Dialect, parent: self, context: context))
          else
            # Invalid, but preserve value
            value
          end
          @type ||= :Tabl
        when :resources
          # An array of table descriptions for the tables in the group.
          @type ||= :TableGroup
          self[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
            value.map {|v| Metadata.new(v, @options.merge(type: :Table, parent: self, context: context))}
          else
            # Invalid, but preserve value
            value
          end
        when :schema
          # An object property that provides a schema description as described in section 3.8 Schemas, for all the tables in the group. This may be provided as an embedded object within the JSON metadata or as a URL reference to a separate JSON schema document
          @type ||= :Table unless object.has_key?('resources')
          self[key] = case value
          when String then Metadata.open(value, @options.merge(type: :Schema, parent: self, context: context))
          when Hash   then Metadata.new(value, @options.merge(type: :Schema, parent: self, context: context))
          else
            # Invalid, but preserve value
            value
          end
        when :templates
          # An array of template specifications that provide mechanisms to transform the tabular data into other formats
          @type ||= :Table unless object.has_key?('resources')
          self[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
            value.map {|v| Metadata.new(v, @options.merge(type: :Template, parent: self, context: context))}
          else
            # Invalid, but preserve value
            value
          end
        when :targetFormat, :templateFormat, :source
          @type ||= :Template
          self.send("#{key}=".to_sym, value)
        when :primaryKey, :foreignKeys, :urlTemplate
          @type ||= :Schema
          self[key] = value
        when :predicateUrl
          @type ||= :Column
          predicateUrl = value
        when :name, :required
          @type ||= :Column
          self.send("#{key}=".to_sym, value)
        when :encoding, :lineTerminator, :quoteChar, :doubleQuote,
             :skipRows, :commentPrefix, :header, :headerRowCount, :delimiter,
             :skipColumns, :headerColumnCount, :skipBlankRows, :skipInitialSpace,
             :trim, :targetFormat, :templateFormat, :title, :source, :urlTemplate,
             :name, :title, :required, :null, :language, :separator, :default,
             :format, :datatype,
             :length, :maxLength, :minLength,
             :minimum, :maximum,
             :minInclusive, :maxInclusive,
             :minExclusive, :maxExclusive
          self.send("#{key}=".to_sym, value)
        when :@id
          # URL of CSV relative to metadata
          # XXX: base from @context, or location of last loaded metadata, or CSV itself. Need to keep track of file base when loading and merging
          self[:@id] = value
          @location = context.base.join(value)
        else
          self[key] = value
        end
      end

      # Set type from @type, if present and not otherwise defined
      @type ||= self[:@type].to_sym if self[:@type]

      validate! if options[:validate]
    end

    # Setters
    def predicateUrl=(value)
      # SPEC CONFUSION: what's the point of having an array?
      self[:predicateUrl] = Array(value).map {|v| RDF::URI(v)}
    end
    (INHERITED_PROPERTIES + NON_INHERITED_PROPERTIES - [:predicateUrl]).map(&:to_sym).each do |a|
      define_method("#{a}=".to_sym) do |value|
        self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
      end
    end

    # Getters for inherited properties. Retrieves through parents, as necessary
    INHERITED_PROPERTIES.map(&:to_sym).each do |a|
      define_method(a) do |value=nil|
        # FIXME why is value=nil necessary
        self.fetch(a) {parent ? parent.send(a) : nil}
      end
    end

    NON_INHERITED_PROPERTIES.map(&:to_sym).each do |a|
      define_method(a) {self[a]}
    end

    # Do we have valid metadata?
    def valid?
      validate!
      true
    rescue
      false
    end

    # Raise error if metadata has any unexpected properties
    # @return [self]
    def validate!
      expected_props, required_props = case type
      when :TableGroup then [TABLE_GROUP_PROPERTIES, TABLE_GROUP_REQUIRED]
      when :Table      then [TABLE_PROPERTIES, TABLE_REQUIRED]
      when :Dialect    then [DIALECT_DEFAULTS.keys, []]
      when :Template   then [TEMPLATE_PROPERTIES, TEMPLATE_REQUIRED]
      when :Schema     then [SCHEMA_PROPERTIES, SCHEMA_REQUIRED]
      when :Column     then [COLUMN_PROPERTIES, COLUMN_REQUIRED]
      else
        raise "Unknown metadata type: #{type}"
      end

      unless [:Dialect, :Template].include?(type)
        expected_props = expected_props + INHERITED_PROPERTIES
      end

      # It has only expected properties (exclude metadata)
      keys = self.keys - [:"@context"]
      keys = keys.reject {|k| k.to_s.include?(':')} unless type == :Dialect
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
          value.all? {|v| v.is_a?(Metadata) && v.type == :Column && v.validate!} &&
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
        when :dialect then value.is_a?(Metadata) && v.type == :Dialect && v.validate!
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
              raise "Foreign key having a resource reference, must not have a schema" if reference.has_key?('schema')
              # FIXME resource is a URL of a specific resource (table) which must exist
            elsif reference.has_key?('schema')
              # FIXME schema is a URL of a specific schema which must exist
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
        when :language then BCP47::Language.identify(value)
        when :lineTerminator then value.is_a?(String)
        when :minimum, :maximum, :minInclusive, :maxInclusive, :minExclusive, :maxExclusive
          value.is_a?(Numeric) ||
          RDF::Literal::Date.new(value).valid? ||
          RDF::Literal::Time.new(value).valid? ||
          RDF::Literal::DateTime.new(value).valid?
        when :minLength, :maxLength
          value.is_a?(Numeric) && value.integer? && value > 0
        when :name then value.is_a?(String) && !name.start_with?("_")
        when :notes then value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
        when :null then value.is_a?(String)
        when :predicateUrl then Array(value).all? {|v| RDF::URI(v).valid?}
        when :primaryKey
          # A column reference property that holds either a single reference to a column description object or an array of references.
          Array(value).all? do |k|
            self.columns.any? {|c| c.name == k}
          end
        when :quoteChar then value.is_a?(String) && value.length == 1
        when :required then %w(true false 1 0).include?(value.to_s.downcase)
        when :resources then value.is_a?(Array) && value.all? {|v| v.is_a?(Metadata) && v.type == :Table && v.validate!}
        when :schema then value.is_a?(Metadata) && value.type == :Schema && value.validate!
        when :separator then value.nil? || value.is_a?(String) && value.length == 1
        when :skipInitialSpace then %w(true false 1 0).include?(value.to_s.downcase)
        when :skipBlankRows then %w(true false 1 0).include?(value.to_s.downcase)
        when :skipColumns then value.is_a?(Numeric) && value.integer? && value >= 0
        when :skipRows then value.is_a?(Numeric) && value.integer? && value >= 0
        when :source then %w(json rdf).include?(value)
        when :"table-direction" then %w(rtl ltr default).include?(value)
        when :targetFormat, :templateFormat then RDF::URI(value).valid?
        when :templates then value.is_a?(Array) && value.all? {|v| v.is_a?(Metadata) && v.type == :Template && v.validate!}
        when :"text-direction" then %w(rtl ltr).include?(value)
        when :title then valid_natural_language_property?(value)
        when :trim then %w(true false 1 0 start end).include?(value.to_s.downcase)
        when :urlTemplate then value.is_a?(String)
        when :"@id" then @location.valid?
        when :"@type" then value.to_sym == type
        else
          raise "?!?! shouldn't get here for key #{key}"
        end
        raise "#{type} has invalid #{key}: #{value.inspect}" unless is_valid
      end

      self
    end

    # Determine if a natural language property is valid
    # @param [String, Array<String>, Hash{String => String}]
    # @return [Boolean]
    def valid_natural_language_property?(value)
      case value
      when String then true
      when Array  then value.all? {|v| v.is_a?(String)}
      when Hash   then value.all? {|k, v| k.is_a?(String) && v.is_a?(String)}
      else
        false
      end
    end

    # Using Metadata, extract a new Metadata document from the file or data provided
    #
    # @param [#read, Array<String>, #to_s] table_data IO, or file path
    # @param  [Hash{Symbol => Object}] options
    #   any additional options (see `RDF::Util::File.open_file`)
    # @return [Metadata]
    def file_metadata(table_data, options = {})
      header_rows = []
      CSV.new(table_data.respond_to?(:read) ? table_data : table_data.to_s) do |csv|
        (0..skipRows.to_i).each {csv.shift } # Skip initial lines
        (0..(headerRowCount || 1)).each do
          csv.shift.each_with_index {|value, index| header_rows[index] << value}
        end
      end

      # Join each header row value 
    end

    # Merge metadata into this a copy of this metadata
    def merge(metadata)
      self.dup.merge(Metadata.new(metadata, context: context))
    end

    # Merge metadata into self
    def merge!(metadata)
      other = Metadata.new(other, context: context)
      # XXX ...
    end

    def inspect
      "Metadata(#{type})" + super
    end

    # Return Table-level metadata with inherited properties merged. If IO is
    # provided, read CSV-level metadata from that file and merge
    #
    # @param [String, #to_s] id of Table if metadata is a TableGroup
    # @param [#read, Hash, Array<Array<String>>] file IO, or Hash or Array of Arrays of column info
    def table_data(id, file = nil)
      table = if table_group?
        data = table_group[id.to_s]
        raise "No table with id #{id}" unless data
        data = data.dup
        inherited_properties.each do |p, v|
          data.merge_property_value(p, v)
        end
        data
      else
        self.dup
      end

      if file
        table.merge!(file_metadata(file)) 
      else
        table
      end
    end

    ##
    # Determine if a value is a valid natural-language property. These include strings, arrays of strings, and objects which are a language map
    #
    # 
    # Return expanded annotation properties
    # @return [Hash{String => Object}] FIXME
    def expanded_annotation_properties
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      if DIALECT_DEFAULTS.has_key?(method.to_sym)
        # As set, or with default
        self.fetch(method, DIALECT_DEFAULTS(method.to_sym))
      elsif INHERITED_PROPERTIES.include?(method.to_sym)
        # Inherited properties
        self.fetch(method.to_sym, parent ? parent.send(method) : nil)
      elsif method.to_sym == :name
        # If not set, name comes from title
        self.fetch(:name, self[:title])
      else
        # Otherwise, retrieve key value defaulting to super
        self[method.to_sym] || super
      end
    end
  end
end
