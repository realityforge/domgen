module Domgen
  module Generator
    def self.define_sql_templates
      template_dir = "#{File.dirname(__FILE__)}/templates"
      [
        Template.new(:schema, "#{template_dir}/ddl.erb", '#{schema.name}/schema.sql'),
        Template.new(:schema, "#{template_dir}/tags.erb", '#{schema.name}/schema_tags.sql'),
      ]
    end
  end
end
