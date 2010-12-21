module Domgen
  module Generator
    def self.define_sql_templates
      template_dir = "#{File.dirname(__FILE__)}/templates"
      [
        Template.new(:data_module, "#{template_dir}/ddl.erb", '#{data_module.name}/schema.sql'),
        Template.new(:data_module, "#{template_dir}/constraints.erb", '#{data_module.name}/schema_constraints.sql'),
        Template.new(:data_module, "#{template_dir}/constraints_check.erb", '#{data_module.name}/finalize/check_constraints.sql'),
      ]
    end
  end
end
