module Domgen
  module Generator
    module EE
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ee]
      HELPERS = [Domgen::JPA::Helper, Domgen::Java::Helper, Domgen::JAXB::Helper]
    end

    def self.define_ee_data_types_templates
      [
        Template.new(EE::FACETS,
                     :enumeration,
                     "#{EE::TEMPLATE_DIRECTORY}/enumeration.java.erb",
                     'java/#{enumeration.ee.qualified_name.gsub(".","/")}.java',
                     EE::HELPERS),
        Template.new(EE::FACETS,
                     :exception,
                     "#{EE::TEMPLATE_DIRECTORY}/exception.java.erb",
                     'java/#{exception.ee.qualified_name.gsub(".","/")}.java',
                     EE::HELPERS),
        Template.new(EE::FACETS,
                     :struct,
                     "#{EE::TEMPLATE_DIRECTORY}/struct.java.erb",
                     'java/#{struct.ee.qualified_name.gsub(".","/")}.java',
                     EE::HELPERS),
      ]
    end
  end
end
