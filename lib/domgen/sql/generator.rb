module Domgen
  module Generator
    module Sql
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:sql]
    end

    def self.define_mssql_templates
      [
        Template.new(Sql::FACETS,
                     :data_module,
                     "#{Sql::TEMPLATE_DIRECTORY}/mssql_ddl.erb",
                     '#{data_module.name}/schema.sql',
                     [::Domgen::Ruby::MssqlHelper],
                     'data_module.sql?'),
        Template.new(Sql::FACETS,
                     :data_module,
                     "#{Sql::TEMPLATE_DIRECTORY}/mssql_finalize.erb",
                     '#{data_module.name}/finalize/schema_finalize.sql',
                     [::Domgen::Ruby::MssqlHelper],
                     'data_module.sql?'),
      ]
    end

    def self.define_pgsql_templates
      [
        Template.new(Sql::FACETS,
                     :data_module,
                     "#{Sql::TEMPLATE_DIRECTORY}/pgsql_ddl.erb",
                     '#{data_module.name}/schema.sql',
                     [],
                     'data_module.sql?'),
        Template.new(Sql::FACETS,
                     :data_module,
                     "#{Sql::TEMPLATE_DIRECTORY}/pgsql_finalize.erb",
                     '#{data_module.name}/finalize/schema_finalize.sql',
                     [],
                     'data_module.sql?'),
      ]
    end
  end
end
