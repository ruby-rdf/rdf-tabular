source "https://rubygems.org"

gemspec
gem 'rdf',      git: "git://github.com/ruby-rdf/rdf.git", branch: "develop"
gem 'rdf-spec', git: "git://github.com/ruby-rdf/rdf-spec.git", branch: "develop"
gem 'rdf-xsd',  git: "git://github.com/ruby-rdf/rdf-xsd.git", branch: "develop"
gem 'json-ld',  git: "git://github.com/ruby-rdf/json-ld.git", branch: "develop"

group :development do
  gem "linkeddata"
end

group :debug do
  gem "wirble"
  gem "byebug",  platforms: [:mri_21, :mri_22]
end

group :development, :test do
  gem 'simplecov', require: false
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
end
