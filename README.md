# Tabular Data RDF Reader and JSON serializer

[CSV][] reader for [RDF.rb][] and fully JSON serializer.

[![Gem Version](https://badge.fury.io/rb/rdf-tabular.png)](http://badge.fury.io/rb/rdf-tabular)
[![Build Status](https://secure.travis-ci.org/ruby-rdf/rdf-tabular.png?branch=master)](http://travis-ci.org/ruby-rdf/rdf-tabular)

## Features

RDF::Tabular parses CSV or other Tabular Data into [RDF][] and JSON using the [W3C CSVW][] specifications, currently undergoing development.

Install with `gem install rdf-tabular`

## Examples

    require 'rubygems'
    require 'rdf/tabular'

## RDF Reader
RDF::Tabular also acts as a normal RDF reader, using the standard RDF.rb Reader interface:

    graph = RDF::Graph.load("etc/doap.csv", minimal: true)

## Documentation
Full documentation available on [RubyDoc](http://rubydoc.info/gems/rdf-tabular/file/README.md)

### Principal Classes
* {RDF::Tabular}
  * {RDF::Tabular::JSON}
  * {RDF::Tabular::Format}
  * {RDF::Tabular::Metadata}
  * {RDF::Tabular::Reader}

## Dependencies
* [Ruby](http://ruby-lang.org/) (>= 2.0.0)
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 1.0)
* [JSON](https://rubygems.org/gems/json) (>= 1.5)

## Installation
The recommended installation method is via [RubyGems](http://rubygems.org/).
To install the latest official release of the `RDF::Tabular` gem, do:

    % [sudo] gem install rdf-tabular

## Mailing List
* <http://lists.w3.org/Archives/Public/public-rdf-ruby/>

## Author
* [Gregg Kellogg](http://github.com/gkellogg) - <http://greggkellogg.net/>

## Contributing
* Do your best to adhere to the existing coding conventions and idioms.
* Don't use hard tabs, and don't leave trailing whitespace on any line.
* Do document every method you add using [YARD][] annotations. Read the
  [tutorial][YARD-GS] or just look at the existing code for examples.
* Don't touch the `rdf-tabular.gemspec`, `VERSION` or `AUTHORS` files. If you need to change them, do so on your private branch only.
* Do feel free to add yourself to the `CREDITS` file and the corresponding list in the the `README`. Alphabetical order applies.
* Do note that in order for us to merge any non-trivial changes (as a rule of thumb, additions larger than about 15 lines of code), we need an explicit [public domain dedication][PDD] on record from you.

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
[CSV]:              http://en.wikipedia.org/wiki/Comma-separated_values
[W3C CSVW]:         http://www.w3.org/2013/csvw/wiki/Main_Page
