module Domgen
  module Generator
    module Jpa
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
    end

    def self.define_jpa_model_templates
      [Template.new(:object_type,
                    "#{Jpa::TEMPLATE_DIRECTORY}/model.erb",
                    'java/#{object_type.java.fully_qualified_name.gsub(".","/")}.java',
                    [Domgen::Jpa::Helper],
                    'object_type.jpa.persistent?')]
    end

    def self.define_jpa_ejb_templates
      [
        Template.new(:object_type,
                     "#{Jpa::TEMPLATE_DIRECTORY}/ejb.erb",
                     'java/#{object_type.data_module.java.package.gsub(".","/")}/ejb/#{object_type.java.classname}EJB.java',
                    [],
                    'object_type.jpa.persistent?')
      ]
    end

    def self.define_jpa_dao_templates
      [
        Template.new(:object_type,
                     "#{Jpa::TEMPLATE_DIRECTORY}/dao.erb",
                     'java/#{object_type.data_module.java.package.gsub(".","/")}/dao/#{object_type.java.classname}DAO.java',
                    [],
                    'object_type.jpa.persistent?'),
        Template.new(:data_module,
                     "#{Jpa::TEMPLATE_DIRECTORY}/entity_manager.erb",
                     'java/#{data_module.java.package.gsub(".","/")}/dao/SchemaEntityManager.java'),
      ]
    end

    def self.define_jpa_jta_persistence_templates
      [Template.new(:repository, "#{Jpa::TEMPLATE_DIRECTORY}/persistence.erb", 'resources/META-INF/persistence.xml')]
    end
  end
end
