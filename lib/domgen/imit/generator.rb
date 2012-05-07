module Domgen
  module Generator
    module Imit
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      HELPERS = [Domgen::Java::Helper]
      FACETS = [:imit]
    end

    def self.define_imit_templates
      [
        Template.new(Imit::FACETS,
                     :entity,
                     "#{Imit::TEMPLATE_DIRECTORY}/entity.java.erb",
                     'java/#{entity.imit.qualified_name.gsub(".","/")}.java',
                     Imit::HELPERS),
        Template.new(Imit::FACETS,
                     :data_module,
                     "#{Imit::TEMPLATE_DIRECTORY}/mapper.java.erb",
                     'java/#{data_module.imit.qualified_mapper_name.gsub(".","/")}.java',
                     Imit::HELPERS),
      ]
    end

    def self.define_imit_json_templates
      [
        Template.new(Imit::FACETS,
                     :repository,
                     "#{Imit::TEMPLATE_DIRECTORY}/change_mapper.java.erb",
                     'java/#{repository.imit.qualified_change_mapper_name.gsub(".","/")}.java',
                     Imit::HELPERS),
      ]
    end

    def self.define_imit_gwt_proxy_templates
      [
        Template.new(Imit::FACETS,
                     :service,
                     "#{Imit::TEMPLATE_DIRECTORY}/service.java.erb",
                     'java/#{service.imit.qualified_name.gsub(".","/")}.java',
                     Imit::HELPERS),
        Template.new(Imit::FACETS + [:gwt],
                     :service,
                     "#{Imit::TEMPLATE_DIRECTORY}/proxy.java.erb",
                     'java/#{service.imit.qualified_proxy_name.gsub(".","/")}.java',
                     Imit::HELPERS),
          Template.new(Imit::FACETS + [:gwt],
                       :repository,
                       "#{Imit::TEMPLATE_DIRECTORY}/services_module.java.erb",
                       'java/#{repository.imit.qualified_services_module_name.gsub(".","/")}.java',
                       [Domgen::Java::Helper]),
        Template.new(Imit::FACETS,
                     :exception,
                     "#{Imit::TEMPLATE_DIRECTORY}/exception.java.erb",
                     'java/#{exception.imit.qualified_name.gsub(".","/")}.java',
                     Imit::HELPERS),
      ]
    end

    def self.define_imit_gwt_proxy_service_test_templates
      [
          Template.new(Imit::FACETS + [:gwt],
                       :repository,
                       "#{Imit::TEMPLATE_DIRECTORY}/mock_services_module.java.erb",
                       'test/#{repository.imit.qualified_mock_services_module_name.gsub(".","/")}.java',
                       [Domgen::Java::Helper]),
      ]
    end

    def self.define_imit_jpa_templates
      facets = Imit::FACETS + [:jpa]
      helpers = Imit::HELPERS + [Domgen::JPA::Helper, Domgen::Java::Helper]
      [
        Template.new(facets,
                     :data_module,
                     "#{Imit::TEMPLATE_DIRECTORY}/jpa_encoder.java.erb",
                     'java/#{data_module.imit.qualified_jpa_encoder_name.gsub(".","/")}.java',
                     helpers),
        Template.new(facets,
                     :data_module,
                     "#{Imit::TEMPLATE_DIRECTORY}/router_interface.java.erb",
                     'java/#{data_module.imit.qualified_router_interface_name.gsub(".","/")}.java',
                     helpers),
        Template.new(facets,
                     :repository,
                     "#{Imit::TEMPLATE_DIRECTORY}/message_generator.java.erb",
                     'java/#{repository.imit.qualified_message_generator_name.gsub(".","/")}.java',
                     helpers),
      ]
    end
  end
end
