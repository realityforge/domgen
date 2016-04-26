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
      SERVER_HELPERS = [Domgen::JPA::Helper, Domgen::Java::Helper]
      FACETS = [:imit]
      SERVER_FACETS = [:imit, :jpa]
    end
  end
end

Domgen.template_set(:imit_integration_qa) do |template_set|
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/integration_module.java.erb",
                        'main/java/#{repository.imit.qualified_integration_module_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
end

Domgen.template_set(:imit_metadata) do |template_set|
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/shared/graph_enum.java.erb",
                        'main/java/#{repository.imit.qualified_graph_enum_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
end

Domgen.template_set(:imit_client_entity) do |template_set|
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :entity,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/entity.java.erb",
                        'main/java/#{entity.imit.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/mapper.java.erb",
                        'main/java/#{data_module.imit.qualified_mapper_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/model_module.xml.erb",
                        'main/resources/#{repository.imit.model_module.gsub(".","/")}.gwt.xml',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/data_loader_service.java.erb",
                        'main/java/#{repository.imit.qualified_data_loader_service_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/data_loader_service_interface.java.erb",
                        'main/java/#{repository.imit.qualified_data_loader_service_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/session_context.java.erb",
                        'main/java/#{repository.imit.qualified_client_session_context_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/session_interface.java.erb",
                        'main/java/#{repository.imit.qualified_client_session_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/session.java.erb",
                        'main/java/#{repository.imit.qualified_client_session_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/change_mapper.java.erb",
                        'main/java/#{repository.imit.qualified_change_mapper_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/router_impl.java.erb",
                        'main/java/#{repository.imit.qualified_client_router_impl_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/router_interface.java.erb",
                        'main/java/#{repository.imit.qualified_client_router_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/repository_debugger.java.erb",
                        'main/java/#{repository.imit.qualified_repository_debugger_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
end

Domgen.template_set(:imit_client_service) do |template_set|
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :service,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/service.java.erb",
                        'main/java/#{service.imit.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS + [:gwt_rpc],
                        :service,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/proxy.java.erb",
                        'main/java/#{service.imit.qualified_proxy_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS + [:gwt_rpc],
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/services_module.java.erb",
                        'main/java/#{repository.imit.qualified_services_module_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::FACETS,
                        :exception,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/exception.java.erb",
                        'main/java/#{exception.imit.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
end

%w(main test).each do |type|
  Domgen.template_set(:"imit_client_#{type}_qa") do |template_set|
    template_set.template(Domgen::Generator::Imit::FACETS + [:gwt_rpc],
                          :data_module,
                          "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/abstract_test_factory.java.erb",
                          type + '/java/#{data_module.imit.qualified_abstract_test_factory_name.gsub(".","/")}.java',
                          Domgen::Generator::Imit::HELPERS)
    template_set.template(Domgen::Generator::Imit::FACETS + [:gwt_rpc],
                          :repository,
                          "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/test_factory_set.java.erb",
                          type + '/java/#{repository.imit.qualified_test_factory_set_name.gsub(".","/")}.java',
                          Domgen::Generator::Imit::HELPERS)
    template_set.template(Domgen::Generator::Imit::FACETS + [:gwt_rpc],
                          :repository,
                          "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/abstract_client_test.java.erb",
                          type + '/java/#{repository.imit.qualified_abstract_client_test_name.gsub(".","/")}.java',
                          Domgen::Generator::Imit::HELPERS)
    template_set.template(Domgen::Generator::Imit::FACETS + [:gwt_rpc],
                          :repository,
                          "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/mock_services_module.java.erb",
                          type + '/java/#{repository.imit.qualified_mock_services_module_name.gsub(".","/")}.java',
                          Domgen::Generator::Imit::HELPERS)
    template_set.template(Domgen::Generator::Imit::FACETS + [:gwt_rpc],
                          :repository,
                          "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/callback_success_answer.java.erb",
                          type + '/java/#{repository.imit.qualified_callback_success_answer_name.gsub(".","/")}.java',
                          Domgen::Generator::Imit::HELPERS)
    template_set.template(Domgen::Generator::Imit::FACETS + [:gwt_rpc],
                          :repository,
                          "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/client/callback_failure_answer.java.erb",
                          type + '/java/#{repository.imit.qualified_callback_failure_answer_name.gsub(".","/")}.java',
                          Domgen::Generator::Imit::HELPERS)
  end
end

Domgen.template_set(:imit_server_entity_listener) do |template_set|
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/change_listener.java.erb",
                        'main/java/#{repository.imit.qualified_change_listener_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/change_recorder.java.erb",
                        'main/java/#{repository.imit.qualified_change_recorder_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
end

Domgen.template_set(:imit_server_entity_replication) do |template_set|
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/change_recorder_impl.java.erb",
                        'main/java/#{repository.imit.qualified_change_recorder_impl_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/router_interface.java.erb",
                        'main/java/#{repository.imit.qualified_router_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/router_impl.java.erb",
                        'main/java/#{repository.imit.qualified_router_impl_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/message_generator.java.erb",
                        'main/java/#{repository.imit.qualified_message_generator_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/message_generator_interface.java.erb",
                        'main/java/#{repository.imit.qualified_message_generator_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/message_constants.java.erb",
                        'main/java/#{repository.imit.qualified_message_constants_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
end

Domgen.template_set(:imit_server_entity => [:imit_server_entity_listener, :imit_server_entity_replication])

Domgen.template_set(:imit_server_service) do |template_set|
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/jpa_encoder.java.erb",
                        'main/java/#{repository.imit.qualified_jpa_encoder_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/graph_encoder.java.erb",
                        'main/java/#{repository.imit.qualified_graph_encoder_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/graph_encoder_impl.java.erb",
                        'main/java/#{repository.imit.qualified_graph_encoder_impl_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/abstract_session_context_impl.java.erb",
                        'main/java/#{repository.imit.qualified_abstract_session_context_impl_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/replication_interceptor.java.erb",
                        'main/java/#{repository.imit.qualified_replication_interceptor_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/session.java.erb",
                        'main/java/#{repository.imit.qualified_session_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/session_manager.java.erb",
                        'main/java/#{repository.imit.qualified_session_manager_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/session_exception_mapper.java.erb",
                        'main/java/#{repository.imit.qualified_session_exception_mapper_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/session_rest_service.java.erb",
                        'main/java/#{repository.imit.qualified_session_rest_service_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
end

Domgen.template_set(:imit_server_qa) do |template_set|
  template_set.template(Domgen::Generator::Imit::SERVER_FACETS,
                        :repository,
                        "#{Domgen::Generator::Imit::TEMPLATE_DIRECTORY}/server/net_module.java.erb",
                        'test/java/#{repository.imit.qualified_server_net_module_name.gsub(".","/")}.java',
                        Domgen::Generator::Imit::SERVER_HELPERS)
end

Domgen.template_set(:imit_shared => [:imit_metadata])
Domgen.template_set(:imit_server => [:imit_server_service, :imit_server_entity, :imit_server_qa])
Domgen.template_set(:imit_client => [:imit_client_test_qa, :imit_client_service, :imit_client_entity])
Domgen.template_set(:imit => [:imit_client, :imit_server, :imit_shared, :imit_integration_qa])
