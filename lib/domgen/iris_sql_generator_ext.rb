module Domgen
  module Generator
    def self.define_iris_sql_templates
      [
          Template.new(:schema, 'iris_sql/sync_checks', "master/stored-procedures/sync_checks.sql"),
          Template.new(:schema, 'iris_sql/runner', "master/stored-procedures/Sync.spImportFromIFIS.sql"),
      ]
    end
  end
end
