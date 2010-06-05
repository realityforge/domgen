module Domgen
  module Generator
    def self.define_sql_templates
      [
          Template.new(:schema, 'sql/ddl', '#{underscore(schema.name)}/schema.sql'),
      ]
    end
  end
end
