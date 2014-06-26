#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Domgen
  module Generator
    module Imit
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      HELPERS = [Domgen::Java::Helper]
      FACETS = [:imit]
    end
  end
end
Domgen.template_set(:imit_metadata) do |template_set|
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/graph_enum.java.erb",
                        'main/java/#{repository.imit.qualified_graph_enum_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
end

Domgen.template_set(:imit_entity) do |template_set|
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :entity,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/entity.java.erb",
                        'main/java/#{entity.imit.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/mapper.java.erb",
                        'main/java/#{data_module.imit.qualified_mapper_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/data_loader_service.java.erb",
                        'main/java/#{repository.imit.qualified_data_loader_service_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client_session_interface.java.erb",
                        'main/java/#{repository.imit.qualified_client_session_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client_session.java.erb",
                        'main/java/#{repository.imit.qualified_client_session_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/change_mapper.java.erb",
                        'main/java/#{repository.imit.qualified_change_mapper_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client_router_impl.java.erb",
                        'main/java/#{repository.imit.qualified_client_router_impl_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS + [Domgen::JPA::Helper, Domgen::Java::Helper])
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client_router_interface.java.erb",
                        'main/java/#{repository.imit.qualified_client_router_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/repository_debugger.java.erb",
                        'main/java/#{repository.imit.qualified_repository_debugger_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
end

Domgen.template_set(:imit_gwt_proxy) do |template_set|
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :service,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/service.java.erb",
                        'main/java/#{service.imit.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS + [:gwt_rpc],
                        :service,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/proxy.java.erb",
                        'main/java/#{service.imit.qualified_proxy_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS + [:gwt_rpc],
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/services_module.java.erb",
                        'main/java/#{repository.imit.qualified_services_module_name.gsub(".","/")}.java',
                        [Domgen::Java::Helper])
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :exception,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/exception.java.erb",
                        'main/java/#{exception.imit.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
end
Domgen.template_set(:imit_gwt_proxy_service_test) do |template_set|
  template_set.template(Domgen::Generator::Imit::FACETS + [:gwt_rpc],
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/mock_services_module.java.erb",
                        'test/java/#{repository.imit.qualified_mock_services_module_name.gsub(".","/")}.java',
                        [Domgen::Java::Helper])
end

Domgen.template_set(:imit_jpa) do |template_set|
  facets = Domgen::Generator::Imit::FACETS + [:jpa]
  helpers = Domgen::Generator::Imit::HELPERS + [Domgen::JPA::Helper, Domgen::Java::Helper]
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/jpa_encoder.java.erb",
                        'main/java/#{repository.imit.qualified_jpa_encoder_name.gsub(".","/")}.java',
                        helpers)
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/graph_encoder.java.erb",
                        'main/java/#{repository.imit.qualified_graph_encoder_name.gsub(".","/")}.java',
                        helpers)
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/graph_encoder_impl.java.erb",
                        'main/java/#{repository.imit.qualified_graph_encoder_impl_name.gsub(".","/")}.java',
                        helpers)
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/change_recorder.java.erb",
                        'main/java/#{repository.imit.qualified_change_recorder_name.gsub(".","/")}.java',
                        helpers)
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server_session_context.java.erb",
                        'main/java/#{repository.imit.qualified_server_session_context_name.gsub(".","/")}.java',
                        helpers)
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/replication_interceptor.java.erb",
                        'main/java/#{repository.imit.qualified_replication_interceptor_name.gsub(".","/")}.java',
                        helpers)
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/session.java.erb",
                        'main/java/#{repository.imit.qualified_session_name.gsub(".","/")}.java',
                        helpers)
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/session_manager.java.erb",
                        'main/java/#{repository.imit.qualified_session_manager_name.gsub(".","/")}.java',
                        helpers)
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/router_interface.java.erb",
                        'main/java/#{repository.imit.qualified_router_interface_name.gsub(".","/")}.java',
                        helpers)
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/router_impl.java.erb",
                        'main/java/#{repository.imit.qualified_router_impl_name.gsub(".","/")}.java',
                        helpers)
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/message_generator.java.erb",
                        'main/java/#{repository.imit.qualified_message_generator_name.gsub(".","/")}.java',
                        helpers)
  template_set.template(facets,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/message_constants.java.erb",
                        'main/java/#{repository.imit.qualified_message_constants_name.gsub(".","/")}.java',
                        helpers)
end

Domgen.template_set(:imit_shared => [:imit_metadata])
Domgen.template_set(:imit_server => [:imit_jpa])
Domgen.template_set(:imit_client => [:imit_gwt_proxy_service_test, :imit_gwt_proxy, :imit_entity])
Domgen.template_set(:imit => [:imit_client, :imit_server, :imit_shared])
