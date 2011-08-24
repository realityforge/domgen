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
                     'java/#{object_type.jpa.qualified_entity_name.gsub(".","/")}.java',
                     [Domgen::JPA::Helper, Domgen::Java::Helper],
                     'object_type.jpa.persistent?'),
        Template.new(JPA::FACETS,
                     :object_type,
                     "#{JPA::TEMPLATE_DIRECTORY}/metamodel.erb",
                     'java/#{object_type.jpa.qualified_metamodel_name.gsub(".","/")}.java',
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
  end
end
