module Domgen
  module Generator
    module EJB
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ejb]
      HELPERS = [Domgen::Java::Helper, Domgen::JAXB::Helper]
    end
  end
end
Domgen.template_set(:ejb) do |template_set|
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/service.java.erb",
                        'java/#{service.ejb.qualified_service_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS)
end
Domgen.template_set(:ejb_facades) do |template_set|
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/boundary_service.java.erb",
                        'java/#{service.ejb.qualified_boundary_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        'service.ejb.generate_boundary?')
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/remote_service.java.erb",
                        'java/#{service.ejb.qualified_remote_service_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        'service.ejb.generate_boundary? && service.ejb.remote?')
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/boundary_implementation.java.erb",
                        'java/#{service.ejb.qualified_boundary_implementation_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        'service.ejb.generate_boundary?')
end