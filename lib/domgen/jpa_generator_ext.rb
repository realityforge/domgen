module Domgen
  module Generator
    def self.define_jpa_templates(template_set)
      template_set.per_schema_set << Template.new('jpa/persistence', 'META-INF/persistence.xml', 'resources')
      template_set.per_schema << Template.new('jpa/entity_manager',
                                              '#{schema.java.package.gsub(".","/")}/SchemaEntityManager.java',
                                              'java')
      template_set.per_object_type << Template.new('jpa/model',
                                                   '#{object_type.java.fully_qualified_name.gsub(".","/")}.java',
                                                   'java')
      template_set.per_object_type << Template.new('jpa/dao',
                                                   '#{object_type.java.fully_qualified_name.gsub(".","/")}DAO.java',
                                                   'java')
    end
  end
end
