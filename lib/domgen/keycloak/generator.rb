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
    module Keycloak
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:keycloak]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end

Domgen.template_set(:keycloak_filter) do |template_set|
  template_set.template(Domgen::Generator::Keycloak::FACETS,
                        'keycloak.client',
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/keycloak_filter_interface.java.erb",
                        'main/java/#{client.qualified_keycloak_filter_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS)
  template_set.template(Domgen::Generator::Keycloak::FACETS,
                        'keycloak.client',
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/abstract_keycloak_filter.java.erb",
                        'main/java/#{client.qualified_abstract_keycloak_filter_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS)
  template_set.template(Domgen::Generator::Keycloak::FACETS,
                        'keycloak.client',
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/keycloak_filter.java.erb",
                        'main/java/#{client.qualified_keycloak_filter_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS)
  template_set.template(Domgen::Generator::Keycloak::FACETS,
                        'keycloak.client',
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/keycloak_config_resolver.java.erb",
                        'main/java/#{client.qualified_keycloak_config_resolver_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS)
end

Domgen.template_set(:keycloak_config_service) do |template_set|
  template_set.template(Domgen::Generator::Keycloak::FACETS,
                        'keycloak.client',
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/config_service.java.erb",
                        'main/java/#{client.qualified_config_service_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS,
                        :guard => 'client.public_client?')
end

Domgen.template_set(:keycloak_js_service) do |template_set|
  template_set.template(Domgen::Generator::Keycloak::FACETS,
                        'keycloak.client',
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/js_service.java.erb",
                        'main/java/#{client.qualified_js_service_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS)
end

Domgen.template_set(:keycloak_client_definitions) do |template_set|
  template_set.template(Domgen::Generator::Keycloak::FACETS,
                        :repository,
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/client_definitions.java.erb",
                        'main/java/#{repository.keycloak.qualified_client_definitions_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS)
end

Domgen.template_set(:keycloak_client_config) do |template_set|
  template_set.ruby_template(Domgen::Generator::Keycloak::FACETS,
                             'keycloak.client',
                             "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/client.rb",
                             'main/etc/keycloak/#{client.key}.json',
                             Domgen::Generator::Keycloak::HELPERS)
end

Domgen.template_set(:keycloak_gwt_jso) do |template_set|
  template_set.template(Domgen::Generator::Keycloak::FACETS + [:gwt],
                        'keycloak.client',
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/token.java.erb",
                        'main/java/#{client.qualified_token_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS)
  template_set.template(Domgen::Generator::Keycloak::FACETS + [:gwt],
                        'keycloak.client',
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/id_token.java.erb",
                        'main/java/#{client.qualified_id_token_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS)
end

Domgen.template_set(:keycloak_gwt_app) do |template_set|
  template_set.template(Domgen::Generator::Keycloak::FACETS + [:gwt],
                        'keycloak.client',
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/abstract_application.java.erb",
                        'main/java/#{client.qualified_abstract_application_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS,
                        :guard => '!client.bearer_only? && client.keycloak_repository.repository.gwt.enable_entrypoints?')
end
