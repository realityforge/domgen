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
                     "#{Imit::TEMPLATE_DIRECTORY}/enum.erb",
                     'java/#{enumeration.imit.qualified_enumeration_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'enumeration.data_module.imit.client_side?'),
        Template.new(Imit::FACETS,
                     :data_module,
                     "#{Imit::TEMPLATE_DIRECTORY}/updater.erb",
                     'java/#{data_module.imit.qualified_updater_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'data_module.imit.client_side?'),
        Template.new(Imit::FACETS,
                     :entity,
                     "#{Imit::TEMPLATE_DIRECTORY}/imitation.erb",
                     'java/#{entity.imit.qualified_imitation_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'entity.imit.client_side?'),
      ]
    end

    def self.define_imit_json_templates
      [
        Template.new(Imit::FACETS,
                     :data_module,
                     "#{Imit::TEMPLATE_DIRECTORY}/json_mapper.erb",
                     'java/#{data_module.imit.qualified_json_mapper_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'data_module.imit.client_side?'),
        Template.new(Imit::FACETS,
                     :repository,
                     "#{Imit::TEMPLATE_DIRECTORY}/repository_json_mapper.erb",
                     'java/#{repository.imit.qualified_json_mapper_name.gsub(".","/")}.java',
                     Imit::HELPERS),
      ]
    end

    def self.define_imit_rpc_templates
      [
        Template.new(Imit::FACETS,
                     :data_module,
                     "#{Imit::TEMPLATE_DIRECTORY}/rpc_mapper.erb",
                     'java/#{data_module.imit.qualified_rpc_mapper_name.gsub(".","/")}.java',
                     Imit::HELPERS,
                     'data_module.imit.client_side?'),
        Template.new(Imit::FACETS,
                     :repository,
                     "#{Imit::TEMPLATE_DIRECTORY}/repository_rpc_mapper.erb",
                     'java/#{repository.imit.qualified_rpc_mapper_name.gsub(".","/")}.java',
                     Imit::HELPERS),
      ]
    end
  end
end
