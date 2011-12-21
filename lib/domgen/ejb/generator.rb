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
                     "#{EJB::TEMPLATE_DIRECTORY}/service.erb",
                     'java/#{service.ejb.qualified_service_name.gsub(".","/")}.java',
                     EJB::HELPERS),
        Template.new(EJB::FACETS,
                     :exception,
                     "#{EJB::TEMPLATE_DIRECTORY}/exception.erb",
                     'java/#{exception.ejb.qualified_name.gsub(".","/")}.java',
                     EJB::HELPERS)
      ]
    end

    def self.define_ejb_facades_templates
      [
        Template.new(EJB::FACETS,
                     :service,
                     "#{EJB::TEMPLATE_DIRECTORY}/boundary_service.erb",
                     'java/#{service.ejb.qualified_boundary_interface_name.gsub(".","/")}.java',
                     EJB::HELPERS,
                     'service.ejb.generate_boundary?'),
        Template.new(EJB::FACETS,
                     :service,
                     "#{EJB::TEMPLATE_DIRECTORY}/remote_service.erb",
                     'java/#{service.ejb.qualified_remote_service_name.gsub(".","/")}.java',
                     EJB::HELPERS,
                     'service.ejb.generate_boundary? && service.ejb.remote?'),
        Template.new(EJB::FACETS,
                     :service,
                     "#{EJB::TEMPLATE_DIRECTORY}/boundary_implementation.erb",
                     'java/#{service.ejb.qualified_boundary_implementation_name.gsub(".","/")}.java',
                     EJB::HELPERS,
                     'service.ejb.generate_boundary?'),
      ]
    end
  end
end
