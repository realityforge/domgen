module Domgen
  module Generator
    module Sql
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:sql]
    end

    def self.define_mssql_templates
      [
        Template.new(Sql::FACETS, :data_module, "#{Sql::TEMPLATE_DIRECTORY}/mssql_ddl.erb", '#{data_module.name}/schema.sql', [::Domgen::Ruby::MssqlHelper]),
        Template.new(Sql::FACETS, :data_module, "#{Sql::TEMPLATE_DIRECTORY}/mssql_finalize.erb", '#{data_module.name}/finalize/schema_finalize.sql', [::Domgen::Ruby::MssqlHelper]),
      ]
    end

    def self.define_pgsql_templates
      [
        Template.new(Sql::FACETS, :data_module, "#{Sql::TEMPLATE_DIRECTORY}/pgsql_ddl.erb", '#{data_module.name}/schema.sql'),
        Template.new(Sql::FACETS, :data_module, "#{Sql::TEMPLATE_DIRECTORY}/pgsql_finalize.erb", '#{data_module.name}/finalize/schema_finalize.sql'),
      ]
    end
  end
end
