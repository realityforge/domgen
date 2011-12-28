module Domgen
  module Generator
    module JPA
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jpa, :sql]
      HELPERS = [Domgen::JPA::Helper, Domgen::Java::Helper, Domgen::JAXB::Helper]
    end

    def self.define_jpa_model_templates
      [
        Template.new(JPA::FACETS,
                     :entity,
                     "#{JPA::TEMPLATE_DIRECTORY}/entity.erb",
                     'java/#{entity.jpa.qualified_name.gsub(".","/")}.java',
                     JPA::HELPERS,
                     'entity.jpa?'),
        Template.new(JPA::FACETS,
                     :entity,
                     "#{JPA::TEMPLATE_DIRECTORY}/metamodel.erb",
                     'java/#{entity.jpa.qualified_metamodel_name.gsub(".","/")}.java',
                     JPA::HELPERS,
                     'entity.jpa?'),
      ]
    end

    def self.define_jpa_model_catalog_templates
      [
        Template.new(JPA::FACETS,
                     :data_module,
                     "#{JPA::TEMPLATE_DIRECTORY}/catalog.erb",
                     'java/#{data_module.jpa.qualified_catalog_name.gsub(".","/")}.java'),
      ]
    end

    def self.define_jpa_ejb_templates
      [
        Template.new(JPA::FACETS,
                     :entity,
                     "#{JPA::TEMPLATE_DIRECTORY}/ejb.erb",
                     'java/#{entity.jpa.qualified_dao_name.gsub(".","/")}.java',
                     JPA::HELPERS,
                     'entity.jpa?')
      ]
    end

    def self.define_jpa_persistence_templates
      [
        Template.new(JPA::FACETS,
                     :repository,
                     "#{JPA::TEMPLATE_DIRECTORY}/persistence.xml.erb",
                     'resources/META-INF/persistence.xml')
      ]
    end
  end
end
