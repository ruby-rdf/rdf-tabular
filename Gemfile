source "https://rubygems.org"

gemspec
gem 'rdf',      git: "git://github.com/ruby-rdf/rdf.git", branch: "develop"
gem 'rdf-spec', git: "git://github.com/ruby-rdf/rdf-spec.git", branch: "develop"
gem 'json-ld',  git: "git://github.com/ruby-rdf/json-ld.git", branch: "develop"
gem 'bcp47'

group :development do
  gem "linkeddata"
end

group :debug do
  gem "wirble"
  gem "byebug", platforms: [:mri_20, :mri_21]
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
end
