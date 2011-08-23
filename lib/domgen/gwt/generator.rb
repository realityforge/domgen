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
  end
end
