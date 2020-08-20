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

Domgen::Generator.define([:keycloak],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper]) do |g|
  g.template_set(:keycloak_filter) do |template_set|
    template_set.erb_template('keycloak.client',
                              'keycloak_filter_interface.java.erb',
                              'main/java/#{client.qualified_keycloak_filter_interface_name.gsub(".","/")}.java',
                              :guard => 'client.protects_application_urls?')
    template_set.erb_template('keycloak.client',
                              'abstract_keycloak_filter.java.erb',
                              'main/java/#{client.qualified_abstract_keycloak_filter_name.gsub(".","/")}.java',
                              :guard => 'client.protects_application_urls?')
    template_set.erb_template('keycloak.client',
                              'standard_keycloak_filter.java.erb',
                              'main/java/#{client.qualified_standard_keycloak_filter_name.gsub(".","/")}.java',
                              :guard => '!client.custom_filter? && client.protects_application_urls?')
    template_set.erb_template('keycloak.client',
                              'keycloak_filter.java.erb',
                              'main/java/#{client.qualified_keycloak_filter_name.gsub(".","/")}.java',
                              :guard => 'client.protects_application_urls?')
    template_set.erb_template('keycloak.client',
                              'keycloak_config_resolver.java.erb',
                              'main/java/#{client.qualified_keycloak_config_resolver_name.gsub(".","/")}.java',
                              :guard => 'client.protects_application_urls?')
    template_set.erb_template('keycloak.remote_client',
                              'ee_remote_client_config.java.erb',
                              'main/java/#{remote_client.qualified_ee_remote_client_config_name.gsub(".","/")}.java')
  end

  g.template_set(:keycloak_auth_service) do |template_set|
    template_set.erb_template(:repository,
                              'auth_service_implementation.java.erb',
                              'main/java/#{repository.keycloak.qualified_auth_service_implementation_name.gsub(".","/")}.java',
                              :additional_facets => [:ejb],
                              :guard => 'repository.keycloak.has_local_auth_service?')
  end

  g.template_set(:keycloak_auth_service_qa) do |template_set|
    template_set.erb_template(:repository,
                              'test_auth_service_implementation.java.erb',
                              'test/java/#{repository.keycloak.qualified_test_auth_service_implementation_name.gsub(".","/")}.java',
                              :additional_facets => [:ejb],
                              :guard => 'repository.keycloak.has_local_auth_service?')
    template_set.erb_template(:repository,
                              'test_module.java.erb',
                              'test/java/#{repository.keycloak.qualified_test_module_name.gsub(".","/")}.java',
                              :additional_facets => [:ejb],
                              :guard => 'repository.keycloak.has_local_auth_service?')
  end

  %w(main test).each do |type|
    g.template_set(:"keycloak_#{type}_integration_qa") do |template_set|
      template_set.erb_template(:repository,
                                'integration_test_module.java.erb',
                                type + '/java/#{repository.keycloak.qualified_integration_test_module_name.gsub(".","/")}.java',
                                :additional_facets => [:ejb])
    end
  end

  g.template_set(:keycloak_config_service) do |template_set|
    template_set.erb_template('keycloak.client',
                              'config_service.java.erb',
                              'main/java/#{client.qualified_config_service_name.gsub(".","/")}.java',
                              :guard => 'client.public_client? && client.keycloak_repository.repository.application.user_experience?')
  end

  g.template_set(:keycloak_js_service) do |template_set|
    template_set.erb_template('keycloak.client',
                              'js_service.java.erb',
                              'main/java/#{client.qualified_js_service_name.gsub(".","/")}.java',
                              :guard => 'client.keycloak_repository.repository.application.user_experience?')
    template_set.erb_template('keycloak.client',
                              'js_min_service.java.erb',
                              'main/java/#{client.qualified_js_min_service_name.gsub(".","/")}.java',
                              :guard => 'client.keycloak_repository.repository.application.user_experience?')
  end

  g.template_set(:keycloak_client_definitions) do |template_set|
    template_set.erb_template(:repository,
                              'client_definitions.java.erb',
                              'main/java/#{repository.keycloak.qualified_client_definitions_name.gsub(".","/")}.java',
                              :guard => 'repository.keycloak.has_local_auth_service? && repository.keycloak.clients.any?{|client|!client.bearer_only?}')
  end

  g.template_set(:keycloak_client_config) do |template_set|
    template_set.ruby_template('keycloak.client', 'client.rb', 'main/etc/keycloak/#{client.key}.json')
  end

  g.template_set(:keycloak_gwt_jso) do |template_set|
    template_set.erb_template('keycloak.client',
                              'token.java.erb',
                              'main/java/#{client.qualified_token_name.gsub(".","/")}.java',
                              :additional_facets => [:gwt],
                              :guard => '!client.bearer_only?')
    template_set.erb_template('keycloak.client',
                              'id_token.java.erb',
                              'main/java/#{client.qualified_id_token_name.gsub(".","/")}.java',
                              :additional_facets => [:gwt],
                              :guard => '!client.bearer_only?')
    template_set.erb_template(:repository,
                              'gwt_token_service.java.erb',
                              'main/java/#{repository.keycloak.qualified_gwt_token_service_name.gsub(".","/")}.java',
                              :additional_facets => [:gwt],
                              :guard => 'repository.keycloak.generates_tokens?')

    %w(main test).each do |type|
      g.template_set(:"keycloak_gwt_#{type}_qa") do |template_set|
        template_set.erb_template(:repository,
                                  'mock_keycloak_sting_fragment.java.erb',
                                  type + '/java/#{repository.keycloak.qualified_mock_keycloak_sting_fragment_name.gsub(".","/")}.java',
                                  :additional_facets => [:gwt])
      end
    end
  end
end
