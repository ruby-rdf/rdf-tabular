source "https://rubygems.org"

gemspec
gem 'rdf',      git: "git://github.com/ruby-rdf/rdf.git", branch: "develop"
gem 'rdf-spec', git: "git://github.com/ruby-rdf/rdf-spec.git", branch: "develop"
gem 'rdf-xsd',  git: "git://github.com/ruby-rdf/rdf-xsd.git", branch: "develop"

group :development do
  gem 'json-ld',  git: "git://github.com/ruby-rdf/json-ld.git", branch: "develop"
  gem "linkeddata",  git: "git://github.com/ruby-rdf/linkeddata.git", branch: "develop"
  gem 'rdf-aggregate-repo', git: "git://github.com/ruby-rdf/rdf-aggregate-repo.git", branch: "develop"
  gem 'rdf-isomorphic', git: "git://github.com/ruby-rdf/rdf-isomorphic.git", branch: "develop"
  gem 'rdf-n3', git: "git://github.com/ruby-rdf/rdf-n3.git", branch: "develop"
  gem 'rdf-rdfa', git: "git://github.com/ruby-rdf/rdf-rdfa.git", branch: "develop"
  gem 'rdf-trig', git: "git://github.com/ruby-rdf/rdf-trig.git", branch: "develop"
  gem 'rdf-turtle', git: "git://github.com/ruby-rdf/rdf-turtle.git", branch: "develop"
  gem 'rdf-vocab', git: "git://github.com/ruby-rdf/rdf-vocab.git", branch: "develop"
  gem 'sparql', git: "git://github.com/ruby-rdf/sparql.git", branch: "develop"
end

group :debug do
  gem "wirble"
  gem "byebug",  platforms: [:mri_21]
end

group :development, :test do
  gem 'simplecov',  require: false
  gem 'coveralls',  require: false
  gem 'psych',      platforms: [:mri, :rbx]
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
end
