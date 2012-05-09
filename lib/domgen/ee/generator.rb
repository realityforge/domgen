module Domgen
  module Generator
    module EE
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ee]
      HELPERS = [Domgen::JPA::Helper, Domgen::Java::Helper, Domgen::JAXB::Helper, Domgen::Jackson::Helper]
    end
  end
end

Domgen.template_set(:ee_data_types) do |template_set|
  template_set.template(Domgen::Generator::EE::FACETS,
                        :enumeration,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/enumeration.java.erb",
                        'java/#{enumeration.ee.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS)
  template_set.template(Domgen::Generator::EE::FACETS,
                        :exception,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/exception.java.erb",
                        'java/#{exception.ee.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS)
  template_set.template(Domgen::Generator::EE::FACETS,
                        :struct,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/struct.java.erb",
                        'java/#{struct.ee.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS)
end
