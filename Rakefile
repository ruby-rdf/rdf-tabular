require 'rubygems'
require 'yard'
require 'rspec/core/rake_task'

namespace :gem do
  desc "Build the rdf-tabular-#{File.read('VERSION').chomp}.gem file"
  task :build do
    sh "gem build rdf-tabular.gemspec && mv rdf-tabular-#{File.read('VERSION').chomp}.gem pkg/"
  end

  desc "Release the rdf-tabular-#{File.read('VERSION').chomp}.gem file"
  task :release do
    sh "gem push pkg/rdf-tabular-#{File.read('VERSION').chomp}.gem"
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

desc "Update copy of CSVW context"
task :context do
  %x(curl -o etc/csvw.jsonld http://w3c.github.io/csvw/ns/csvw.jsonld)
end

desc "Create CSVW vocabulary definition"
task :vocab do
  puts "Generate lib/rdf/tabular/csvw.rb"
  cmd = "bundle exec rdf"
  cmd += " serialize --uri 'http://www.w3.org/ns/csvw#' --output-format vocabulary"
  cmd += " --module-name RDF::Tabular"
  cmd += " --class-name CSVW"
  cmd += " --strict"
  cmd += " -o lib/rdf/tabular/csvw.rb_t"
  cmd += " etc/csvw.jsonld"
  
  begin
    %x{#{cmd} && mv lib/rdf/tabular/csvw.rb_t lib/rdf/tabular/csvw.rb}
  rescue
    puts "Failed to load CSVW: #{$!.message}"
  ensure
    %x{rm -f lib/rdf/tabular/csvw.rb_t}
  end
end

task :default => :spec
task :specs => :spec

desc "Generate etc/doap.{nt,ttl} from etc/doap.csv."
task :doap do
  require 'rdf/tabular'
  require 'rdf/turtle'
  require 'rdf/ntriples'
  g = RDF::Graph.load("etc/doap.csv")
  RDF::NTriples::Writer.open("etc/doap.nt") {|w| w <<g }
  RDF::Turtle::Writer.open("etc/doap.ttl", standard_prefixes: true) {|w| w <<g }
end

desc "Generate etc/earl.html from etc/earl.ttl and etc/doap.ttl"
task :earl => "etc/earl.html"
file "etc/earl.jsonld" => %w(etc/earl.ttl etc/doap.ttl) do
  %x{cd etc; earl-report --format json -o earl.jsonld earl.ttl}
end
file "etc/earl.html" => "etc/earl.jsonld" do
  %x{cd etc; earl-report --json --format html -o earl.html earl.jsonld}
end
