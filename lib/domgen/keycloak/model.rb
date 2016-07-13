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
  FacetManager.facet(:keycloak) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :keycloak_filter, :filter, :server, :keycloak, '#{repository.name}KeycloakFilter'
      java_artifact :abstract_keycloak_filter, :filter, :server, :keycloak, 'Abstract#{repository.name}KeycloakFilter'
      java_artifact :keycloak_config_resolver, :filter, :server, :keycloak, '#{repository.name}KeycloakConfigResolver'

      attr_writer :protected_url_patterns

      def protected_url_patterns
        @protected_url_patterns ||= %w(/.keycloak/*)
      end

      attr_writer :jndi_config_base

      def jndi_config_base
        @jndi_config_base || "#{Domgen::Naming.underscore(repository.name)}/keycloak"
      end
    end
  end
end
