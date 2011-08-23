module Domgen
  module Generator
    module JPA
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jpa, :java, :sql]
    end

    def self.define_jpa_model_templates
      [
        Template.new(JPA::FACETS,
                     :object_type,
                     "#{JPA::TEMPLATE_DIRECTORY}/model.erb",
                     'java/#{object_type.java.qualified_name.gsub(".","/")}.java',
                     [Domgen::JPA::Helper, Domgen::Java::Helper],
                     'object_type.jpa.persistent?'),
        Template.new(JPA::FACETS,
                     :object_type,
                     "#{JPA::TEMPLATE_DIRECTORY}/metamodel.erb",
                     'java/#{object_type.java.qualified_name.gsub(".","/")}_.java',
                     [Domgen::JPA::Helper, Domgen::Java::Helper],
                     'object_type.jpa.persistent?'),
      ]
    end

    def self.define_jpa_ejb_templates
      [
        Template.new(JPA::FACETS,
                     :object_type,
                     "#{JPA::TEMPLATE_DIRECTORY}/ejb.erb",
                     'java/#{object_type.jpa.qualified_dao_name.gsub(".","/")}.java',
                     [],
                     'object_type.jpa.persistent?')
      ]
    end

    def self.define_jpa_dao_templates
      [
        Template.new(JPA::FACETS,
                     :object_type,
                     "#{JPA::TEMPLATE_DIRECTORY}/dao.erb",
                     'java/#{object_type.jpa.qualified_dao_name.gsub(".","/")}.java',
                     [],
                     'object_type.jpa.persistent?'),
        Template.new(JPA::FACETS,
                     :data_module,
                     "#{JPA::TEMPLATE_DIRECTORY}/entity_manager.erb",
                     'java/#{data_module.java.package.gsub(".","/")}/dao/SchemaEntityManager.java'),
      ]
    end

    def self.define_jpa_jta_persistence_templates
      [Template.new(JPA::FACETS, :repository, "#{JPA::TEMPLATE_DIRECTORY}/persistence.erb", 'resources/META-INF/persistence.xml')]
    end
  end
end
