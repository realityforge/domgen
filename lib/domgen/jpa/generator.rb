module Domgen
  module Generator
    def self.define_jpa_templates
      template_dir = "#{File.dirname(__FILE__)}/templates"
      [
        Template.new(:object_type,
                     "#{template_dir}/model.erb",
                     'java/#{object_type.java.fully_qualified_name.gsub(".","/")}.java',
                     [Domgen::Jpa::Helper]),
        Template.new(:object_type,
                     "#{template_dir}/dao.erb",
                     'java/#{object_type.java.fully_qualified_name.gsub(".","/")}DAO.java'),
        Template.new(:schema,
                     "#{template_dir}/entity_manager.erb",
                     'java/#{schema.java.package.gsub(".","/")}/SchemaEntityManager.java'),
        Template.new(:schema_set,
                     "#{template_dir}/persistence.erb",
                     'resources/META-INF/persistence.xml'),
      ]
    end
  end
end
