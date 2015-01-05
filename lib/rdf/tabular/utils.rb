module RDF::Tabular
  module Utils
    # Add debug event to debug array, if specified
    #
    #   param [String] message
    #   yieldreturn [String] appended to message, to allow for lazy-evaulation of message
    def debug(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      return unless ::RDF::Tabular.debug
      list = args
      list << yield if block_given?
      message = (list.empty? ? "" : list.join(": "))
      ::RDF::Tabular.debug.puts message if ::RDF::Tabular.debug.respond_to?(:write)
      ::RDF::Tabular.debug << message if ::RDF::Tabular.debug.is_a?(Array)
    end
  end
end