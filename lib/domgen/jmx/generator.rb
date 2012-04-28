module Domgen
  module Generator
    module JMX
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jmx]
      HELPERS = [Domgen::Java::Helper]
    end

    def self.define_jmx_templates
      [
        Template.new(JMX::FACETS,
                     :service,
                     "#{JMX::TEMPLATE_DIRECTORY}/service.java.erb",
                     'java/#{service.jmx.qualified_service_name.gsub(".","/")}.java',
                     JMX::HELPERS),
      ]
    end
  end
end
