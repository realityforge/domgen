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
                     :enumeration,
                     "#{Imit::TEMPLATE_DIRECTORY}/enumeration.erb",
                     'java/#{enumeration.imit.qualified_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'enumeration.data_module.imit?'),
        Template.new(Imit::FACETS,
                     :entity,
                     "#{Imit::TEMPLATE_DIRECTORY}/entity.erb",
                     'java/#{entity.imit.qualified_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'entity.imit?'),
        Template.new(Imit::FACETS,
                     :data_module,
                     "#{Imit::TEMPLATE_DIRECTORY}/mapper.erb",
                     'java/#{data_module.imit.qualified_mapper_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'data_module.imit?'),
        Template.new(Imit::FACETS,
                     :struct,
                     "#{Imit::TEMPLATE_DIRECTORY}/struct_interface.java.erb",
                     'java/#{struct.imit.qualified_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'struct.imit?'),
        Template.new(Imit::FACETS,
                     :struct,
                     "#{Imit::TEMPLATE_DIRECTORY}/java_struct.java.erb",
                     'java/#{struct.imit.qualified_java_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'struct.imit?'),
      ]
    end

    def self.define_imit_json_templates
      [
        Template.new(Imit::FACETS,
                     :struct,
                     "#{Imit::TEMPLATE_DIRECTORY}/struct_factory.java.erb",
                     'java/#{struct.imit.qualified_factory_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'struct.imit?'),
        Template.new(Imit::FACETS,
                     :struct,
                     "#{Imit::TEMPLATE_DIRECTORY}/jso_struct.java.erb",
                     'java/#{struct.imit.qualified_jso_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'struct.imit?'),
        Template.new(Imit::FACETS,
                     :repository,
                     "#{Imit::TEMPLATE_DIRECTORY}/change_mapper.erb",
                     'java/#{repository.imit.qualified_change_mapper_name.gsub(".","/")}.java',
                     Imit::HELPERS),
      ]
    end

    def self.define_imit_gwt_proxy_templates
      [
        Template.new(Imit::FACETS,
                     :service,
                     "#{Imit::TEMPLATE_DIRECTORY}/service.erb",
                     'java/#{service.imit.qualified_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'service.imit?'),
        Template.new(Imit::FACETS + [:gwt],
                     :service,
                     "#{Imit::TEMPLATE_DIRECTORY}/proxy.erb",
                     'java/#{service.imit.qualified_proxy_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'service.imit? && service.gwt?'),
          Template.new(Imit::FACETS + [:gwt],
                       :repository,
                       "#{Imit::TEMPLATE_DIRECTORY}/services_module.erb",
                       'java/#{repository.imit.qualified_services_module_name.gsub(".","/")}.java',
                       [Domgen::Java::Helper]),
        Template.new(Imit::FACETS,
                     :exception,
                     "#{Imit::TEMPLATE_DIRECTORY}/exception.erb",
                     'java/#{exception.imit.qualified_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'exception.data_module.imit?'),
      ]
    end

    def self.define_imit_gwt_proxy_service_test_templates
      [
          Template.new(Imit::FACETS + [:gwt],
                       :repository,
                       "#{Imit::TEMPLATE_DIRECTORY}/mock_services_module.erb",
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
                     "#{Imit::TEMPLATE_DIRECTORY}/jpa_encoder.erb",
                     'java/#{data_module.imit.qualified_jpa_encoder_name.gsub(".","/")}.java',
                     helpers,
                     'data_module.imit?'),
        Template.new(facets,
                     :data_module,
                     "#{Imit::TEMPLATE_DIRECTORY}/router_interface.erb",
                     'java/#{data_module.imit.qualified_router_interface_name.gsub(".","/")}.java',
                     helpers,
                     'data_module.imit?'),
        Template.new(facets,
                     :repository,
                     "#{Imit::TEMPLATE_DIRECTORY}/message_generator.erb",
                     'java/#{repository.imit.qualified_message_generator_name.gsub(".","/")}.java',
                     helpers),
      ]
    end
  end
end
