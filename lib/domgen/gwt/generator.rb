module Domgen
  module Generator
    module GWT
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:gwt, :java]
    end

    def self.define_gwt_shared_service_templates
      [
        Template.new(GWT::FACETS,
                     :service,
                     "#{GWT::TEMPLATE_DIRECTORY}/service.erb",
                     'java/#{service.gwt.qualified_service_name.gsub(".","/")}.java',
                     [Domgen::Java::Helper]),
      Template.new(GWT::FACETS,
                   :service,
                   "#{GWT::TEMPLATE_DIRECTORY}/async_service.erb",
                   'java/#{service.gwt.qualified_async_service_name.gsub(".","/")}.java',
                   [Domgen::Java::Helper])
      ]
    end

    def self.define_gwt_client_service_templates
      [
        Template.new(GWT::FACETS,
                     :repository,
                     "#{GWT::TEMPLATE_DIRECTORY}/gin_module.erb",
                     'java/#{repository.gwt.qualified_gin_module_name.gsub(".","/")}.java',
                     [Domgen::Java::Helper]),
        Template.new(GWT::FACETS,
                     :message,
                     "#{GWT::TEMPLATE_DIRECTORY}/event.erb",
                     'java/#{message.gwt.qualified_event_name.gsub(".","/")}.java',
                     [Domgen::Java::Helper]),
        Template.new(GWT::FACETS,
                     :message,
                     "#{GWT::TEMPLATE_DIRECTORY}/event_handler.erb",
                     'java/#{message.gwt.qualified_event_handler_name.gsub(".","/")}.java',
                     [Domgen::Java::Helper]),
      ]
    end

    def self.define_gwt_server_service_templates
      [
        Template.new(GWT::FACETS,
                     :service,
                     "#{GWT::TEMPLATE_DIRECTORY}/servlet.erb",
                     'java/#{service.gwt.qualified_servlet_name.gsub(".","/")}.java',
                     [Domgen::Java::Helper]),
      ]
    end
  end
end
