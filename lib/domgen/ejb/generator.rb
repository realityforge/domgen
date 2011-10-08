module Domgen
  module Generator
    module EJB
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ejb]
      HELPERS = [Domgen::Java::Helper]
    end

    def self.define_ejb_templates
      [
        Template.new(EJB::FACETS,
                     :service,
                     "#{EJB::TEMPLATE_DIRECTORY}/interface.erb",
                     'java/#{service.ejb.qualified_service_name.gsub(".","/")}.java',
                     EJB::HELPERS),
        Template.new(EJB::FACETS,
                     :exception,
                     "#{EJB::TEMPLATE_DIRECTORY}/exception.erb",
                     'java/#{exception.ejb.qualified_name.gsub(".","/")}.java',
                     EJB::HELPERS)
      ]
    end
  end
end
