module Domgen
  module Generator
    module GWT
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:gwt]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end
Domgen.template_set(:gwt_shared_service) do |template_set|
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :service,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/rpc_service.java.erb",
                        'main/java/#{service.gwt.qualified_service_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :exception,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/exception.java.erb",
                        'main/java/#{exception.gwt.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :service,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/async_rpc_service.java.erb",
                        'main/java/#{service.gwt.qualified_async_rpc_service_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
end

Domgen.template_set(:gwt_client_service) do |template_set|
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :repository,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/rpc_services_module.java.erb",
                        'main/java/#{repository.gwt.qualified_rpc_services_module_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :message,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/event.java.erb",
                        'main/java/#{message.gwt.qualified_event_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :message,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/event_handler.java.erb",
                        'main/java/#{message.gwt.qualified_event_handler_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :struct,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/struct_interface.java.erb",
                        'main/java/#{struct.gwt.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :struct,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/java_struct.java.erb",
                        'main/java/#{struct.gwt.qualified_java_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS + [:json],
                        :struct,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/struct_factory.java.erb",
                        'main/java/#{struct.gwt.qualified_factory_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS + [:json],
                        :struct,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/jso_struct.java.erb",
                        'main/java/#{struct.gwt.qualified_jso_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :enumeration,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/enumeration.java.erb",
                        'main/java/#{enumeration.gwt.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :service,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/facade_service.java.erb",
                        'main/java/#{service.gwt.qualified_facade_service_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :service,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/proxy.java.erb",
                        'main/java/#{service.gwt.qualified_proxy_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :repository,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/services_module.java.erb",
                        'main/java/#{repository.gwt.qualified_services_module_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
end
Domgen.template_set(:gwt_client_service_test) do |template_set|
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :repository,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/mock_services_module.java.erb",
                        'test/java/#{repository.gwt.qualified_mock_services_module_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
end

Domgen.template_set(:gwt_server_service) do |template_set|
  template_set.template(Domgen::Generator::GWT::FACETS + [:ejb],
                        :service,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/servlet.java.erb",
                        'main/java/#{service.gwt.qualified_servlet_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
end

Domgen.template_set(:gwt_shared => [:gwt_shared_service])
Domgen.template_set(:gwt_client => [:gwt_client_service, :gwt_client_service_test])
Domgen.template_set(:gwt_server => [:gwt_server_service])
Domgen.template_set(:gwt => [:gwt_shared, :gwt_client, :gwt_server])
