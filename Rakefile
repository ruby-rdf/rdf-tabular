require 'rubygems'
require 'yard'
require 'rspec/core/rake_task'

namespace :gem do
  desc "Build the rdf-csv-#{File.read('VERSION').chomp}.gem file"
  task :build do
    sh "gem build rdf-csv.gemspec && mv rdf-csv-#{File.read('VERSION').chomp}.gem pkg/"
  end

  desc "Release the rdf-csv-#{File.read('VERSION').chomp}.gem file"
  task :release do
    sh "gem push pkg/rdf-csv-#{File.read('VERSION').chomp}.gem"
  end
end

desc 'Run specifications'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = %w(--options spec/spec.opts) if File.exists?('spec/spec.opts')
end

desc "Run specs through RCov"
RSpec::Core::RakeTask.new("spec:rcov") do |spec|
  spec.rcov = true
  spec.rcov_opts =  %q[--exclude "spec"]
end

namespace :doc do
  YARD::Rake::YardocTask.new

  desc "Generate HTML report specs"
  RSpec::Core::RakeTask.new("spec") do |spec|
    spec.rspec_opts = ["--format", "html", "-o", "doc/spec.html"]
  end
end

task :default => :spec
task :specs => :spec

desc "Generate etc/doap.{nt,ttl} from etc/doap.csv."
task :doap do
  require 'rdf/csv'
  require 'rdf/turtle'
  require 'rdf/ntriples'
  g = RDF::Graph.load("etc/doap.csv")
  RDF::NTriples::Writer.open("etc/doap.nt") {|w| w <<g }
  RDF::Turtle::Writer.open("etc/doap.ttl", standard_prefixes: true) {|w| w <<g }
end
