# Tabular Data RDF Reader and JSON serializer

[CSV][] reader for [RDF.rb][] and fully JSON serializer.

[![Gem Version](https://badge.fury.io/rb/rdf-tabular.png)](http://badge.fury.io/rb/rdf-tabular)
[![Build Status](https://secure.travis-ci.org/ruby-rdf/rdf-tabular.png?branch=master)](http://travis-ci.org/ruby-rdf/rdf-tabular)
[![Coverage Status](https://coveralls.io/repos/ruby-rdf/rdf-tabular/badge.svg)](https://coveralls.io/r/ruby-rdf/rdf-tabular)
[![Dependency Status](https://gemnasium.com/ruby-rdf/rdf-tabular.png)](https://gemnasium.com/ruby-rdf/rdf-tabular)

## Features

RDF::Tabular parses CSV or other Tabular Data into [RDF][] and JSON using the [W3C CSVW][] specifications, currently undergoing development.

* Parses [number patterns](http://www.unicode.org/reports/tr35/tr35-39/tr35-numbers.html#Number_Patterns) from [UAX35][]
* Parses [date formats](http://www.unicode.org/reports/tr35/tr35-39/tr35-dates.html#Contents) from [UAX35][]
* Returns detailed errors and warnings using optional `Logger`.

## Installation
Install with `gem install rdf-tabular`

## Description
RDF::Tabular parses CSVs, TSVs, and potentially other tabular data formats. Using rules defined for [W3C CSVW][], it can also parse metadata files (in JSON-LD format) to find a set of tabular data files, or locate a metadata file given a CSV:

* Given a CSV `http://example.org/mycsv.csv` look for `http://example.org/mycsv.csv-metata.json` or `http://example.org/metadata.json`. Metadata can also be specified using the `describedby` link header to reference a metadata file.
* Given a metadata file, locate one or more CSV files described within the metadata file.
* Also, extract _embedded metadata_ from the CSV (limited to column titles right now).

Metadata can then provide datatypes for the columns, express foreign key relationships, and associate subjects and predicates with columns. An example [metadata file for the project DOAP description](https://raw.githubusercontent.com/ruby-rdf/rdf-tabular/develop/etc/doap.csv-metadata.json) is:

    {
      "@context": "http://www.w3.org/ns/csvw",
      "url": "doap.csv",
      "tableSchema": {
        "aboutUrl": "http://rubygems.org/gems/rdf-tabular",
        "propertyUrl": "http://usefulinc.com/ns/doap#{_name}",
        "null": "",
        "columns": [
          {"titles": "name"},
          {"titles": "type", "propertyUrl": "rdf:type", "valueUrl": "{+type}"},
          {"titles": "homepage", "valueUrl": "{+homepage}"},
          {"titles": "license", "valueUrl": "{+license}"},
          {"titles": "shortdesc", "lang": "en"},
          {"titles": "description", "lang": "en"},
          {"titles": "created", "datatype": {"base": "date", "format": "M/d/yyyy"}},
          {"titles": "programming_language", "propertyUrl": "http://usefulinc.com/ns/doap#programming-language"},
          {"titles": "implements", "valueUrl": "{+implements}"},
          {"titles": "category", "valueUrl": "{+category}"},
          {"titles": "download_page", "propertyUrl": "http://usefulinc.com/ns/doap#download-page", "valueUrl": "{+download_page}"},
          {"titles": "mailing_list", "propertyUrl": "http://usefulinc.com/ns/doap#mailing-list", "valueUrl": "{+mailing_list}"},
          {"titles": "bug_database", "propertyUrl": "http://usefulinc.com/ns/doap#bug-database", "valueUrl": "{+bug_database}"},
          {"titles": "blog", "valueUrl": "{+blog}"},
          {"titles": "developer", "valueUrl": "{+developer}"},
          {"titles": "maintainer", "valueUrl": "{+maintainer}"},
          {"titles": "documenter", "valueUrl": "{+documenter}"},
          {"titles": "maker", "propertyUrl": "foaf:maker", "valueUrl": "{+maker}"},
          {"titles": "dc_title", "propertyUrl": "dc:title"},
          {"titles": "dc_description", "propertyUrl": "dc:description", "lang": "en"},
          {"titles": "dc_date", "propertyUrl": "dc:date", "datatype": {"base": "date", "format": "M/d/yyyy"}},
          {"titles": "dc_creator", "propertyUrl": "dc:creator", "valueUrl": "{+dc_creator}"},
          {"titles": "isPartOf", "propertyUrl": "dc:isPartOf", "valueUrl": "{+isPartOf}"}
        ]
      }
    }

This associates the metadata with the CSV [doap.csv](https://raw.githubusercontent.com/ruby-rdf/rdf-tabular/develop/etc/doap.csv), creates a common subject for all rows in the file, and a common predicate using the URI Template [URI Template](https://tools.ietf.org/html/rfc6570) `http://usefulinc.com/ns/doap#\{_name\}` which uses the `name` of each column (defaulted from `titles`) to construct a URI in the DOAP vocabulary, and constructs object URIs for object-valued properties from the contents of the column cells. In some cases, the predicates are changed on a per-column basis by using a different `propertyUrl` property on a given column.

This results in the following Turtle:

    @prefix csvw: <http://www.w3.org/ns/csvw#> .
    @prefix dc: <http://purl.org/dc/terms/> .
    @prefix doap: <http://usefulinc.com/ns/doap#> .
    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @prefix prov: <http://www.w3.org/ns/prov#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <http://rubygems.org/gems/rdf-tabular> a doap:Project,
         <http://www.w3.org/ns/earl#TestSubject>,
         <http://www.w3.org/ns/earl#Software>;
       dc:title "RDF::Tabular";
       dc:creator <http://greggkellogg.net/foaf#me>;
       dc:date "2015-01-05"^^xsd:date;
       dc:description "RDF::Tabular processes tabular data with metadata creating RDF or JSON output."@en;
       dc:isPartOf <http://rubygems.org/gems/rdf>;
       doap:blog <http://greggkellogg.net/>;
       doap:bug-database <http://github.com/ruby-rdf/rdf-tabular/issues>;
       doap:category <http://dbpedia.org/resource/Resource_Description_Framework>,
         <http://dbpedia.org/resource/Ruby_(programming_language)>;
       doap:created "2015-01-05"^^xsd:date;
       doap:description "RDF::Tabular processes tabular data with metadata creating RDF or JSON output."@en;
       doap:developer <http://greggkellogg.net/foaf#me>;
       doap:documenter <http://greggkellogg.net/foaf#me>;
       doap:download-page <http://rubygems.org/gems/rdf-tabular>;
       doap:homepage <http://ruby-rdf.github.com/rdf-tabular>;
       doap:implements <http://www.w3.org/TR/tabular-data-model/>,
         <http://www.w3.org/TR/tabular-metadata/>,
         <http://www.w3.org/TR/csv2rdf/>,
         <http://www.w3.org/TR/csv2json/>;
       doap:license <http://creativecommons.org/licenses/publicdomain/>;
       doap:mailing-list <http://lists.w3.org/Archives/Public/public-rdf-ruby/>;
       doap:maintainer <http://greggkellogg.net/foaf#me>;
       doap:name "RDF::Tabular";
       doap:programming-language "Ruby";
       doap:shortdesc "Tabular Data RDF Reader and JSON serializer."@en;
       foaf:maker <http://greggkellogg.net/foaf#me> .

     [
        a csvw:TableGroup;
        csvw:table [
          a csvw:Table;
          csvw:row [
            a csvw:Row;
            csvw:describes <http://rubygems.org/gems/rdf-tabular>;
            csvw:rownum 1;
            csvw:url <file://users/gregg/Projects/rdf-tabular/etc/doap.csv#row=2>
          ],  [
            a csvw:Row;
            csvw:describes <http://rubygems.org/gems/rdf-tabular>;
            csvw:rownum 2;
            csvw:url <file://users/gregg/Projects/rdf-tabular/etc/doap.csv#row=3>
          ],  [
            a csvw:Row;
            csvw:describes <http://rubygems.org/gems/rdf-tabular>;
            csvw:rownum 3;
            csvw:url <file://users/gregg/Projects/rdf-tabular/etc/doap.csv#row=4>
          ],  [
            a csvw:Row;
            csvw:describes <http://rubygems.org/gems/rdf-tabular>;
            csvw:rownum 4;
            csvw:url <file://users/gregg/Projects/rdf-tabular/etc/doap.csv#row=5>
          ];
          csvw:url <file://users/gregg/Projects/rdf-tabular/etc/doap.csv>
        ];
        prov:wasGeneratedBy [
          a prov:Activity;
          prov:endedAtTime "2015-04-11T12:33:26Z"^^xsd:dateTime;
          prov:qualifiedUsage [
            a prov:Usage;
            prov:entity <file://users/gregg/Projects/rdf-tabular/etc/doap.csv>;
            prov:hadRole csvw:csvEncodedTabularData
          ],  [
            a prov:Usage;
            prov:entity <file://users/gregg/Projects/rdf-tabular/etc/doap.csv-metadata.json>;
            prov:hadRole csvw:tabularMetadata
          ];
          prov:startedAtTime "2015-04-11T12:33:25Z"^^xsd:dateTime;
          prov:wasAssociatedWith <http://rubygems.org/gems/rdf-tabular>
        ]
     ] .

The provenance on table-source information can be excluded by using the `:minimal` option to the reader.

It can also generate JSON output (not complete JSON-LD, but compatible with it), using the {RDF::Tabular::Reader#to_json} method:

    {
      "table": [
        {
          "url": "file://users/gregg/Projects/rdf-tabular/etc/doap.csv",
          "row": [
            {
              "url": "file://users/gregg/Projects/rdf-tabular/etc/doap.csv#row=2",
              "rownum": 1,
              "describes": [
                {
                  "@id": "http://rubygems.org/gems/rdf-tabular",
                  "http://usefulinc.com/ns/doap#name": "RDF::Tabular",
                  "@type": "http://usefulinc.com/ns/doap#Project",
                  "http://usefulinc.com/ns/doap#homepage": "http://ruby-rdf.github.com/rdf-tabular",
                  "http://usefulinc.com/ns/doap#license": "http://creativecommons.org/licenses/publicdomain/",
                  "http://usefulinc.com/ns/doap#shortdesc": "Tabular Data RDF Reader and JSON serializer.",
                  "http://usefulinc.com/ns/doap#description": "RDF::Tabular processes tabular data with metadata creating RDF or JSON output.",
                  "http://usefulinc.com/ns/doap#created": "2015-01-05",
                  "http://usefulinc.com/ns/doap#programming-language": "Ruby",
                  "http://usefulinc.com/ns/doap#implements": "http://www.w3.org/TR/tabular-data-model/",
                  "http://usefulinc.com/ns/doap#category": "http://dbpedia.org/resource/Resource_Description_Framework",
                  "http://usefulinc.com/ns/doap#download-page": "http://rubygems.org/gems/rdf-tabular",
                  "http://usefulinc.com/ns/doap#mailing-list": "http://lists.w3.org/Archives/Public/public-rdf-ruby/",
                  "http://usefulinc.com/ns/doap#bug-database": "http://github.com/ruby-rdf/rdf-tabular/issues",
                  "http://usefulinc.com/ns/doap#blog": "http://greggkellogg.net/",
                  "http://usefulinc.com/ns/doap#developer": "http://greggkellogg.net/foaf#me",
                  "http://usefulinc.com/ns/doap#maintainer": "http://greggkellogg.net/foaf#me",
                  "http://usefulinc.com/ns/doap#documenter": "http://greggkellogg.net/foaf#me",
                  "foaf:maker": "http://greggkellogg.net/foaf#me",
                  "dc:title": "RDF::Tabular",
                  "dc:description": "RDF::Tabular processes tabular data with metadata creating RDF or JSON output.",
                  "dc:date": "2015-01-05",
                  "dc:creator": "http://greggkellogg.net/foaf#me",
                  "dc:isPartOf": "http://rubygems.org/gems/rdf"
                }
              ]
            },
            {
              "url": "file://users/gregg/Projects/rdf-tabular/etc/doap.csv#row=3",
              "rownum": 2,
              "describes": [
                {
                  "@id": "http://rubygems.org/gems/rdf-tabular",
                  "@type": "http://www.w3.org/ns/earl#TestSubject",
                  "http://usefulinc.com/ns/doap#implements": "http://www.w3.org/TR/tabular-metadata/",
                  "http://usefulinc.com/ns/doap#category": "http://dbpedia.org/resource/Ruby_(programming_language)"
                }
              ]
            },
            {
              "url": "file://users/gregg/Projects/rdf-tabular/etc/doap.csv#row=4",
              "rownum": 3,
              "describes": [
                {
                  "@id": "http://rubygems.org/gems/rdf-tabular",
                  "@type": "http://www.w3.org/ns/earl#Software",
                  "http://usefulinc.com/ns/doap#implements": "http://www.w3.org/TR/csv2rdf/"
                }
              ]
            },
            {
              "url": "file://users/gregg/Projects/rdf-tabular/etc/doap.csv#row=5",
              "rownum": 4,
              "describes": [
                {
                  "@id": "http://rubygems.org/gems/rdf-tabular",
                  "http://usefulinc.com/ns/doap#implements": "http://www.w3.org/TR/csv2json/"
                }
              ]
            }
          ]
        }
      ]
    }

## Tutorials

* [CSV on the Web](http://greggkellogg.net/CSV-on-the-Web)
* [Implementing CSV on the Web](http://greggkellogg.net/2015/04/implementing-csv-on-the-web/)

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
* [Ruby](http://ruby-lang.org/) (>= 2.2.2)
* [RDF.rb](http://rubygems.org/gems/rdf) (>= 2.0)
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
[URI template]:     https://tools.ietf.org/html/rfc6570
[UAX35]:            http://www.unicode.org/reports/tr15/