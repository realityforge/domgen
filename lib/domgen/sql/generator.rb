module Domgen
  module Generator
    module Sql
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:sql]
    end
  end
end
Domgen.template_set(:mssql) do |template_set|
  template_set.template(Domgen::Generator::Sql::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Sql::TEMPLATE_DIRECTORY}/mssql_ddl.sql.erb",
                        '#{data_module.name}/schema.sql',
                        [::Domgen::Ruby::MssqlHelper])
  template_set.template(Domgen::Generator::Sql::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Sql::TEMPLATE_DIRECTORY}/mssql_finalize.sql.erb",
                        '#{data_module.name}/finalize/schema_finalize.sql',
                        [::Domgen::Ruby::MssqlHelper])
end
Domgen.template_set(:pgsql) do |template_set|
  template_set.template(Domgen::Generator::Sql::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Sql::TEMPLATE_DIRECTORY}/pgsql_ddl.sql.erb",
                        '#{data_module.name}/schema.sql')
  template_set.template(Domgen::Generator::Sql::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Sql::TEMPLATE_DIRECTORY}/pgsql_finalize.sql.erb",
                        '#{data_module.name}/finalize/schema_finalize.sql')
end