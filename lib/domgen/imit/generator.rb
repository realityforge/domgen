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

Domgen::Generator.define([:imit],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper, Domgen::Imit::Helper]) do |g|
  g.template_set(:imit_metadata) do |template_set|
    template_set.erb_template(:repository,
                              'shared/system_constants.java.erb',
                              'main/java/#{repository.imit.qualified_system_constants_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'shared/subscription_constants.java.erb',
                              'main/java/#{repository.imit.qualified_subscription_constants_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'shared/entity_type_constants.java.erb',
                              'main/java/#{repository.imit.qualified_entity_type_constants_name.gsub(".","/")}.java')
  end

  g.template_set(:imit_client_entity) do |template_set|
    template_set.erb_template(:repository,
                              'client/schema_factory.java.erb',
                              'main/java/#{repository.imit.qualified_schema_factory_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'client/schema_dagger_module.java.erb',
                              'main/java/#{repository.imit.qualified_schema_dagger_module_name.gsub(".","/")}.java')
    template_set.erb_template(:data_module,
                              'client/mapper.java.erb',
                              'main/java/#{data_module.imit.qualified_mapper_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'client/router_impl.java.erb',
                              'main/java/#{repository.imit.qualified_client_router_impl_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'client/router_interface.java.erb',
                              'main/java/#{repository.imit.qualified_client_router_interface_name.gsub(".","/")}.java')
  end

  g.template_set(:imit_client_react4j_support) do |template_set|
    template_set.erb_template('imit.graph',
                              'client/gwt/react_subscription_component.java.erb',
                              'main/java/#{graph.qualified_react4j_subscription_component_name.gsub(".","/")}.java',
                              :additional_facets => [:react4j],
                              :guard => 'graph.external_visibility?')
  end

  g.template_set(:imit_client_entity_gwt) do |template_set|
    template_set.erb_template(:repository,
                              'client/gwt/session_context.java.erb',
                              'main/java/#{repository.imit.qualified_gwt_client_session_context_name.gsub(".","/")}.java')
  end

  g.template_set(:imit_client_service) do |template_set|
    template_set.erb_template(:service,
                              'client/service.java.erb',
                              'main/java/#{service.imit.qualified_name.gsub(".","/")}.java')
    template_set.erb_template(:service,
                              'client/proxy.java.erb',
                              'main/java/#{service.imit.qualified_proxy_name.gsub(".","/")}.java',
                              :additional_facets => [:gwt_rpc])
    template_set.erb_template(:repository,
                              'client/gwt/services_dagger_module.java.erb',
                              'main/java/#{repository.imit.qualified_services_dagger_module_name.gsub(".","/")}.java',
                              :additional_facets => [:gwt_rpc])
    template_set.erb_template(:exception,
                              'client/exception.java.erb',
                              'main/java/#{exception.imit.qualified_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'client/gwt/rpc_request_builder.java.erb',
                              'main/java/#{repository.imit.qualified_rpc_request_builder_name.gsub(".","/")}.java')
  end

  %w(main test).each do |type|
    g.template_set(:"imit_server_#{type}_qa") do |template_set|
      template_set.erb_template(:repository,
                                'server/integration_module.java.erb',
                                type + '/java/#{repository.imit.qualified_integration_module_name.gsub(".","/")}.java',
                                :guard => 'repository.imit.include_standard_integration_test_module?')
    end
    g.template_set(:"imit_client_#{type}_qa_external") do |template_set|
      template_set.erb_template(:repository,
                                'client/abstract_client_test.java.erb',
                                type + '/java/#{repository.imit.qualified_abstract_client_test_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'client/abstract_schema_test.java.erb',
                                type + '/java/#{repository.imit.qualified_abstract_schema_test_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'client/client_test.java.erb',
                                type + '/java/#{repository.imit.qualified_client_test_name.gsub(".","/")}.java',
                                :guard => '!repository.imit.custom_base_client_test?')
    end

    g.template_set(:"imit_client_#{type}_gwt_qa_external") do |template_set|
      template_set.erb_template(:repository,
                                'client/gwt/gwt_complete_module.java.erb',
                                type + '/java/#{repository.imit.qualified_gwt_complete_module_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'client/mock_services_module.java.erb',
                                type + '/java/#{repository.imit.qualified_mock_services_module_name.gsub(".","/")}.java',
                                :additional_facets => [:gwt_rpc])
      template_set.erb_template(:repository,
                                'client/support_test_module.java.erb',
                                type + '/java/#{repository.imit.qualified_support_test_module_name.gsub(".","/")}.java')
    end
  end
