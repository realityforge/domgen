module Domgen
  module Generator
    def self.define_mssql_templates
      template_dir = "#{File.dirname(__FILE__)}/templates"
      [
        Template.new(:data_module, "#{template_dir}/mssql_ddl.erb", '#{data_module.name}/schema.sql', [::Domgen::Ruby::MssqlHelper]),
        Template.new(:data_module, "#{template_dir}/mssql_finalize.erb", '#{data_module.name}/finalize/schema_finalize.sql', [::Domgen::Ruby::MssqlHelper]),
      ]
    end

    def self.define_pgsql_templates
      template_dir = "#{File.dirname(__FILE__)}/templates"
      [
        Template.new(:data_module, "#{template_dir}/pgsql_ddl.erb", '#{data_module.name}/schema.sql'),
      Template.new(:data_module, "#{template_dir}/pgsql_finalize.erb", '#{data_module.name}/finalize/schema_finalize.sql'),
      ]
    end
  end
end
