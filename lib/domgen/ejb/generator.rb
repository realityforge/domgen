module Domgen
  module Generator
    module EJB
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ejb]
    end

    def self.define_ejb_templates
      [
        Template.new(EJB::FACETS,
                     :service,
                     "#{EJB::TEMPLATE_DIRECTORY}/interface.erb",
                     'java/#{service.ejb.qualified_service_name.gsub(".","/")}.java',
                     [Domgen::Java::Helper])
      ]
    end
  end
end
