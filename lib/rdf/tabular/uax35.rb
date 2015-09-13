module RDF::Tabular
  ##
  # Utilities for parsing UAX35 dates and numbers.
  #
  # @see http://www.unicode.org/reports/tr35
  module UAX35

    ##
    # Parse the date format (if provided), and match against the value (if provided)
    # Otherwise, validate format and raise an error
    #
    # @param [String] format
    # @param [String] value
    # @return [String] XMLSchema version of value
    # @raise [ArgumentError] if format is not valid, or nil, if value does not match
    def parse_uax35_date(format, value)
      tz, date_format, time_format = nil, nil, nil
      return value unless format
      value ||= ""

      # Extract tz info
      if md = format.match(/^(.*[dyms])+(\s*[xX]+)$/)
        format, tz_format = md[1], md[2]
      end

      date_format, time_format = format.split(' ')
      date_format, time_format = nil, date_format if self.base.to_sym == :time

      # Extract date, of specified
      date_part = case date_format
      when 'yyyy-MM-dd' then value.match(/^(?<yr>\d{4})-(?<mo>\d{2})-(?<da>\d{2})/)
      when 'yyyyMMdd'   then value.match(/^(?<yr>\d{4})(?<mo>\d{2})(?<da>\d{2})/)
      when 'dd-MM-yyyy' then value.match(/^(?<da>\d{2})-(?<mo>\d{2})-(?<yr>\d{4})/)
      when 'd-M-yyyy'   then value.match(/^(?<da>\d{1,2})-(?<mo>\d{1,2})-(?<yr>\d{4})/)
      when 'MM-dd-yyyy' then value.match(/^(?<mo>\d{2})-(?<da>\d{2})-(?<yr>\d{4})/)
      when 'M-d-yyyy'   then value.match(/^(?<mo>\d{1,2})-(?<da>\d{1,2})-(?<yr>\d{4})/)
      when 'dd/MM/yyyy' then value.match(/^(?<da>\d{2})\/(?<mo>\d{2})\/(?<yr>\d{4})/)
      when 'd/M/yyyy'   then value.match(/^(?<da>\d{1,2})\/(?<mo>\d{1,2})\/(?<yr>\d{4})/)
      when 'MM/dd/yyyy' then value.match(/^(?<mo>\d{2})\/(?<da>\d{2})\/(?<yr>\d{4})/)
      when 'M/d/yyyy'   then value.match(/^(?<mo>\d{1,2})\/(?<da>\d{1,2})\/(?<yr>\d{4})/)
      when 'dd.MM.yyyy' then value.match(/^(?<da>\d{2})\.(?<mo>\d{2})\.(?<yr>\d{4})/)
      when 'd.M.yyyy'   then value.match(/^(?<da>\d{1,2})\.(?<mo>\d{1,2})\.(?<yr>\d{4})/)
      when 'MM.dd.yyyy' then value.match(/^(?<mo>\d{2})\.(?<da>\d{2})\.(?<yr>\d{4})/)
      when 'M.d.yyyy'   then value.match(/^(?<mo>\d{1,2})\.(?<da>\d{1,2})\.(?<yr>\d{4})/)
      when 'yyyy-MM-ddTHH:mm' then value.match(/^(?<yr>\d{4})-(?<mo>\d{2})-(?<da>\d{2})T(?<hr>\d{2}):(?<mi>\d{2})(?<se>(?<ms>))/)
      when 'yyyy-MM-ddTHH:mm:ss' then value.match(/^(?<yr>\d{4})-(?<mo>\d{2})-(?<da>\d{2})T(?<hr>\d{2}):(?<mi>\d{2}):(?<se>\d{2})(?<ms>)/)
      when /yyyy-MM-ddTHH:mm:ss\.S+/
        md = value.match(/^(?<yr>\d{4})-(?<mo>\d{2})-(?<da>\d{2})T(?<hr>\d{2}):(?<mi>\d{2}):(?<se>\d{2})\.(?<ms>\d+)/)
        num_ms = date_format.match(/S+/).to_s.length
        md if md && md[:ms].length <= num_ms
      else
        raise ArgumentError, "unrecognized date/time format #{date_format}" if date_format
        nil
      end

      # Forward past date part
      if date_part
        value = value[date_part.to_s.length..-1]
        value = value.lstrip if date_part && value.start_with?(' ')
      end

      # Extract time, of specified
      time_part = case time_format
      when 'HH:mm:ss' then value.match(/^(?<hr>\d{2}):(?<mi>\d{2}):(?<se>\d{2})(?<ms>)/)
      when 'HHmmss'   then value.match(/^(?<hr>\d{2})(?<mi>\d{2})(?<se>\d{2})(?<ms>)/)
      when 'HH:mm'    then value.match(/^(?<hr>\d{2}):(?<mi>\d{2})(?<se>)(?<ms>)/)
      when 'HHmm'     then value.match(/^(?<hr>\d{2})(?<mi>\d{2})(?<se>)(?<ms>)/)
      when /HH:mm:ss\.S+/
        md = value.match(/^(?<hr>\d{2}):(?<mi>\d{2}):(?<se>\d{2})\.(?<ms>\d+)/)
        num_ms = time_format.match(/S+/).to_s.length
        md if md && md[:ms].length <= num_ms
      else
        raise ArgumentError, "unrecognized date/time format #{time_format}" if time_format
        nil
      end

      # If there's a date_format but no date_part, match fails
      return nil if date_format && date_part.nil?

      # If there's a time_format but no time_part, match fails
      return nil if time_format && time_part.nil?

      # Forward past time part
      value = value[time_part.to_s.length..-1] if time_part

      # Use datetime match for time
      time_part = date_part if date_part && date_part.names.include?("hr")

      # If there's a timezone, it may optionally start with whitespace
      value = value.lstrip if tz_format.to_s.start_with?(' ')
      tz_part = case tz_format.to_s.lstrip
      when 'x'    then value.match(/^(?:(?<hr>[+-]\d{2})(?<mi>\d{2})?)$/)
      when 'X'    then value.match(/^(?:(?:(?<hr>[+-]\d{2})(?<mi>\d{2})?)|(?<z>Z))$/)
      when 'xx'   then value.match(/^(?:(?<hr>[+-]\d{2})(?<mi>\d{2}))|$/)
      when 'XX'   then value.match(/^(?:(?:(?<hr>[+-]\d{2})(?<mi>\d{2}))|(?<z>Z))$/)
      when 'xxx'  then value.match(/^(?:(?<hr>[+-]\d{2}):(?<mi>\d{2}))$/)
      when 'XXX'  then value.match(/^(?:(?:(?<hr>[+-]\d{2}):(?<mi>\d{2}))|(?<z>Z))$/)
      else
        raise ArgumentError, "unrecognized timezone format #{tz_format.to_s.lstrip}" if tz_format
        nil
      end

      # If there's a tz_format but no time_part, match fails
      return nil if tz_format && tz_part.nil?

      # Compose normalized value
      vd = ("%04d-%02d-%02d" % [date_part[:yr].to_i, date_part[:mo].to_i, date_part[:da].to_i]) if date_part
      vt = ("%02d:%02d:%02d" % [time_part[:hr].to_i, time_part[:mi].to_i, time_part[:se].to_i]) if time_part

      # Add milliseconds, if matched
      vt += ".#{time_part[:ms]}" if time_part && !time_part[:ms].empty?

      value = [vd, vt].compact.join('T')
      value += tz_part[:z] ? "Z" : ("%s:%02d" % [tz_part[:hr], tz_part[:mi].to_i]) if tz_part
      value
    end

    ##
    # Parse the date format (if provided), and match against the value (if provided)
    # Otherwise, validate format and raise an error
    #
    # @param [String] pattern
    # @param [String] value
    # @param [String] groupChar
    # @param [String] decimalChar
    # @return [String] XMLSchema version of value or nil, if value does not match
    # @raise [ArgumentError] if format is not valid
    def parse_uax35_number(pattern, value, groupChar=",", decimalChar=".")
      return value if pattern.to_s.empty?
      value ||= ""

      re = build_number_re(pattern, groupChar, decimalChar)

      # Upcase value and remove internal spaces
      value = value.upcase.gsub(/\s+/, '')

      # Remove groupChar from value
      value = value.gsub(groupChar, '')

      # Replace decimalChar with "."
      value = value.gsub(decimalChar, '.')

      if value =~ re
        # result re-assembles parts removed from value
        value
      else
        # no match
        nil
      end
    end

    # Build a regular expression from the provided pattern to match value, after suitable modifications
    #
    # @param [String] pattern
    # @param [String] groupChar
    # @param [String] decimalChar
    # @return [Regexp] Regular expression matching value
    # @raise [ArgumentError] if format is not valid
    def build_number_re(pattern, groupChar, decimalChar)
      # pattern must be composed of only 0, #, decimalChar, groupChar, E, %, and ‰
      legal_number_pattern = /\A
        ([%‰])?
        ([+-])?
        # Mantissa
        (\#|#{groupChar == '.' ? '\.' : groupChar})*
        (0|#{groupChar == '.' ? '\.' : groupChar})*
        # Fractional
        (?:#{decimalChar == '.' ? '\.' : decimalChar}
          (0|#{groupChar == '.' ? '\.' : groupChar})*
          (\#|#{groupChar == '.' ? '\.' : groupChar})*
          # Exponent
          (E
            [+-]?
            (?:\#|#{groupChar == '.' ? '\.' : groupChar})*
            (?:0|#{groupChar == '.' ? '\.' : groupChar})*
          )?
        )?
        ([%‰])?
      \Z/x

      unless pattern =~ legal_number_pattern
        raise ArgumentError, "unrecognized number pattern #{pattern}"
      end

      # Remove groupChar from pattern
      pattern = pattern.gsub(groupChar, '')

      # Replace decimalChar with "."
      pattern = pattern.gsub(decimalChar, '.')

      # Split on decimalChar and E
      parts = pattern.split(/[\.E]/)

      # Construct regular expression
      mantissa_str = case parts[0]
      when /\A([%‰])?([+-])?#+(0+)([%‰])?\Z/ then "#{$1}#{$2}\\d{#{$3.length},}#{$4}"
      when /\A([%‰])?([+-])?(0+)([%‰])?\Z/   then "#{$1}#{$2}\\d{#{$3.length}}#{$4}"
      when /\A([%‰])?([+-])?#+([%‰])?\Z/     then "#{$1}#{$2}\\d*#{$4}"
      end

      fractional_str = case parts[1]
      when /\A(0+)(#+)([%‰])?\Z/ then "\\d{#{$1.length},#{$1.length+$2.length}}#{$3}"
      when /\A(0+)([%‰])?\Z/     then "\\d{#{$1.length}}#{$2}"
      when /\A(#+)([%‰])?\Z/     then "\\d{,#{$1.length}}#{$2}"
      end
      fractional_str = "\\.#{fractional_str}" if fractional_str

      exponent_str = case parts[2]
      when /\A([+-])?(#+)(0+)([%‰])?\Z/ then "#{$1}\\d{#{$3.length},#{$2.length+$3.length}}#{$4}"
      when /\A([+-])?(0+)([%‰])?\Z/    then "#{$1}\\d{#{$2.length}}#{$3}"
      when /\A([+-])?(#+)([%‰])?\Z/     then "#{$1}\\d{,#{$2.length}}#{$3}"
      end
      exponent_str = "E#{exponent_str}" if exponent_str

      Regexp.new("^#{mantissa_str}#{fractional_str}#{exponent_str}$")
    end
  end
end
