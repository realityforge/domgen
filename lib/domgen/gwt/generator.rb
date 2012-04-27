module Domgen
  module Generator
    module GWT
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:gwt]
      HELPERS = [Domgen::Java::Helper]
    end

    def self.define_gwt_shared_service_templates
      [
        Template.new(GWT::FACETS,
                     :service,
                     "#{GWT::TEMPLATE_DIRECTORY}/service.erb",
                     'java/#{service.gwt.qualified_service_name.gsub(".","/")}.java',
                     GWT::HELPERS,
                     'service.gwt?'),
        Template.new(GWT::FACETS,
                     :exception,
                     "#{GWT::TEMPLATE_DIRECTORY}/exception.erb",
                     'java/#{exception.gwt.qualified_name.gsub(".","/")}.java',
                     GWT::HELPERS,
                     'exception.data_module.gwt?'),
        Template.new(GWT::FACETS,
                     :service,
                     "#{GWT::TEMPLATE_DIRECTORY}/async_service.erb",
                     'java/#{service.gwt.qualified_async_service_name.gsub(".","/")}.java',
                     GWT::HELPERS,
                     'service.gwt?')
      ]
    end

    def self.define_gwt_client_service_templates
      [
        Template.new(GWT::FACETS,
                     :repository,
                     "#{GWT::TEMPLATE_DIRECTORY}/gin_module.erb",
                     'java/#{repository.gwt.qualified_gin_module_name.gsub(".","/")}.java',
                     GWT::HELPERS),
        Template.new(GWT::FACETS,
                     :message,
                     "#{GWT::TEMPLATE_DIRECTORY}/event.erb",
                     'java/#{message.gwt.qualified_event_name.gsub(".","/")}.java',
                     GWT::HELPERS,
                     'message.gwt?'),
        Template.new(GWT::FACETS,
                     :message,
                     "#{GWT::TEMPLATE_DIRECTORY}/event_handler.erb",
                     'java/#{message.gwt.qualified_event_handler_name.gsub(".","/")}.java',
                     GWT::HELPERS,
                     'message.gwt?'),
        Template.new(GWT::FACETS,
                     :struct,
                     "#{GWT::TEMPLATE_DIRECTORY}/struct_interface.java.erb",
                     'java/#{struct.gwt.qualified_name.gsub(".","/")}.java',
                     GWT::HELPERS,
                     'struct.gwt?'),
        Template.new(GWT::FACETS,
                     :struct,
                     "#{GWT::TEMPLATE_DIRECTORY}/java_struct.java.erb",
                     'java/#{struct.gwt.qualified_java_name.gsub(".","/")}.java',
                     GWT::HELPERS,
                     'struct.gwt?'),
        Template.new(GWT::FACETS + [:json],
                     :struct,
                     "#{GWT::TEMPLATE_DIRECTORY}/struct_factory.java.erb",
                     'java/#{struct.gwt.qualified_factory_name.gsub(".","/")}.java',
                     GWT::HELPERS,
                     'struct.gwt?'),
        Template.new(GWT::FACETS + [:json],
                     :struct,
                     "#{GWT::TEMPLATE_DIRECTORY}/jso_struct.java.erb",
                     'java/#{struct.gwt.qualified_jso_name.gsub(".","/")}.java',
                     GWT::HELPERS,
                     'struct.gwt?'),
        Template.new(GWT::FACETS,
                     :enumeration,
                     "#{GWT::TEMPLATE_DIRECTORY}/enumeration.erb",
                     'java/#{enumeration.gwt.qualified_name.gsub(".","/")}.java',
                     GWT::HELPERS,
                     'enumeration.data_module.gwt?'),
      ]
    end

    def self.define_gwt_client_service_test_templates
      [
          Template.new(GWT::FACETS,
                       :repository,
                       "#{GWT::TEMPLATE_DIRECTORY}/mock_services_module.erb",
                       'test/#{repository.gwt.qualified_mock_services_module_name.gsub(".","/")}.java',
                       GWT::HELPERS),
      ]
    end

    def self.define_gwt_server_service_templates
      [
        Template.new(GWT::FACETS + [:ejb],
                     :service,
                     "#{GWT::TEMPLATE_DIRECTORY}/servlet.erb",
                     'java/#{service.gwt.qualified_servlet_name.gsub(".","/")}.java',
                     GWT::HELPERS,
                     'service.gwt?'),
      ]
    end
  end
end
