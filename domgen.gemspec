Gem::Specification.new do |spec|
  spec.name           = 'domgen'
  spec.version        = `git describe`.strip.split('-').first
  spec.authors        = ['Peter Donald']
  spec.email          = ["peter@stocksoftware.com.au"]
  spec.homepage       = "http://github.com/stocksoftware/domgen"
  spec.summary        = "Extendable generator of SQL,AR,Hibernate models from data model DSL"
  spec.description    = <<-TEXT
This is an for generating, at least, SQL DDL and Active Record and Hibernate Models
from a Data Model definition file described in an extendable DSL
  TEXT
  spec.files          = Dir['{lib}/**/*', '*.gemspec'] +
                        ['Rakefile']
  spec.require_paths  = ['lib']

  spec.has_rdoc         = false
end
