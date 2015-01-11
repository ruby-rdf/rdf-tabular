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
      language:           :atomic,
      :"text-direction" =>:atomic,
      separator:          :atomic,
      default:            :atomic,
      format:             :atomic,
      datatype:           :atomic,
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
      duration:           RDF::XSD.duration,
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

    # ID of this Metadata
    # @return [RDF::URI]
    attr_reader :id

    # Parent of this Metadata (TableGroup for Table, ...)
    # @return [Metadata]
    attr_reader :parent

    # Context used for this metadata
    # @return [JSON::LD::Context]
    attr_reader :context

    # Filename (URI) of opened metadata, if any
    # @return [RDF::URI] filename
    attr_reader :filename

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
      RDF::Util::File.open_file(path, options) {|file| self.new(file, options.merge(base: path, filename: path))}
    end


    ##
    # @private
    def self.new(input, options = {})
      # Triveal case
      return input if input.is_a?(Metadata)

      context = options.fetch(:context, ::JSON::LD::Context.new(options))

      # Open as JSON-LD to get context
      jsonld = ::JSON::LD::API.new(input, context)
      if context.empty? && jsonld.context.empty? # FIXME: need mappings
        input.rewind if input.respond_to?(:rewind)
        jsonld = ::JSON::LD::API.new(input, 'http://www.w3.org/ns/csvw')
      end

      # If we already have a context, merge in the context from this object, otherwise, set it to this object
      context.merge!(jsonld.context)

      options = options.merge(context: context)

      # Get both parsed JSON and context from jsonld
      object = jsonld.value

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
          when %w(dialect schema templates).any? {|k| object_keys.include?(k)} then :Table
          when %w(targetFormat templateFormat source).any? {|k| object_keys.include?(k)} then :Template
          when %w(columns primaryKey foreignKeys urlTemplate).any? {|k| object_keys.include?(k)} then :Schema
          when %w(predicateUrl name required).any? {|k| object_keys.include?(k)} then :Column
          when %w(commentPrefix delimiter doubleQuote encoding header headerColumnCount headerRowCount).any? {|k| object_keys.include?(k)} then :Dialect
          when %w(lineTerminator quoteChar skipBlankRows skipColumns skipInitialSpace skipRows trim).any? {|k| object_keys.include?(k)} then :Dialect
          end

          case type.to_sym
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
      @context = options.fetch(:context)

      @options[:base] ||= context.base
      @options[:base] ||= input.base_uri if input.respond_to?(:base_uri)
      @options[:base] ||= input.filename if input.respond_to?(:filename)
      @options[:base] = RDF::URI(@options[:base])

      @options[:depth] ||= 0
      @filename = RDF::URI(@options[:filename]) if @options[:filename]
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
              colno = parent ? dialect.skipColumns : 0  # Get dialect from Table, not Schema
              value.map do |v|
                colno += 1
                Column.new(v, @options.merge(parent: self, context: context, colno: colno))
              end
            else
              # Invalid, but preserve value
              value
            end
          when :dialect
            # If provided, dialect provides hints to processors about how to parse the referenced file to create a tabular data model.
            self[key] = case value
            when Hash   then Dialect.new(value, @options.merge(parent: self, context: context))
            else
              # Invalid, but preserve value
              value
            end
            @type ||= :Tabl
          when :resources
            # An array of table descriptions for the tables in the group.
            self[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
              value.map {|v| Table.new(v, @options.merge(parent: self, context: context))}
            else
              # Invalid, but preserve value
              value
            end
          when :schema
            # An object property that provides a schema description as described in section 3.8 Schemas, for all the tables in the group. This may be provided as an embedded object within the JSON metadata or as a URL reference to a separate JSON schema document
            self[key] = case value
            when String then Schema.open(value, @options.merge(parent: self, context: context))
            when Hash   then Schema.new(value, @options.merge(parent: self, context: context))
            else
              # Invalid, but preserve value
              value
            end
          when :templates
            # An array of template specifications that provide mechanisms to transform the tabular data into other formats
            self[key] = if value.is_a?(Array) && value.all? {|v| v.is_a?(Hash)}
              value.map {|v| Template.new(v, @options.merge(parent: self, context: context))}
            else
              # Invalid, but preserve value
              value
            end
          when :@id
            # URL of CSV relative to metadata
            # XXX: base from @context, or location of last loaded metadata, or CSV itself. Need to keep track of file base when loading and merging
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
      debug("md.new") {inspect}

      validate! if options[:validate]
    end

    # Setters
    INHERITED_PROPERTIES.keys.each do |a|
      define_method("#{a}=".to_sym) do |value|
        self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
      end
    end

    # When setting language, also update the default language in the context
    def language=(value)
      context.default_language = self[:language] = value
    end

    # Treat `dialect` similar to an inherited property, but default
    def dialect
      case
      when self[:dialect] then self[:dialect]
      when parent then parent.dialect
      when is_a?(Table) || is_a?(TableGroup)
        Dialect.new({}, @options.merge(parent: self, context: context))
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
      keys = self.keys - [:"@context"]
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
        when :resources then value.is_a?(Array) && value.all? {|v| v.is_a?(Table) && v.validate!}
        when :schema then value.is_a?(Schema) && value.validate!
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
        when :@id then @id.valid?
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

    ##
    # Extract a new Metadata document from the file or data provided
    #
    # @param [#read, #to_s] input IO, or file path or URL
    # @param  [Hash{Symbol => Object}] options
    #   any additional options (see `RDF::Util::File.open_file`)
    # @return [Metadata] Tabular metadata
    # @see http://w3c.github.io/csvw/syntax/#parsing
    def embedded_metadata(input, options = {})
      table = {
        "@id" => (options.fetch(:base, "")),
        "@type" => "Table",
        "schema" => {
          "@type" => "Schema",
          "columns" => nil
        }
      }

      # Normalize input to an IO object
      if !input.respond_to?(:read)
        return ::RDF::Util::File.open_file(input.to_s) {|f| embedded_metadata(f, options.merge(base: input.to_s))}
      end

      # Set encoding on input
      csv = ::CSV.new(input, csv_options)
      (1..dialect.skipRows.to_i).each do
        row = csv.shift.join("")  # Skip initial lines, these form comment annotations
        row = row[1..-1] if dialect.commentPrefix && row.start_with?(dialect.commentPrefix)
        table["notes"] ||= [] << row unless row.empty?
      end

      (1..(dialect.headerRowCount || 1)).each do
        Array(csv.shift).each_with_index do |value, index|
          # Skip columns
          next if index < dialect.skipColumns

          # Trim value
          value = ltrim(value) if %w(true start).include?(dialect.trim)
          value = rtrim(value) if %w(true end).include?(dialect.trim)

          # Initialize title
          # SPEC CONFUSION: does title get an array, or concatenated values?
          columns = table["schema"]["columns"] ||= []
          column = columns[index - dialect.skipColumns] ||= {
            "title" => [],
          }
          column["title"] << value
        end

        Array(table["schema"]["columns"]).each do |c|
          c["title"] = c["title"].first if c["title"].length == 1
        end
      end
      input.rewind if input.respond_to?(:rewind)

      Table.new(table, options)
    end

    ##
    # Yield each data row from the input file
    #
    # @param [:read] input
    # @yield [Row]
    def each_row(input)
      csv = ::CSV.new(input, csv_options)
      # Skip skipRows and headerRows
      rownum = dialect.skipRows.to_i + (dialect.headerRowCount || 1)
      (1..rownum).each {csv.shift}
      csv.each do |row|
        rownum += 1
        yield(Row.new(row, self, rownum))
      end
    end

    ##
    # Return or yield common properties (those which are CURIEs or URLS)
    #
    # @param [RDF::Resource] subject
    # @yield property, value
    # @yieldparam [String] property as a PName or URL
    # @yieldparam [RDF::Statement] statement
    # @return [Hash{String => RDF::Value, Array<RDF::Value>}]
    def common_properties(subject, &block)
      if block_given?
        each do |key, value|
          next unless key.to_s.include?(':')  # Only common properties
          rdf_values(subject, key.to_s, value, &block)
        end
      else
        # FIXME, probably doesn't work for JSON, maybe just use values directly
        props = {}
        common_properties do |p, v|
          case props[p]
          when nil then props[p] = v
          when Array then props[p] << v
          else props[p] = [props[p], v]
          end
        end
        props
      end
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
        statement.object = RDF::Literal(statement.object.value) if statement.object.literal? && statement.object.language == :und
        yield statement
      end
    end

    # Merge metadata into this a copy of this metadata
    def merge(metadata)
      # If the top-level object of any of the metadata files are table descriptions, these are treated as if they were table group descriptions containing a single table description (ie having a single resource property whose value is the same as the original table description).
      this = self.is_a?(Table) ? TableGroup.new({"resources" => self}, context: context) : self.dup
      raise "Can't merge #{self.class}" unless this.is_a?(TableGroup)
      metadata = case metadata
      when TableGroup then metadata
      when Table then TableGroup.new({"@type" => "TableGroup", "resources" => metadata}, context: context)
      else
        raise "Can't merge #{other.class}"
      end

      this.merge!(Metadata.new(metadata, context: context))
    end

    # Merge metadata into self
    def merge!(metadata)
      other = Metadata.new(metadata, context: context)

      raise "Merging non-equivalent metadata types: #{self.class} vs #{other.class}" unless self.class == other.class

      # Save original context
      ctx = self.context.dup

      depth do
        # Merge each property from metadata into self
        other.each do |key, value|
          case key
          when :"@context"
            # Merge contexts
            @context = other.context.merge(self.context)

            # Use defined representation
            this_ctx = self[key].is_a?(Array) ? self[key] : [self[key]].compact
            other_ctx = other[key].is_a?(Array) ? other[key] : [other[key]].compact
            this_object = this_ctx.detect {|v| v.is_a?(Hash)} || {}
            this_uri = this_ctx.select {|v| v.is_a?(String)}
            other_object = other_ctx.detect {|v| v.is_a?(Hash)} || {}
            other_uri = other_ctx.select {|v| v.is_a?(String)}
            merged_object = other_object.merge(this_object)
            merged_object = nil if merged_object.empty?
            self[key] = this_uri + (other_uri - this_uri) + ([merged_object].compact)
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
                    if ta = self[key].detect {|e| e.id == t.id}
                      # if there is a table description with the same @id in A, the table description from B is imported into the matching table description in A
                      ta.merge!(t)
                    else
                      # otherwise, the table description from B is appended to the array of table descriptions A
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
                      self[key] << t
                    end
                  end
                when :columns
                  # When an array of column descriptions B is imported into an original array of column descriptions A, each column description within B is combined into the original array A by:
                  value.each_with_index do |t, index|
                    ta = self[key][index]
                    if ta && ta[:name] == t[:name]
                      # if there is a column description at the same index within A and that column description has the same name, the column description from B is imported into the matching column description in A
                      ta.merge!(t)
                    elsif ta && !(Array(ta[:title]) & Array(t[:title])).empty?
                      # SPEC SUGGESTION:
                      # if there is a column description at the same index within A and that column description has a title, is also in A, the column description from B is imported into the matching column description in A
                      ta.merge!(t)
                    else
                      # otherwise, the column description is ignored
                    end
                  end
                when :foreignKeys
                  # When an array of foreign key definitions B is imported into an original array of foreign key definitions A, each foreign key definition within B which does not appear within A is appended to the original array A.
                  # SPEC CONFUSION: If definitions vary only a little, they should probably be merged (e.g. common properties).
                  self[key] = self[key] + (other[key] - self[key])
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
                  else
                    # otherwise (if both values as objects) the objects are merged as described here
                    self[key].merge!(value)
                  end
                end
              when :natural_language
                # If the property is a natural language property, the result is an object whose properties are language codes and where the values of those properties are arrays. The suitable language code for the values is either explicit within the existing value or determined through the default language in the metadata document; if it can't be determined the language code und should be used. The arrays should provide the values from A followed by those from B that were not already a value in A.
                a = case self[key]
                when Hash then self[key]
                when Array then {(ctx.default_language || "und") => self[key]}
                when String then {(ctx.default_language || "und") => [self[key]]}
                end
                b = case value
                when Hash then value
                when Array then {(other.context.default_language || "und") => value}
                when String then {(other.context.default_language || "und") => [value]}
                end
                b.each do |k, v|
                  vv = a[k] + (b[k] - a[k])
                  a[k] = vv.length == 1 ? vv.first : vv
                end
                self[key] = a
              else
                # If the property is an atomic property, then
                case key.to_s
                when "predicateUrl", "null"
                  # otherwise the result is an array of values: those from A followed by those from B that were not already a value in A.
                  self[key] = Array(self[key]) + (Array[value] - Array[self[key]])
                when /:/
                  # SPEC SUGGESTION: common property
                  a = case self[key]
                  when nil then []
                  when Array then self[key]
                  else [self[key]]
                  end

                  b = case other[key]
                  when nil then []
                  when Array then other[key]
                  else [other[key]]
                  end

                  self[key] = a + (b - a)
                  self[key] = self[key].first if self[key].length == 1
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

  private
    # Options passed to CSV.new based on dialect
    def csv_options
      {
        col_sep: dialect.delimiter,
        row_sep: dialect.lineTerminator,
        quote_char: dialect.quoteChar,
      }
    end
  end

  class TableGroup < Metadata
    PROPERTIES = {
     :@id               => :link,
     :"@type"           => :atomic,
     resources:            :array,
     schema:               :object,
     :"table-direction" => :atomic,
     dialect:              :object,
     templates:            :array,
    }.freeze
    REQUIRED = [].freeze

    # Setters
    PROPERTIES.keys.each do |a|
      define_method("#{a}=".to_sym) do |value|
        self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
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

  class Table < Metadata
    PROPERTIES = {
      :@id               => :link,
     :"@type"            => :atomic,
     schema:                :object,
     notes:                 :object,
     :"table-direction"  => :atomic,
     templates:             :array,
     dialect:               :object,
    }.freeze
    REQUIRED = [:@id].freeze

    # Setters
    PROPERTIES.keys.each do |a|
      define_method("#{a}=".to_sym) do |value|
        self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
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

  class Template < Metadata
    PROPERTIES = {
      :@id         => :link,
     :"@type"      => :atomic,
      targetFormat:   :link,
      templateFormat: :link,
      title:          :natural_language,
      source:         :atomic,
    }.freeze
    REQUIRED = %w(targetFormat templateFormat).map(&:to_sym).freeze

    # Setters
    PROPERTIES.keys.each do |a|
      define_method("#{a}=".to_sym) do |value|
        self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
      end
    end

    # Logic for accessing elements as accessors
    def method_missing(method, *args)
      PROPERTIES.has_key?(method.to_sym) ? self[method.to_sym] : super
    end
  end

  class Schema < Metadata
    PROPERTIES = {
      :@id       => :link,
      :"@type"   => :atomic,
      columns:      :array,
      primaryKey:   :column_reference,
      foreignKeys:  :array,
      urlTemplate:  :uri_template,
    }.freeze
    REQUIRED = [].freeze

    # Setters
    PROPERTIES.keys.each do |a|
      define_method("#{a}=".to_sym) do |value|
        self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
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
      :@id       => :link,
      :"@type"   => :atomic,
      name:         :atomic,
      title:        :natural_language,
      required:     :atomic,
      predicateUrl: :atomic,
    }.freeze
    REQUIRED = [:name].freeze

    # Column number set on initialization
    # @return [Integer] 1-based colnum number
    def colnum; @options.fetch(:colnum, 0); end

    # Setters
    PROPERTIES.keys.each do |a|
      define_method("#{a}=".to_sym) do |value|
        self[a] = value.to_s =~ /^\d+/ ? value.to_i : value
      end
    end

    # Create predicateUrl by merging with table ID
    def predicateUrl=(value)
      # SPEC CONFUSION: what's the point of having an array?
      table = self
      table = table.parent while table.parent && table.type != :Table
      self[:predicateUrl] = table && table.id ? table.id.join(value) : RDF::URI(value)
    end

    # Return or create a predicateUrl for the column
    def predicateUrl
      self.fetch(:predicateUrl) do
        self.predicateUrl = "##{URI.encode(name)}"
        self[:predicateUrl]
      end
    end

    # Return or create a name for the column from title, if it exists
    def name
      self[:name] ||= title ? Array(title).join("\n") : "_col=#{colnum}"
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
      trim:               "false"
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
    # @param [Metadata] Table metadata
    # @param [rownum] 1-based row number
    # @return [Row]
    def initialize(row, metadata, rownum)
      @rownum = rownum
      skipColumns = metadata.dialect.skipColumns

      # Create values hash
      # SPEC CONFUSION: are values pre-or-post conversion?
      map_values = {"_row" => rownum}

      # SPEC SUGGESTION:
      # Create columns if no columns were ever set; this would be the case when headerRowCount is zero, and nothing was set from explicit metadata
      create_columns = metadata.schema.columns.nil?
      columns = metadata.schema.columns ||= []
      row.each_with_index do |value, index|
        next if index < skipColumns

        # create column if necessary
        if create_columns && !columns[index]
          columns[index] = Column.new({}, parent: metadata.schema, context: metadata.schema.context, colnum: index + 1)
        end

        map_values[columns[index].name] = value
      end

      # Create resource using urlTemplate and values hash
      @resource = if metadata.schema.urlTemplate
        t = Addressable::Template.new(metadata.urlTemplate)
        RDF::URI(t.expand(map_values))
      else
        RDF::Node.new
      end

      # Yield each value, after conversion
      @values = []
      row.each_with_index do |cell, index|
        next if index < skipColumns
        @values << if column = columns[index - skipColumns]
          cv = cell
          # Trim value
          cv = ltrim(cv.to_s) if %w(true start).include?(metadata.dialect.trim)
          cv = rtrim(cv.to_s) if %w(true end).include?(metadata.dialect.trim)

          cell_values = column.separator ? cv.split(column.separator) : [cv]

          cell_values = cell_values.map do |v|
            case
            when v.empty? then metadata.dialect.null
            when v.nil? then metadata.dialect.default
            when column.datatype == :anyUri
              metadata.id.join(v)
            when column.datatype
              # FIXME: use of format in extracting information
              RDF::Literal(v, datatype: metadata.context.expand_iri(column.datatype, vocab: true))
            else
              RDF::Literal(v, language: column.language)
            end
          end.compact

          (column.separator ? cell_values : cell_values.first)
        else
          # Non-mapped columns
          nil
        end
      end
    end
  end
end
