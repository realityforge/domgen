module Domgen
  module Generator
    module JPA
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jpa, :sql]
      HELPERS = [Domgen::JPA::Helper, Domgen::Java::Helper, Domgen::JAXB::Helper]
    end
  end
end
Domgen.template_set(:jpa_model) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :entity,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/entity.java.erb",
                        'java/#{entity.jpa.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :entity,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/metamodel.java.erb",
                        'java/#{entity.jpa.qualified_metamodel_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
end

Domgen.template_set(:jpa_model_catalog) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :data_module,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/catalog.java.erb",
                        'java/#{data_module.jpa.qualified_catalog_name.gsub(".","/")}.java')
end

Domgen.template_set(:jpa_ejb) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :entity,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/ejb.java.erb",
                        'java/#{entity.jpa.qualified_dao_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
end

Domgen.template_set(:jpa_persistence) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :repository,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/persistence.xml.erb",
                        'resources/META-INF/persistence.xml')
end
