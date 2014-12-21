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
    TABLE_GROUP_PROPERTIES = %(
      resources schema table-direction dialect templates @type
    ).map(&:to_sym).freeze
    TABLE_GROUP_REQUIRED = [].freeze

    TABLE_PROPERTIES = %(
      @id schema notes table-direction templates dialect @type
    ).map(&:to_sym).freeze
    TABLE_REQUIRED = [:@id].freeze

    DIALECT_DEFAULTS = {
      commentPrefix:      nil,
      delimiter:          ",".freeze,
      doubleQuote:        true,
      encoding:           "utf-8".freeze,
      header:             true,
      headerColumnnCount: 0,
      headerRowCount:     1,
      lineTerminator:     %r(\r?\n) # SPEC says "\r\n",
      quoteChar:          '"',
      skipBlankRows:      false,
      skipColumns:        0,
      skipInitialSpace:   false,
      skipRows:           0,
      trim:               false,
      "@type" =>          nil
    }.freeze

    TEMPLATE_PROPERTIES = %(
      targetFormat templateFormat title source @type
    ).map(&:to_sym).freeze
    TEMPLATE_REQUIRED = %(targetFormat templateFormat).map(&:to_sym).freeze

    SCHEMA_PROPERTIES = %(
      columns primaryKey foreignKeys uriTemplate @type
    ).map(&:to_sym).freeze
    SCHEMA_REQUIRED = [].freeze

    COLUMN_PROPERTIES = %(
      name title required @type
    ).map(&:to_sym).freeze
    COLUMN_REQUIRED = [:name].freeze

    INHERITED_PROPERTIES = %w(
      null language text-direction separator format datatype
      length minLength maxLength minimum maximum
      minInclusive maxInclusive minExclusive maxExclusive
    ).map(&:to_sym).freeze

    # Type of this Metadata
    # @return [:TableGroup, :Table, :Template, :Schema, :Column]
    attr_reader :type

    # Parent of this Metadata (TableGroup for Table, ...)
    # @return [Metadata]
    attr_reader :parent

    # Attempt to retrieve the file at the specified path. If it is valid metadata, create a new Metadata object from it, otherwise, an empty Metadata object
    #
    # @param [String] path
    # @param [Hash{Symbol => Object}] options
    #   see `RDF::Util::File.open_file` in RDF.rb
    def self.open(path, options = {})
      RDF::Util::File.open_file(path, options) {|file| Metadata.initialize(file, options)}
    end

    # Create Metadata from IO, Hash or String
    #
    # @param [Metadata, Hash, #read, #to_s] input
    # @param [Hash{Symbol => Object}] options
    # @option options [:TableGroup, :Table, :Template, :Schema, :Column] :type
    #   Type of schema, if not set, intuited from properties
    # @return [Metadata]
    def initialize(input, options = {})
      @options = options.dup

      object = case
      when input.is_a?(Metadata)      then return input
      when input.respond_to?(:read)   then ::JSON.parse(input.read)
      when input.is_a?(Hash)          then input
      else                                 ::JSON.parse(input.to_s)
      end

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
          self[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
            value.map {|v| Metadata.new(v, @options.merge(type: :Column, parent: self))}
          else
            # Invalid, but preserve value
            value
          end
        when :dialect
          # If provided, dialect provides hints to processors about how to parse the referenced file to create a tabular data model.
          self[key] = case value
          when Hash   then Metadata.new(value, @options.merge(type: :Dialect, parent: self))
          else
            # Invalid, but preserve value
            value
          end
        when :resources
          # An array of table descriptions for the tables in the group.
          @type ||= :TableGroup
          self[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
            value.map {|v| Metadata.new(v, @options.merge(type: :Table, parent: self))}
          else
            # Invalid, but preserve value
            value
          end
        when :schema
          # An object property that provides a schema description as described in section 3.8 Schemas, for all the tables in the group. This may be provided as an embedded object within the JSON metadata or as a URL reference to a separate JSON schema document
          self[key] = case value
          when String then Metadata.open(value, @options.merge(type: :Schema, parent: self))
          when Hash   then Metadata.new(value, @options.merge(type: :Schema, parent: self))
          else
            # Invalid, but preserve value
            value
          end
        when :templates
          # An array of template specifications that provide mechanisms to transform the tabular data into other formats
          self[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
            value.map {|v| Metadata.new(v, @options.merge(type: :Template, parent: self))}
          else
            # Invalid, but preserve value
            value
          end
        when :targetFormat, :templateFormat, :source
          @type ||= :Template
          self[key] = value
        when :primaryKey, :foreignKeys, :uriTemplate
          @type ||= :Schema
          self[key] = value
        when :name, :required
          @type ||= :Column
          self[key] = value
        when :@id
          # URL of CSV relative to metadata
          # XXX: base from @context, or location of last loaded metadata, or CSV itself. Need to keep track of file base when loading and merging
          @location = @base.join(value)
        else
          self[key] = value
        end
      end

      # Set type from @type, if present and not otherwise defined
      @type ||= self[:@type] if self[:@type]
    end

    # Do we have valid metadata?
    def valid?
      validate!
      true
    rescue
      false
    end

    # Raise error if metadata has any unexpected properties
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
      expected_props = expected_props.merge(INHERITED_PROPERTIES)

      # It has only expected properties
      raise "#{type} has unexpected keys: #{keys}" unless keys.all? {|k| expected_proper.include?(k) || k.to_s.include?(':')}

      # It has required properties
      raise "#{type} missing required keys: #{keys}"  unless (required_props - keys) == required_props

      # Every property is valid
      each do |key, value|
        is_valid = case key.to_s
        when /:/  then true
        when :columns then value.is_a?(Array) && value.all? {|v| v.is_a?(Metadata) && v.type == :Column && v.valid?}
        when :commentPrefix then value.is_a?(String) && value.length == 1
        when :datatype then value.is_a?(String) # FIXME validate against defined datatypes?
        when :delimiter then value.is_a?(String) && value.length == 1
        when :dialect then value.is_a?(Metadata) && v.type == :Dialect && value.valid?
        when :doubleQuote then value == TrueClass || value == FalseClass
        when :encoding then Encoding.find(value)
        when :format then value.is_a?(String)
        when :header then value == TrueClass || value == FalseClass
        when :headerColumnCount then value.is_a?(String) && value.length == 1
        when :headerRowCount then value.is_a?(String) && value.length == 1
        when :length
          value.is_a?(Number) && value.integer? && value >= 0 &&
          self.fetch(:minLength, value) == value &&
          self.fetch(:maxLength, value) == value
        when :language then BCP47::Language.identify(value)
        when :lineTerminator then value.is_a?(String)
        when :minimum, :maximum, :minInclusive, :maxInclusive, :minExclusive, :maxExclusive
          value.is_a?(Number) ||
            RDF::Literal::Date.new(value).valid? ||
            RDF::Literal::Time.new(value).valid? ||
            RDF::Literal::DateTime.new(value).valid?
        when :minLength, :maxLength
          value.is_a?(Number) && value.integer? && value >= 0
        when :name then value.is_a?(String)
        when :notes then value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
        when :null then value.is_a?(String)
        when :quoteChar then value.is_a?(String) && value.length == 1
        when :required then value == TrueClass || value == FalseClass
        when :resources then value.is_a?(Array) && value.all? {|v| v.is_a?(Metadata) && v.type == :Table && v.valid?}
        when :schema then value.is_a?(Metadata) && value.type == :Schema && value.valid?
        when :separator then value.is_a?(String) && value.length == 1
        when :skipInitialSpace then value == TrueClass || value == FalseClass
        when :skipBlankRows then value == TrueClass || value == FalseClass
        when :skipColumns then value.is_a?(Number) && value.integer? && value >= 0
        when :skipRows then value.is_a?(Number) && value.integer? && value >= 0
        when :source then %w(json rdf).include?(value)
        when :"table-direction" then %w(rtl ltr default).include?(value)
        when :targetFormat, :templateFormat then RDF::URI(value).valid?
        when :templates then value.is_a?(Array) && value.all? {|v| v.is_a?(Metadata) && v.type == :Template && v.valid?}
        when :"text-direction" then %w(rtl ltr).include?(value)
        when :title then valid_natural_language_property?(value)
        when :trim then value == TrueClass || value == FalseClass || %w(true false start end).include?(value)
        when :urlTemplate then value.is_a?(String)
        when :"@id" then @location.valid?
        when :"@type" then value.to_sym == type
        when :primaryKey
          # A column reference property that holds either a single reference to a column description object or an array of references.
          Array(value).all? do |k|
            self.columns.any? {|c| c.name == k}
          end
        when :foreignKey
          # An array of foreign key definitions that define how the values from specified columns within this table link to rows within this table or other tables. A foreign key definition is a JSON object with the properties:
          value.is_a?(Array) && value.all? do |fk|
            raise "Foreign key must be an object" unless fk.is_a?(Hash)
            columns, reference = fk['columns'], fk['reference']
            raise "Foreign key missing columns and reference" unless columns && reference
            raise "Foreign key has extra keys" unless fk.keys.length == 2
            raise "Foreign key must reference columns" unless Array(columns).all? {|k| self.columns.any? {|c| c.name == k}}
            raise "Foreign key resference must be an Object" unless reference.is-a?(Hash)

            if reference.has_key?('resource')
              raise "Foreign key having a resource reference, must not have a schema" if reference.has_key?('schema')
              # FIXME resource is a URL of a specific resource (table) which must exist
            elsif reference.has_key('schema')
              # FIXME schema is a URL of a specific schema which must exist
            end
            # FIXME: columns
          end
        else
          raise "?!?! shouldn't get here"
        end

        raise "#{type} has invalid #{key}: #{value.inspect}" unless is_valid
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
        csv.shift for i in 0..skipRows.to_i # Skip initial lines
        for i in 0..(headerRowCount || 1) do
          csv.shift.each_with_index {|value, index| header_rows[index] << value}
        end
      end

      # Join each header row value 
    end

    # Merge metadata into this a copy of this metadata
    def merge(metadata)
      self.dup.merge(Metadata.new(metadata))
    end

    # Merge metadata into self
    def merge!(metadata)
      other = Metadata.new(other)
      # XXX ...
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

    # Return expanded annotation properties
    # @return [Hash{String => Object}] FIXME
    def expanded_annotation_properties
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      if DIALECT_DEFAULTS.has_key?(method.to_sym)
        # As set, or with default
        self.fetch(method, DIALECT_DEFAULTS(method.to_sym))
      elsif INHERITED_PROPERTIES.has_key?(method.to_sym)
        # Inherited properties
        self.fetch(method.to_sym, parent ? parent.send(method) : nil)
      elsif method.to_sym == :name
        # If not set, name comes from title
        self.fetch(:name, self[:title])
    end
  end
end
