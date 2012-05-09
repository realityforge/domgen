module Domgen
  module Generator
    module JPA
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jpa, :sql]
      HELPERS = [Domgen::JPA::Helper, Domgen::Java::Helper, Domgen::JAXB::Helper]
    end
  end
end
Domgen.template_set(:jpa_model => [:ee_data_types]) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :entity,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/entity.java.erb",
                        'main/java/#{entity.jpa.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :entity,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/metamodel.java.erb",
                        'main/java/#{entity.jpa.qualified_metamodel_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
end

Domgen.template_set(:jpa_model_catalog) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :data_module,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/catalog.java.erb",
                        'main/java/#{data_module.jpa.qualified_catalog_name.gsub(".","/")}.java')
end

Domgen.template_set(:jpa_ejb_dao) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :entity,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/ejb.java.erb",
                        'main/java/#{entity.jpa.qualified_dao_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
end

Domgen.template_set(:jpa_persistence_xml) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :repository,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/persistence.xml.erb",
                        'main/resources/META-INF/persistence.xml')
end

Domgen.template_set(:jpa => [:jpa_persistence_xml, :jpa_model])
