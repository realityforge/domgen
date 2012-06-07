module Domgen
  module Generator
    module AutoBean
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:auto_bean]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end

Domgen.template_set(:auto_bean) do |template_set|
  template_set.template(Domgen::Generator::AutoBean::FACETS,
                        :enumeration,
                        "#{Domgen::Generator::AutoBean::TEMPLATE_DIRECTORY}/enumeration.java.erb",
                        'main/java/#{enumeration.auto_bean.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::AutoBean::HELPERS)
  template_set.template(Domgen::Generator::AutoBean::FACETS,
                        :struct,
                        "#{Domgen::Generator::AutoBean::TEMPLATE_DIRECTORY}/struct.java.erb",
                        'main/java/#{struct.auto_bean.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::AutoBean::HELPERS)
end
