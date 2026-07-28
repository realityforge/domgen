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

Domgen::Generator.define([:replicant],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper, Domgen::Replicant::Helper]) do |g|
  g.template_set(:replicant_system_schema) do |template_set|
    template_set.erb_template(:repository,
                              'shared/system_schema_constants.java.erb',
                              'main/java/#{repository.replicant.qualified_system_schema_constants_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'shared/dataset_constants.java.erb',
                              'main/java/#{repository.replicant.qualified_dataset_constants_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'shared/entity_type_constants.java.erb',
                              'main/java/#{repository.replicant.qualified_entity_type_constants_name.gsub(".","/")}.java')
  end

  g.template_set(:replicant_client_entity) do |template_set|
    template_set.erb_template(:repository,
                              'client/system_schema_sting_fragment.java.erb',
                              'main/java/#{repository.replicant.qualified_system_schema_sting_fragment_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'client/system_schema_filter_tools.java.erb',
                              'main/java/#{repository.replicant.qualified_system_schema_filter_tools_name.gsub(".","/")}.java',
                              :guard => 'repository.replicant.datasets.any?{|dataset| dataset.updatable_filter_parameter? || dataset.reevaluate_membership_on_replica_update? || (!dataset.unfiltered? && dataset.routing_keys.any?{|routing_key| !routing_key.target_attribute.immutable?})}')
    template_set.erb_template(:data_module,
                              'client/mapper.java.erb',
                              'main/java/#{data_module.replicant.qualified_mapper_name.gsub(".","/")}.java',
                              :guard => 'data_module.arez.factory_required?')
    template_set.erb_template(:repository,
                              'client/router.java.erb',
                              'main/java/#{repository.replicant.qualified_client_router_name.gsub(".","/")}.java')
    template_set.erb_template('replicant.dataset',
                              'client/dataset_subscription_util.java.erb',
                              'main/java/#{dataset.qualified_subscription_util_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'client/system_schema_hooks.java.erb',
                              'main/java/#{repository.replicant.qualified_system_schema_hooks_name.gsub(".","/")}.java')
  end

  g.template_set(:replicant_client_react4j_support) do |template_set|
    template_set.erb_template('replicant.dataset',
                              'client/gwt/react4j_area_of_interest_view.java.erb',
                              'main/java/#{dataset.qualified_react4j_area_of_interest_view_name.gsub(".","/")}.java',
                              :additional_facets => [:react4j],
                              :guard => 'dataset.area_of_interest_origin_permitted?')
  end

  g.template_set(:replicant_client_service) do |template_set|
    template_set.erb_template(:exception,
                              'client/exception.java.erb',
                              'main/java/#{exception.replicant.qualified_name.gsub(".","/")}.java')
    template_set.erb_template(:exception,
                              'client/exception_json_decoder.java.erb',
                              'main/java/#{exception.replicant.qualified_json_decoder_name.gsub(".","/")}.java')
    template_set.erb_template(:service,
                              'client/service.java.erb',
                              'main/java/#{service.replicant.qualified_service_name.gsub(".","/")}.java')
    template_set.erb_template(:service,
                              'client/service_impl.java.erb',
                              'main/java/#{service.replicant.qualified_service_impl_name.gsub(".","/")}.java')
    template_set.erb_template(:data_module,
                              'client/remote_service_sting_fragment.java.erb',
                              'main/java/#{data_module.replicant.qualified_remote_service_sting_fragment_name.gsub(".","/")}.java',
                              :guard => 'data_module.replicant.generate_remote_service_sting_fragment?')
    template_set.erb_template(:data_module,
                              'client/remote_service_sting_test_fragment.java.erb',
                              'test/java/#{data_module.replicant.qualified_remote_service_sting_test_fragment_name.gsub(".","/")}.java',
                              :guard => 'data_module.replicant.generate_remote_service_sting_fragment?')
    template_set.erb_template(:service,
                              'client/mock_service_impl.java.erb',
                              'test/java/#{service.replicant.qualified_mock_service_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'client/aggregate_remote_service_sting_fragment.java.erb',
                              'main/java/#{repository.replicant.qualified_aggregate_remote_service_sting_fragment_name.gsub(".","/")}.java',
                              :guard => 'repository.replicant.generate_aggregate_remote_service_sting_fragment?')
    template_set.erb_template(:repository,
                              'client/aggregate_remote_service_sting_test_fragment.java.erb',
                              'test/java/#{repository.replicant.qualified_aggregate_remote_service_sting_test_fragment_name.gsub(".","/")}.java',
                              :guard => 'repository.replicant.generate_aggregate_remote_service_sting_fragment?')
  end

  %w(main test).each do |type|
    g.template_set(:"replicant_server_#{type}_qa") do |template_set|
      template_set.erb_template(:repository,
                                'server/integration_module.java.erb',
                                type + '/java/#{repository.replicant.qualified_integration_module_name.gsub(".","/")}.java',
                                :guard => 'repository.replicant.include_standard_integration_test_module?')
    end
    g.template_set(:"replicant_client_#{type}_qa_external") do |template_set|
      template_set.erb_template(:repository,
                                'client/system_schema_test.java.erb',
                                type + '/java/#{repository.replicant.qualified_system_schema_test_name.gsub(".","/")}.java')
    end
  end
end

Domgen::Generator.define([:replicant, :jpa],
                         "#{File.dirname(__FILE__)}/templates/server",
                         [Domgen::JPA::Helper, Domgen::Replicant::Helper, Domgen::Java::Helper]) do |g|

  g.template_set(:replicant_server_service) do |template_set|
    template_set.erb_template(:repository,
                              'abstract_replicant_server_adapter.java.erb',
                              'main/java/#{repository.replicant.qualified_abstract_replicant_server_adapter_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'system_schema.java.erb',
                              'main/java/#{repository.replicant.qualified_system_schema_name.gsub(".","/")}.java')
    template_set.erb_template(:data_module,
                              'encoder.java.erb',
                              'main/java/#{data_module.replicant.qualified_encoder_name.gsub(".","/")}.java',
                              :guard => 'data_module.replicant.replicated_entities?')
  end

  g.template_set(:replicant_server_qa) do |template_set|
    template_set.erb_template(:repository,
                              'entity_test_module.java.erb',
                              'test/java/#{repository.replicant.qualified_server_entity_test_module_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'net_module.java.erb',
                              'test/java/#{repository.replicant.qualified_server_net_module_name.gsub(".","/")}.java')
  end
end