end

Domgen::Generator.define([:imit, :jpa],
                         "#{File.dirname(__FILE__)}/templates/server",
                         [Domgen::JPA::Helper, Domgen::Java::Helper]) do |g|

  g.template_set(:imit_server_entity_listener) do |template_set|
    template_set.erb_template(:repository,
                              'change_listener.java.erb',
                              'main/java/#{repository.imit.qualified_change_listener_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'change_recorder.java.erb',
                              'main/java/#{repository.imit.qualified_change_recorder_name.gsub(".","/")}.java')
  end

  g.template_set(:imit_server_entity_replication) do |template_set|
    template_set.erb_template(:repository,
                              'change_recorder_impl.java.erb',
                              'main/java/#{repository.imit.qualified_change_recorder_impl_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'router_interface.java.erb',
                              'main/java/#{repository.imit.qualified_router_interface_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'router_impl.java.erb',
                              'main/java/#{repository.imit.qualified_router_impl_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'message_generator.java.erb',
                              'main/java/#{repository.imit.qualified_message_generator_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'message_generator_interface.java.erb',
                              'main/java/#{repository.imit.qualified_message_generator_interface_name.gsub(".","/")}.java')
  end

  g.template_set(:imit_server_entity => [:imit_server_entity_listener, :imit_server_entity_replication])

  g.template_set(:imit_server_service) do |template_set|
    template_set.erb_template(:repository,
                              'jpa_encoder.java.erb',
                              'main/java/#{repository.imit.qualified_jpa_encoder_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'graph_encoder.java.erb',
                              'main/java/#{repository.imit.qualified_graph_encoder_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'graph_encoder_impl.java.erb',
                              'main/java/#{repository.imit.qualified_graph_encoder_impl_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'abstract_session_context_impl.java.erb',
                              'main/java/#{repository.imit.qualified_abstract_session_context_impl_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'replication_interceptor.java.erb',
                              'main/java/#{repository.imit.qualified_replication_interceptor_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'poll_service.java.erb',
                              'main/java/#{repository.imit.qualified_poll_service_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'system_metadata.java.erb',
                              'main/java/#{repository.imit.qualified_system_metadata_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'session_manager.java.erb',
                              'main/java/#{repository.imit.qualified_session_manager_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'session_rest_service.java.erb',
                              'main/java/#{repository.imit.qualified_session_rest_service_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'poll_rest_service.java.erb',
                              'main/java/#{repository.imit.qualified_poll_rest_service_name.gsub(".","/")}.java')
    template_set.erb_template('imit.remote_datasource',
                              'ee_data_loader_service_implementation.java.erb',
                              'main/java/#{remote_datasource.qualified_ee_data_loader_service_implementation_name.gsub(".","/")}.java')
    template_set.erb_template('imit.remote_datasource',
                              'ee_data_loader_rest_service.java.erb',
                              'main/java/#{remote_datasource.qualified_ee_data_loader_rest_service_name.gsub(".","/")}.java')
  end

  g.template_set(:imit_server_qa) do |template_set|
    template_set.erb_template(:repository,
                              'net_module.java.erb',
                              'test/java/#{repository.imit.qualified_server_net_module_name.gsub(".","/")}.java')
  end

  g.template_set(:imit_shared => [:imit_metadata])
  g.template_set(:imit_server => [:imit_server_service, :imit_server_entity, :imit_server_qa])
  g.template_set(:imit_client => [:imit_client_service, :imit_client_entity, :imit_client_entity_gwt])
  g.template_set(:imit => [:imit_client, :imit_server, :imit_shared, :imit_server_test_qa])
end
