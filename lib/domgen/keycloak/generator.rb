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
                        :repository,
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/abstract_keycloak_filter.java.erb",
                        'main/java/#{repository.keycloak.qualified_abstract_keycloak_filter_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS)
  template_set.template(Domgen::Generator::Keycloak::FACETS,
                        :repository,
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/keycloak_filter.java.erb",
                        'main/java/#{repository.keycloak.qualified_keycloak_filter_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS)
  template_set.template(Domgen::Generator::Keycloak::FACETS,
                        :repository,
                        "#{Domgen::Generator::Keycloak::TEMPLATE_DIRECTORY}/keycloak_config_resolver.java.erb",
                        'main/java/#{repository.keycloak.qualified_keycloak_config_resolver_name.gsub(".","/")}.java',
                        Domgen::Generator::Keycloak::HELPERS)
end

Domgen.template_set(:Keycloak => [:keycloak_filter])
