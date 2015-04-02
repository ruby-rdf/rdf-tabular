module RDF::Tabular
  module Utils
    # Add debug event to debug array, if specified
    #
    #   param [String] message
    #   yieldreturn [String] appended to message, to allow for lazy-evaulation of message
    def debug(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      return unless options[:debug] || @options[:debug] || RDF::Tabular.debug?
      depth = options[:depth] || @options[:depth]
      d_str = depth > 100 ? ' ' * 100 + '+' : ' ' * depth
      list = args
      list << yield if block_given?
      message = d_str + (list.empty? ? "" : list.join(": "))
      options[:debug] << message if options[:debug].is_a?(Array)
      @options[:debug] << message if @options[:debug].is_a?(Array)
      $stderr.puts(message) if RDF::Tabular.debug? || @options[:debug] == TrueClass
    end
    module_function :debug

    # Increase depth around a method invocation
    # @yield
    #   Yields with no arguments
    # @yieldreturn [Object] returns the result of yielding
    # @return [Object]
    def depth
      @options[:depth] += 1
      ret = yield
      @options[:depth] -= 1
      ret
    end
  end
end