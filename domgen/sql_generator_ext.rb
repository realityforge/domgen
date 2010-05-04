module Domgen
  module Generator
    def self.define_sql_templates(template_set)
      template_set.per_schema << Template.new('sql/ddl', 'schema.sql', 'databases/#{schema.name}')
    end
  end
end
