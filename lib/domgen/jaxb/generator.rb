module Domgen
  module Generator
    module JAXB
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jaxb]
      HELPERS = [Domgen::Java::Helper, Domgen::JAXB::Helper]
    end

    def self.define_jaxb_model_templates
      [
        Template.new(JAXB::FACETS,
                     :struct,
                     "#{JAXB::TEMPLATE_DIRECTORY}/struct.erb",
                     'java/#{struct.jaxb.qualified_name.gsub(".","/")}.java',
                     JAXB::HELPERS),
      ]
    end
  end
end
