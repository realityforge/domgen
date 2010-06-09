module Domgen
  module Generator
    def self.define_jpa_templates
      [
          Template.new(:object_type,
                       'jpa/model',
                       'java/#{object_type.java.fully_qualified_name.gsub(".","/")}.java',
                       [JpaHelper]),
          Template.new(:object_type,
                       'jpa/dao',
                       'java/#{object_type.java.fully_qualified_name.gsub(".","/")}DAO.java'),
          Template.new(:schema,
                       'jpa/entity_manager',
                       'java/#{schema.java.package.gsub(".","/")}/SchemaEntityManager.java'),
          Template.new(:schema_set,
                       'jpa/persistence',
                       'resources/META-INF/persistence.xml'),
      ]
    end
  end
end
