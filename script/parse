#!/usr/bin/env ruby
require 'rubygems'
require "bundler/setup"
require 'logger'
$:.unshift(File.expand_path("../../lib", __FILE__))
begin
  require 'linkeddata'
rescue LoadError
end
require 'rdf/tabular'
require 'getoptlong'

def run(input, options)
  reader_class = RDF::Reader.for(options[:input_format].to_sym)
  raise "Reader not found for #{options[:input_format]}" unless reader_class

  reader_class.send((input.is_a?(String) ? :open : :new), input, options[:parser_options]) do |reader|
    if [:json, :atd].include?(options[:output_format])
      options[:output].puts reader.to_json(atd: options[:output_format] == :atd)
    else
      RDF::Writer.for(options[:output_format]).
      new(options[:output], prefixes: reader.prefixes, standard_prefixes: true) do |writer|
        writer << reader
      end
    end
  end
rescue
  fname = input.respond_to?(:path) ? input.path : (input.is_a?(String) ? input : "-stdin-")
  STDERR.puts("Error in #{fname}: #{$!}")
  raise
end

logger = Logger.new(STDERR)
logger.level = Logger::WARN
logger.formatter = lambda {|severity, datetime, progname, msg| "#{severity}: #{msg}\n"}

parser_options = {
  :base     => nil,
  :progress => false,
  :profile  => false,
  :validate => false,
  :strict   => false,
  :minimal  => false,
  logger: logger,
}

options = {
  :parser_options => parser_options,
  :output        => STDOUT,
  :output_format => :turtle,
  :input_format  => :tabular,
}
input = nil

opts = GetoptLong.new(
  ["--dbg", GetoptLong::NO_ARGUMENT],
  ["--execute", "-e", GetoptLong::REQUIRED_ARGUMENT],
  ["--format", GetoptLong::REQUIRED_ARGUMENT],
  ["--minimal", GetoptLong::NO_ARGUMENT],
  ["--output", "-o", GetoptLong::REQUIRED_ARGUMENT],
  ["--quiet", GetoptLong::NO_ARGUMENT],
  ["--uri", GetoptLong::REQUIRED_ARGUMENT],
  ["--validate", GetoptLong::NO_ARGUMENT],
  ["--verbose", GetoptLong::NO_ARGUMENT]
)
opts.each do |opt, arg|
  case opt
  when '--dbg'          then logger.level = Logger::DEBUG
  when '--execute'      then input = arg
  when '--format'       then options[:output_format] = arg.to_sym
  when '--minimal'      then parser_options[:minimal] = true
  when '--output'       then options[:output] = File.open(arg, "w")
  when '--quiet'
    options[:quiet] = options[:quiet].to_i + 1
    logger.level = Logger::FATAL
  when '--uri'          then parser_options[:base] = arg
  when '--validate'     then parser_options[:validate] = true
  when '--verbose'      then $verbose = true
  end
end

if ARGV.empty?
  s = input ? input : $stdin.read
  run(StringIO.new(s), options)
else
  ARGV.each do |test_file|
    run(test_file, options)
  end
end
puts
