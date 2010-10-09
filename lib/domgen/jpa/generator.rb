module Domgen
  module Generator
    def self.define_jpa_templates
      template_dir = "#{File.dirname(__FILE__)}/templates"
      java_class_prefix = 'java/#{object_type.java.fully_qualified_name.gsub(".","/")}'
      java_package_prefix = 'java/#{schema.java.package.gsub(".","/")}'
      [
        Template.new(:object_type, "#{template_dir}/model.erb", "#{java_class_prefix}.java", [Domgen::Jpa::Helper]),
        Template.new(:object_type, "#{template_dir}/dao.erb", "#{java_class_prefix}DAO.java"),
        Template.new(:schema, "#{template_dir}/entity_manager.erb", "#{java_package_prefix}/SchemaEntityManager.java"),
        Template.new(:schema_set, "#{template_dir}/persistence.erb", 'resources/META-INF/persistence.xml'),
      ]
    end
  end
end
