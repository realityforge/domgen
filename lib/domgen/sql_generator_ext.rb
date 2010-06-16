module Domgen
  module Generator
    def self.define_sql_templates
      template_dir = "#{File.dirname(__FILE__)}/templates/sql"
      [
          Template.new(:schema, "#{template_dir}/ddl.erb", '#{underscore(schema.name)}/schema.sql'),
      ]
    end
  end
end
