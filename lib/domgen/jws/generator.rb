module Domgen
  module Generator
    module JWS
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jws]
      HELPERS = [Domgen::Java::Helper]
    end

    def self.define_jws_templates
      [
        Template.new(JWS::FACETS,
                     :service,
                     "#{JWS::TEMPLATE_DIRECTORY}/service.erb",
                     'java/#{service.jws.qualified_service_name.gsub(".","/")}.java',
                     JWS::HELPERS),
      ]
    end
  end
end
