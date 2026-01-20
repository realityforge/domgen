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
                              'client/schema_sting_fragment.java.erb',
                              'main/java/#{repository.imit.qualified_schema_sting_fragment_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'client/schema_filter_tools.java.erb',
                              'main/java/#{repository.imit.qualified_schema_filter_tools_name.gsub(".","/")}.java',
                              :guard => 'repository.imit.graphs.any?{|g| g.filter_parameter? && !g.filter_parameter.immutable?}')
    template_set.erb_template(:data_module,
                              'client/mapper.java.erb',
                              'main/java/#{data_module.imit.qualified_mapper_name.gsub(".","/")}.java',
                              :guard => 'data_module.arez.factory_required?')
    template_set.erb_template(:repository,
                              'client/router.java.erb',
                              'main/java/#{repository.imit.qualified_client_router_name.gsub(".","/")}.java')
    template_set.erb_template('imit.graph',
                              'client/graph_subscription_util.java.erb',
                              'main/java/#{graph.qualified_subscription_util_name.gsub(".","/")}.java',
                              :guard => 'graph.external_visibility?')
    template_set.erb_template(:repository,
                              'client/gwt/session_context.java.erb',
                              'main/java/#{repository.imit.qualified_gwt_client_session_context_name.gsub(".","/")}.java')
  end

  g.template_set(:imit_client_react4j_support) do |template_set|
    template_set.erb_template('imit.graph',
                              'client/gwt/react4j_subscription_view.java.erb',
                              'main/java/#{graph.qualified_react4j_subscription_view_name.gsub(".","/")}.java',
                              :additional_facets => [:react4j],
                              :guard => 'graph.external_visibility?')
  end

  g.template_set(:imit_client_service) do |template_set|
    template_set.erb_template(:exception,
                              'client/exception.java.erb',
                              'main/java/#{exception.imit.qualified_name.gsub(".","/")}.java')
    template_set.erb_template(:exception,
                              'client/exception_json_decoder.java.erb',
                              'main/java/#{exception.imit.qualified_json_decoder_name.gsub(".","/")}.java')
    template_set.erb_template(:service,
                              'client/service.java.erb',
                              'main/java/#{service.imit.qualified_service_name.gsub(".","/")}.java')
    template_set.erb_template(:service,
                              'client/service_impl.java.erb',
                              'main/java/#{service.imit.qualified_service_impl_name.gsub(".","/")}.java')
    template_set.erb_template(:data_module,
                              'client/remote_service_sting_fragment.java.erb',
                              'main/java/#{data_module.imit.qualified_remote_service_sting_fragment_name.gsub(".","/")}.java',
                              :guard => 'data_module.imit.generate_remote_service_sting_fragment?')
    template_set.erb_template(:data_module,
                              'client/remote_service_sting_test_fragment.java.erb',
                              'test/java/#{data_module.imit.qualified_remote_service_sting_test_fragment_name.gsub(".","/")}.java',
                              :guard => 'data_module.imit.generate_remote_service_sting_fragment?')
    template_set.erb_template(:repository,
                              'client/aggregate_remote_service_sting_fragment.java.erb',
                              'main/java/#{repository.imit.qualified_aggregate_remote_service_sting_fragment_name.gsub(".","/")}.java',
                              :guard => 'repository.imit.generate_aggregate_remote_service_sting_fragment?')
    template_set.erb_template(:repository,
                              'client/aggregate_remote_service_sting_test_fragment.java.erb',
                              'test/java/#{repository.imit.qualified_aggregate_remote_service_sting_test_fragment_name.gsub(".","/")}.java',
                              :guard => 'repository.imit.generate_aggregate_remote_service_sting_fragment?')
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
                                'client/schema_test.java.erb',
                                type + '/java/#{repository.imit.qualified_schema_test_name.gsub(".","/")}.java')
    end
  end
end

Domgen::Generator.define([:imit, :jpa],
                         "#{File.dirname(__FILE__)}/templates/server",
                         [Domgen::JPA::Helper, Domgen::Java::Helper]) do |g|

  g.template_set(:imit_server_service) do |template_set|
    template_set.erb_template(:repository,
                              'abstract_session_context_impl.java.erb',
                              'main/java/#{repository.imit.qualified_abstract_session_context_impl_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'system_metadata.java.erb',
                              'main/java/#{repository.imit.qualified_system_metadata_name.gsub(".","/")}.java')
  end

  g.template_set(:imit_server_qa) do |template_set|
    template_set.erb_template(:repository,
                              'net_module.java.erb',
                              'test/java/#{repository.imit.qualified_server_net_module_name.gsub(".","/")}.java')
  end
end
