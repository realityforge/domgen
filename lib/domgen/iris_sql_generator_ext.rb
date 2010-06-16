module Domgen
  module Generator
    def self.define_iris_sql_templates
      template_dir = "#{File.dirname(__FILE__)}/templates/iris_sql"
      [
          Template.new(:schema, "#{template_dir}/sync_checks.erb", "master/stored-procedures/sync_checks.sql"),
          Template.new(:schema, "#{template_dir}/runner.erb", "master/stored-procedures/Sync.spImportFromIFIS.sql"),
      ]
    end
  end
end
