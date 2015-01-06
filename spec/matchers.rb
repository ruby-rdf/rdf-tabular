require 'rdf/isomorphic'
require 'rspec/matchers'
require 'rdf/rdfa'

RSpec::Matchers.define :have_xpath do |xpath, value, trace|
  match do |actual|
    @doc = Nokogiri::HTML.parse(actual)
    return false unless @doc.is_a?(Nokogiri::XML::Document)
    return false unless @doc.root.is_a?(Nokogiri::XML::Element)
    @namespaces = @doc.namespaces.merge("xhtml" => "http://www.w3.org/1999/xhtml", "xml" => "http://www.w3.org/XML/1998/namespace")
    case value
    when false
      @doc.root.at_xpath(xpath, @namespaces).nil?
    when true
      !@doc.root.at_xpath(xpath, @namespaces).nil?
    when Array
      @doc.root.at_xpath(xpath, @namespaces).to_s.split(" ").include?(*value)
    when Regexp
      @doc.root.at_xpath(xpath, @namespaces).to_s =~ value
    else
      @doc.root.at_xpath(xpath, @namespaces).to_s == value
    end
  end
  
  failure_message do |actual|
    msg = "expected that #{xpath.inspect} would be #{value.inspect} in:\n" + actual.to_s
    msg += "was: #{@doc.root.at_xpath(xpath, @namespaces)}"
    msg +=  "\nDebug:#{trace.join("\n")}" if trace
    msg
  end
  
  failure_message_when_negated do |actual|
    msg = "expected that #{xpath.inspect} would not be #{value.inspect} in:\n" + actual.to_s
    msg +=  "\nDebug:#{trace.join("\n")}" if trace
    msg
  end
end

def normalize(graph)
  case graph
  when RDF::Queryable then graph
  when IO, StringIO
    RDF::Graph.new.load(graph, base_uri: @info.about)
  else
    # Figure out which parser to use
    g = RDF::Repository.new
    reader_class = detect_format(graph)
    reader_class.new(graph, base_uri: @info.about).each {|s| g << s}
    g
  end
end

Info = Struct.new(:about, :debug, :action, :result)

RSpec::Matchers.define :be_equivalent_graph do |expected, info|
  match do |actual|
    @info = if info.respond_to?(:action)
      info
    elsif info.is_a?(Hash)
      about = info[:about]
      debug = info[:debug]
      debug = Array(debug).join("\n")
      Info.new(about, debug, info[:action], info[:result])
    else
      Info.new(expected.is_a?(RDF::Enumerable) ? expected.context : info, info.to_s)
    end
    @expected = normalize(expected)
    @actual = normalize(actual)
    @actual.isomorphic_with?(@expected) rescue false
  end
  
  failure_message do |actual|
    info = @info.about
    if @expected.is_a?(RDF::Enumerable) && @actual.size != @expected.size
      "Graph entry count differs:\nexpected: #{@expected.size}\nactual:   #{@actual.size}"
    elsif @expected.is_a?(Array) && @actual.size != @expected.length
      "Graph entry count differs:\nexpected: #{@expected.length}\nactual:   #{@actual.size}"
    else
      "Graph differs"
    end +
    "\n#{info + "\n" unless info.empty?}" +
    (@info.action ? "Action: #{@info.action}\n" : "") +
    (@info.result ? "Result: #{@info.result}\n" : "") +
    "Expected:\n#{@expected.dump(:ttl, standard_prefixes: true, prefixes: {'' => @info.action})}" +
    "Results:\n#{@actual.dump(:ttl, standard_prefixes: true, prefixes: {'' => @info.action})}" +
    (@info.debug ? "\nDebug:\n#{@info.debug}" : "")
  end  
end

RSpec::Matchers.define :produce do |expected, info = []|
  match do |actual|
    expect(actual).to eq expected
  end
  
  failure_message do |actual|
    "Expected: #{expected.is_a?(String) ? expected : expected.to_json(JSON_STATE)}\n" +
    "Actual  : #{actual.is_a?(String) ? actual : actual.to_json(JSON_STATE)}\n" +
    #(expected.is_a?(Hash) && actual.is_a?(Hash) ? "Diff: #{expected.diff(actual).to_json(JSON_STATE)}\n" : "") +
    "Processing results:\n#{info.join("\n")}"
  end
end
