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
  module Keycloak

    class Claim < Domgen.ParentedElement(:client)
      def initialize(client, name, options = {}, &block)
        @name = name
        super(client, options, &block)
      end

      attr_reader :name

      attr_writer :protocol

      def protocol
        @protocol || 'openid-connect'
      end

      attr_writer :protocol_mapper

      def protocol_mapper
        @protocol_mapper || 'oidc-usermodel-property-mapper'
      end

      attr_writer :consent_required

      def consent_required?
        @consent_required.nil? ? true : !!@consent_required
      end

      attr_writer :consent_text

      def consent_text
        @consent_text || (consent_required? ? "${#{Domgen::Naming.camelize(name.to_s.gsub(' ', '_'))}}" : '')
      end

      attr_writer :config

      def config
        @config || {}
      end
    end

    class Client < Domgen.ParentedElement(:keycloak_repository)
      def initialize(keycloak_repository, key, options = {}, &block)
        @key = key
        super(keycloak_repository, options, &block)
      end

      attr_reader :key

      attr_writer :name

      def name
        Domgen::Naming.underscore(key.to_s)
      end

      attr_writer :root_url

      def root_url
        @root_url || "{{APPLICATION_URL}}"
      end

      attr_writer :base_url

      def base_url
        @base_url || '/'
      end

      attr_writer :standard_flow

      def standard_flow?
        @standard_flow.nil? ? true : !!@standard_flow
      end

      attr_writer :implicit_flow

      def implicit_flow?
        @implicit_flow.nil? ? true : !!@implicit_flow
      end

      attr_writer :consent_required

      def consent_required?
        @consent_required.nil? ? false : !!@consent_required
      end

      attr_writer :bearer_only

      def bearer_only?
        @bearer_only.nil? ? false : !!@bearer_only
      end

      attr_writer :service_accounts

      def service_accounts?
        @service_accounts.nil? ? false : !!@service_accounts
      end

      attr_writer :direct_access_grants

      def direct_access_grants?
        @direct_access_grants.nil? ? true : !!@direct_access_grants
      end

      attr_writer :public_client

      def public_client?
        @public_client.nil? ? true : !!@public_client
      end

      attr_writer :frontchannel_logout

      def frontchannel_logout?
        @frontchannel_logout.nil? ? true : !!@frontchannel_logout
      end

      attr_writer :full_scope_allowed

      def full_scope_allowed?
        @full_scope_allowed.nil? ? true : !!@full_scope_allowed
      end

      attr_writer :surrogate_auth_required

      def surrogate_auth_required?
        @surrogate_auth_required.nil? ? false : !!@surrogate_auth_required
      end

      attr_writer :redirect_uris

      def redirect_uris
        @redirect_uris ||= ["#{root_url}/*"]
      end

      def claim(name, options = {}, &block)
        raise "Claim with name '#{name}' already defined for client #{self.name}" if claim_map[name.to_s]
        claim_map[name.to_s] = Claim.new(self, name, options, &block)
      end

      def claims
        claim_map.values
      end

      def claim_by_name?(name)
        !!claim_map[name.to_s]
      end

      def claim_by_name(name)
        raise "Claim with name '#{name}' not defined for client #{self.name}" unless claim_map[name.to_s]
        claim_map[name.to_s]
      end

      attr_writer :standard_claims

      def standard_claims
        @standard_claims || [:username]
      end

      def pre_verify
        standard_claims.each do |claim_type|
          self.send("add_#{claim_type}_claim") unless claim_by_name?(claim_type)
        end
      end

      def add_username_claim
        claim(:username,
              :config =>
                {
                  'user.attribute' => 'username',
                  'id.token.claim' => 'true',
                  'access.token.claim' => 'true',
                  'claim.name' => 'preferred_username',
                  'jsonType.label' => 'String'
                })
      end

      def add_given_name_claim
        claim('given name',
              :config =>
                {
                  'user.attribute' => 'firstName',
                  'id.token.claim' => 'false',
                  'access.token.claim' => 'true',
                  'claim.name' => 'given_name',
                  'jsonType.label' => 'String'
                })
      end

      def add_family_name_claim
        claim('family name',
              :config =>
                {
                  'user.attribute' => 'lastName',
                  'id.token.claim' => 'false',
                  'access.token.claim' => 'true',
                  'claim.name' => 'family_name',
                  'jsonType.label' => 'String'
                })
      end

      def add_full_name_claim
        claim('full name',
              :protocol_mapper => 'oidc-full-name-mapper',
              :config =>
                {
                  'id.token.claim' => 'false',
                  'access.token.claim' => 'true'
                })
      end

      def add_email_claim
        claim('email',
              :config =>
                {
                  'user.attribute' => 'email',
                  'id.token.claim' => 'false',
                  'access.token.claim' => 'true',
                  'claim.name' => 'email',
                  'jsonType.label' => 'String'
                })
      end

      private

      def claim_map
        @claim_map ||= {}
      end
    end
  end

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

      def default_client
        key = Domgen::Naming.underscore(repository.name.to_s)
        client(key) unless client_by_key?(key)
        client_by_key(key)
      end

      def client_by_key?(key)
        !!client_map[key.to_s]
      end

      def client_by_key(key)
        raise "No keycloak client with key #{key} defined." unless client_map[key.to_s]
        client_map[key.to_s]
      end

      def client(key, options = {}, &block)
        raise "Keycloak client with id #{key} already defined." if client_map[key.to_s]
        client_map[key.to_s] = Domgen::Keycloak::Client.new(self, key, options, &block)
      end

      def clients
        client_map.values
      end

      TargetManager.register_target('keycloak.client', :repository, :keycloak, :clients)

      def pre_verify
        default_client

        clients.each do |client|
          client.pre_verify
        end
      end

      private

      def client_map
        @clients ||= {}
      end
    end
  end
end
