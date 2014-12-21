# Tabular Data RDF Reader and JSON serializer

[RDF-CSV][] reader for [RDF.rb][] and fully JSON serializer.

[![Gem Version](https://badge.fury.io/rb/rdf-csv.png)](http://badge.fury.io/rb/rdf-csv)
[![Build Status](https://secure.travis-ci.org/ruby-rdf/rdf-csv.png?branch=master)](http://travis-ci.org/ruby-rdf/rdf-csv)

## Features

RDF::CSV parses and serializes CSV or other Tabular Data into [RDF][] and JSON.

Install with `gem install rdf-csv`

## Examples

    require 'rubygems'
    require 'rdf/csv

## RDF Reader
{RDF::CSV} also acts as a normal RDF reader, using the standard RDF.rb Reader interface:

    graph = RDF::Graph.load("etc/doap.csv")


## Documentation
Full documentation available on [RubyDoc](http://rubydoc.info/gems/rdf-csv/file/README.md)


### Principal Classes
* {RDF::CSV}
  * {RDF::CSV::JSON}
  * {RDF::CSV::Format}
  * {RDF::CSV::Metadata}
  * {RDF::CSV::Reader}

## Dependencies
* [Ruby](http://ruby-lang.org/) (>= 1.9.2)
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 1.0)
* [JSON](https://rubygems.org/gems/json) (>= 1.5)

## Installation
The recommended installation method is via [RubyGems](http://rubygems.org/).
To install the latest official release of the `RDF::CSV` gem, do:

    % [sudo] gem install rdf-csv

## Mailing List
* <http://lists.w3.org/Archives/Public/public-rdf-ruby/>

## Author
* [Gregg Kellogg](http://github.com/gkellogg) - <http://greggkellogg.net/>

## Contributing
* Do your best to adhere to the existing coding conventions and idioms.
* Don't use hard tabs, and don't leave trailing whitespace on any line.
* Do document every method you add using [YARD][] annotations. Read the
  [tutorial][YARD-GS] or just look at the existing code for examples.
* Don't touch the `json-ld.gemspec`, `VERSION` or `AUTHORS` files. If you need to
  change them, do so on your private branch only.
* Do feel free to add yourself to the `CREDITS` file and the corresponding
  list in the the `README`. Alphabetical order applies.
* Do note that in order for us to merge any non-trivial changes (as a rule
  of thumb, additions larger than about 15 lines of code), we need an
  explicit [public domain dedication][PDD] on record from you.

License
-------

This is free and unencumbered public domain software. For more information,
see <http://unlicense.org/> or the accompanying {file:UNLICENSE} file.

[Ruby]:             http://ruby-lang.org/
[RDF]:              http://www.w3.org/RDF/
[YARD]:             http://yardoc.org/
[YARD-GS]:          http://rubydoc.info/docs/yard/file/docs/GettingStarted.md
[PDD]:              http://lists.w3.org/Archives/Public/public-rdf-ruby/2010May/0013.html
[RDF.rb]:           http://rubygems.org/gems/rdf
