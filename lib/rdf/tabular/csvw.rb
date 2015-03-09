# -*- encoding: utf-8 -*-
# This file generated automatically using vocab-fetch from http://www.w3.org/ns/csvw#
require 'rdf'
module RDF::Tabular
  class CSVW < RDF::Vocabulary("http://www.w3.org/ns/csvw#")

    # Class definitions
    term :Column,
      comment: %(A Column Description describes a single column.).freeze,
      label: "Column Description".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdfs:Class".freeze
    term :Dialect,
      comment: %(A Dialect Description provides hints to parsers about how to parse a linked file.).freeze,
      label: "Dialect Description".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdfs:Class".freeze
    term :Direction,
      comment: %(The class of table/text directions.).freeze,
      label: "Direction".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdfs:Class".freeze
    term :Schema,
      comment: %(A Schema is a definition of a tabular format that may be common to multiple tables.).freeze,
      label: "Schema".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdfs:Class".freeze
    term :Table,
      comment: %(A table description is a JSON object that describes a table within a CSV file.).freeze,
      label: "Table Description".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdfs:Class".freeze
    term :TableGroup,
      comment: %(A Table Group Description describes a group of Tables.).freeze,
      label: "Table Group Description".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdfs:Class".freeze
    term :Transformation,
      comment: %(A Transformation Specification is a definition of how tabular data can be transformed into another format.).freeze,
      label: "Transformation Specification".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdfs:Class".freeze

    # Property definitions
    property :columns,
      comment: %(An array of Column Descriptions.).freeze,
      domain: "http://www.w3.org/ns/csvw#Schema".freeze,
      label: "columns".freeze,
      range: "http://www.w3.org/ns/csvw#Column".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :commentPrefix,
      comment: %(A character that, when it appears at the beginning of a skipped row, indicates a comment that should be associated as a comment annotation to the table. The default is "#".).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "comment prefix".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :datatype,
      comment: %(The main datatype of the values of the cell. If the cell contains a list \(ie separator is specified and not null\) then this is the datatype of each value within the list.).freeze,
      label: "datatype".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :default,
      comment: %(An atomic property holding a single string that provides a default string value for the cell in cases where the original string value is a null value. This default value may be used when converting the table into other formats.).freeze,
      label: "default".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :delimiter,
      comment: %(The separator between cells. The default is ",".).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "delimiter".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :dialect,
      comment: %(Provides hints to processors about how to parse the referenced files for to create tabular data models for an individual table, or all the tables in a group.).freeze,
      label: "dialect".freeze,
      range: "http://www.w3.org/ns/csvw#Dialect".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :doubleQuote,
      comment: %(If true, sets the escape character flag to ". If false, to \.).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "double quote".freeze,
      range: "xsd:boolean".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :encoding,
      comment: %(The character encoding for the file, one of the encodings listed in [encoding]. The default is utf-8.).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "encoding".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :foreignKeys,
      comment: %(An array of foreign key definitions that define how the values from specified columns within this table link to rows within this table or other tables.).freeze,
      domain: "http://www.w3.org/ns/csvw#Schema".freeze,
      label: "foreign keys".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :format,
      comment: %(A definition of the format of the cell, used when parsing the cell.).freeze,
      label: "format".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :header,
      comment: %().freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "header".freeze,
      range: "xsd:boolean".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :headerColumnCount,
      comment: %(The number of header columns \(following the skipped columns\) in each row. The default is 0.
).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "header column count".freeze,
      range: "xsd:nonNegativeInteger".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :headerRowCount,
      comment: %(The number of header rows \(following the skipped rows\) in the file. The default is 1.).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "header row count".freeze,
      range: "xsd:nonNegativeInteger".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :language,
      comment: %(A language code as defined by [BCP47]. Indicates the language of the value within the cell.).freeze,
      label: "language".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :length,
      comment: %(The exact length of the value of the cell.).freeze,
      label: "length".freeze,
      range: "xsd:nonNegativeInteger".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :lineTerminator,
      comment: %(The character that is used at the end of a row. The default is CRLF.).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "line terminator".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :maxExclusive,
      comment: %(The maximum value for the cell \(exclusive\).).freeze,
      label: "max exclusive".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :maxInclusive,
      comment: %(The maximum value for the cell \(inclusive\). ).freeze,
      label: "max inclusive".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :maxLength,
      comment: %(The maximum length of the value of the cell.).freeze,
      label: "max length".freeze,
      range: "xsd:nonNegativeInteger".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :minExclusive,
      comment: %(The minimum value for the cell \(exclusive\).).freeze,
      label: "min exclusive".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :minInclusive,
      comment: %(The minimum value for the cell \(inclusive\).).freeze,
      label: "min inclusive".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :minLength,
      comment: %(The minimum length of the value of the cell.).freeze,
      label: "min length".freeze,
      range: "xsd:nonNegativeInteger".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :name,
      comment: %(An atomic property that gives a canonical name for the column. This must be a string. Conversion specifications must use this property as the basis for the names of properties/elements/attributes in the results of conversions.).freeze,
      domain: "http://www.w3.org/ns/csvw#Column".freeze,
      label: "name".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :notes,
      comment: %(An array of objects representing annotations. This specification does not place any constraints on the structure of these objects.).freeze,
      domain: "http://www.w3.org/ns/csvw#Table".freeze,
      label: "notes".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :null,
      comment: %(The string used for null values. If not specified, the default for this is the empty string.).freeze,
      label: "null".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :predicateUrl,
      comment: %(An atomic property that holds one or more URIs that may be used as URIs for predicates if the table is mapped to another format.).freeze,
      domain: "http://www.w3.org/ns/csvw#Column".freeze,
      label: "predicate URL".freeze,
      range: "xsd:anyURI".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :primaryKey,
      comment: %(A column reference property that holds either a single reference to a column description object or an array of references.).freeze,
      domain: "http://www.w3.org/ns/csvw#Schema".freeze,
      label: "primary key".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :quoteChar,
      comment: %(The character that is used around escaped cells.).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "quote char".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :required,
      comment: %(A boolean value which indicates whether every cell within the column must have a non-null value.).freeze,
      domain: "http://www.w3.org/ns/csvw#Column".freeze,
      label: "required".freeze,
      range: "xsd:boolean".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :resources,
      comment: %(An array of table descriptions for the tables in the group.).freeze,
      domain: "http://www.w3.org/ns/csvw#TableGroup".freeze,
      label: "resources".freeze,
      range: "http://www.w3.org/ns/csvw#Table".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :row,
      comment: %(Relates a Table to each Row output.).freeze,
      domain: "http://www.w3.org/ns/csvw#Table".freeze,
      label: "row".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      subPropertyOf: "rdfs:member".freeze,
      type: "rdf:Property".freeze
    property :schema,
      comment: %(An object property that provides a schema description for an individual table, or all the tables in a group.).freeze,
      label: "schema".freeze,
      range: "http://www.w3.org/ns/csvw#Schema".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :separator,
      comment: %(The character used to separate items in the string value of the cell.).freeze,
      label: "separator".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :skipBlankRows,
      comment: %(Indicates whether to ignore wholly empty rows \(ie rows in which all the cells are empty\). The default is false.).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "skip blank rows".freeze,
      range: "xsd:boolean".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :skipColumns,
      comment: %(The number of columns to skip at the beginning of each row, before any header columns. The default is 0.).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "skip columns".freeze,
      range: "xsd:nonNegativeInteger".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :skipInitialSpace,
      comment: %(If true, sets the trim flag to "start". If false, to false.).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "skip initial space".freeze,
      range: "xsd:boolean".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :skipRows,
      comment: %(The number of rows to skip at the beginning of the file, before a header row or tabular data.).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "skip rows".freeze,
      range: "xsd:nonNegativeInteger".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :source,
      comment: %(The format to which the tabular data should be transformed prior to the transformation using the template. If the value is "json", the tabular data should first be transformed first to JSON based on the simple mapping defined in Generating JSON from Tabular Data on the Web. If the value is "rdf", it should similarly first be transformed to XML based on the simple mapping defined in Generating RDF from Tabular Data on the Web.).freeze,
      domain: "http://www.w3.org/ns/csvw#Transformation".freeze,
      label: "source".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :table,
      comment: %(Relates an Table group to annotated tables. \(Note, this is different from csvw:resources, which relates metadata, rather than resulting annotated table descriptions.).freeze,
      domain: "http://www.w3.org/ns/csvw#TableGroup".freeze,
      label: "table".freeze,
      range: "http://www.w3.org/ns/csvw#Table".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      subPropertyOf: "rdfs:member".freeze,
      type: "rdf:Property".freeze
    property :"table-direction",
      comment: %(One of csvw:rtl csvw:ltr or csvw:default. Indicates whether the tables in the group should be displayed with the first column on the right, on the left, or based on the first character in the table that has a specific direction. ).freeze,
      label: "table direction".freeze,
      range: "http://www.w3.org/ns/csvw#Direction".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :targetFormat,
      comment: %(A URL for the format that will be created through the transformation. If one has been defined, this should be a URL for a media type, in the form http://www.iana.org/assignments/media-types/media-type such as http://www.iana.org/assignments/media-types/text/calendar. Otherwise, it can be any URL that describes the target format.).freeze,
      domain: "http://www.w3.org/ns/csvw#Transformation".freeze,
      label: "target format".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :templateFormat,
      comment: %(A URL for the format that is used by the template. If one has been defined, this should be a URL for a media type, in the form http://www.iana.org/assignments/media-types/media-type such as http://www.iana.org/assignments/media-types/application/javascript. Otherwise, it can be any URL that describes the template format.).freeze,
      domain: "http://www.w3.org/ns/csvw#Transformation".freeze,
      label: "template format".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :transformations,
      comment: %(An array of template specifications that provide mechanisms to transform the tabular data into other formats. ).freeze,
      label: "transformations".freeze,
      range: "http://www.w3.org/ns/csvw#Transformation".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :"text-direction",
      comment: %(One of csvw:rtl or csvw:ltr. Indicates whether the text within cells should be displayed by default as left-to-right or right-to-left text. ).freeze,
      label: "text direction".freeze,
      range: "http://www.w3.org/ns/csvw#Direction".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :title,
      comment: %(For a Transformation: A natural language property that describes the format that will be generated from the transformation. This is useful if the target format is a generic format \(such as application/json\) and the transformation is creating a specific profile of that format.

For a Column: A natural language property that provides possible alternative names for the column.).freeze,
      label: "title".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :trim,
      comment: %(Indicates whether to trim whitespace around cells; may be true, false, start or end. The default is false.).freeze,
      domain: "http://www.w3.org/ns/csvw#Dialect".freeze,
      label: "trim".freeze,
      range: "xsd:boolean".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze
    property :uriTransformation,
      comment: %(A URI template property that may be used to create a unique identifier for each row when mapping data to other formats.).freeze,
      domain: "http://www.w3.org/ns/csvw#Schema".freeze,
      label: "uri template".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "rdf:Property".freeze

    # Datatype definitions
    term :json,
      comment: %(A literal containing JSON.).freeze,
      label: "json".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      subClassOf: "rdfs:Literal".freeze,
      type: "rdfs:Datatype".freeze

    # Extra definitions
    term :"",
      "dc:description" => %(Validation, conversion, display and search of tabular data on the web
    requires additional metadata that describes how the data should be
    interpreted. This document defines a vocabulary for metadata that
    annotates tabular data. This can be used to provide metadata at various
    levels, from collections of data from CSV documents and how they relate
    to each other down to individual cells within a table.).freeze,
      "dc:title" => %(Metadata Vocabulary for Tabular Data).freeze,
      label: "".freeze,
      type: "owl:Ontology".freeze
    term :ltr,
      comment: %(Indicates text should be processed left to right.).freeze,
      label: "left to right".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "http://www.w3.org/ns/csvw#Direction".freeze
    term :rtl,
      comment: %(Indiects text should be processed right to left).freeze,
      label: "right to left".freeze,
      "rdfs:isDefinedBy" => %(http://www.w3.org/ns/csvw#).freeze,
      type: "http://www.w3.org/ns/csvw#Direction".freeze
  end
end
