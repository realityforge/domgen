Gem::Specification.new do |spec|
  spec.name           = 'domgen'
  spec.version        = `git describe`.strip.split('-').first
  spec.authors        = ['Peter Donald']
  spec.email          = ["peter@realityforge.org"]
  spec.homepage       = "http://github.com/stocksoftware/domgen"
  spec.summary        = "Extendable generator of SQL,AR,Hibernate models from data model DSL"
  spec.description    = <<-TEXT
This is an extensible generator that includes support for SQL DDL, Active Record models and Hibernate Models
from a data model definition file described in an extendable DSL.
  TEXT
  spec.files          = Dir['{lib}/**/*', '*.gemspec'] +
                        ['Rakefile']
  spec.require_paths  = ['lib']

  spec.has_rdoc         = false
end
