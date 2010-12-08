module Domgen
  module Generator
    module Jpa
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      JAVA_CLASS_PREFIX = 'java/#{object_type.java.fully_qualified_name.gsub(".","/")}'
      JAVA_PACKAGE_PREFIX = 'java/#{data_module.java.package.gsub(".","/")}'
    end

    def self.define_jpa_model_templates
      [Template.new(:object_type,
                    "#{Jpa::TEMPLATE_DIRECTORY}/model.erb",
                    "#{Jpa::JAVA_CLASS_PREFIX}.java",
                    [Domgen::Jpa::Helper])]
    end

    def self.define_jpa_ejb_templates
      [Template.new(:object_type, "#{Jpa::TEMPLATE_DIRECTORY}/ejb.erb", "#{Jpa::JAVA_CLASS_PREFIX}EJB.java"),]
    end

    def self.define_jpa_dao_templates
      [
        Template.new(:object_type, "#{Jpa::TEMPLATE_DIRECTORY}/dao.erb", "#{Jpa::JAVA_CLASS_PREFIX}DAO.java"),
        Template.new(:data_module, "#{Jpa::TEMPLATE_DIRECTORY}/entity_manager.erb", "#{Jpa::JAVA_PACKAGE_PREFIX}/SchemaEntityManager.java"),
      ]
    end

    def self.define_jpa_jta_persistence_templates
      [Template.new(:schema_set, "#{Jpa::TEMPLATE_DIRECTORY}/persistence.erb", 'resources/META-INF/persistence.xml')]
    end
  end
end
