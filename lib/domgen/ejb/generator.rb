module Domgen
  module Generator
    module EJB
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ejb]
      HELPERS = [Domgen::Java::Helper, Domgen::JAXB::Helper]
    end
  end
end
Domgen.template_set(:ejb_services => [:ee_exceptions]) do |template_set|
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/service.java.erb",
                        'main/java/#{service.ejb.qualified_service_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS)
end
Domgen.template_set(:ejb_service_facades => [:ejb_services]) do |template_set|
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/boundary_service.java.erb",
                        'main/java/#{service.ejb.qualified_boundary_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        'service.ejb.generate_boundary?')
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/remote_service.java.erb",
                        'main/java/#{service.ejb.qualified_remote_service_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        'service.ejb.generate_boundary? && service.ejb.remote?')
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/boundary_implementation.java.erb",
                        'main/java/#{service.ejb.qualified_boundary_implementation_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        'service.ejb.generate_boundary?')
end

Domgen.template_set(:ejb => [:ejb_service_facades, :jpa_ejb_dao])
