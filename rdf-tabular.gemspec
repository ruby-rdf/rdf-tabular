#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "rdf-tabular"
  gem.homepage              = "http://github.com/ruby-rdf/rdf-tabular"
  gem.license               = 'Unlicense'
  gem.summary               = "Tabular Data RDF Reader and JSON serializer."
  gem.description           = "RDF::Tabular processes tabular data with metadata creating RDF or JSON output."

  gem.authors               = ['Gregg Kellogg']
  gem.email                 = 'public-rdf-ruby@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README.md UNLICENSE VERSION) + Dir.glob('etc/*') + Dir.glob('lib/**/*.rb')
  gem.require_paths         = %w(lib)
  gem.extensions            = %w()
  gem.test_files            = Dir.glob('spec/**')
  gem.has_rdoc              = false

  gem.required_ruby_version = '>= 2.2.2'
  gem.requirements          = []
  gem.add_runtime_dependency     'bcp47',           '~> 0.3', '>= 0.3.3'
  gem.add_runtime_dependency     'rdf',             '~> 2.0'
  gem.add_runtime_dependency     'rdf-vocab',       '~> 2.0'
  gem.add_runtime_dependency     'rdf-xsd',         '~> 2.0'
  gem.add_runtime_dependency     'json-ld',         '~> 2.0'
  gem.add_runtime_dependency     'addressable',     '~> 2.3'
  gem.add_development_dependency 'nokogiri',        '~> 1.6'
  gem.add_development_dependency 'rspec',           '~> 3.4'
  gem.add_development_dependency 'rspec-its',       '~> 1.2'
  gem.add_development_dependency 'rdf-isomorphic',  '~> 2.0'
  gem.add_development_dependency 'rdf-spec',        '~> 2.0'
  gem.add_development_dependency 'rdf-turtle',      '~> 2.0'
  gem.add_development_dependency 'sparql',          '~> 2.0'
  gem.add_development_dependency 'webmock',         '~> 2.3'
  gem.add_development_dependency 'yard' ,           '~> 0.8'

  gem.post_install_message  = nil
end
