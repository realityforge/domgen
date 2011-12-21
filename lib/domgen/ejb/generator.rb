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
                     "#{EJB::TEMPLATE_DIRECTORY}/facade_service.erb",
                     'java/#{service.ejb.qualified_facade_interface_name.gsub(".","/")}.java',
                     EJB::HELPERS,
                     'service.ejb.generate_facade?'),
        Template.new(EJB::FACETS,
                     :service,
                     "#{EJB::TEMPLATE_DIRECTORY}/remote_service.erb",
                     'java/#{service.ejb.qualified_remote_service_name.gsub(".","/")}.java',
                     EJB::HELPERS,
                     'service.ejb.generate_facade? && service.ejb.remote?'),
        Template.new(EJB::FACETS,
                     :service,
                     "#{EJB::TEMPLATE_DIRECTORY}/facade_implementation.erb",
                     'java/#{service.ejb.qualified_facade_implementation_name.gsub(".","/")}.java',
                     EJB::HELPERS,
                     'service.ejb.generate_facade?'),
      ]
    end
  end
end
