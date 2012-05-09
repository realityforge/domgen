module Domgen
  module Generator
    module JMX
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jmx]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end
Domgen.template_set(:jmx) do |template_set|
  template_set.template(Domgen::Generator::JMX::FACETS,
                        :service,
                        "#{Domgen::Generator::JMX::TEMPLATE_DIRECTORY}/service.java.erb",
                        'main/java/#{service.jmx.qualified_service_name.gsub(".","/")}.java',
                        Domgen::Generator::JMX::HELPERS)
end
