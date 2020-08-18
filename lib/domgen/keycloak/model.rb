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

      attr_writer :java_accessor_key

      attr_writer :java_type

      attr_writer :js_type

      def java_accessor_key
        @java_accessor_key || Reality::Naming.pascal_case(self.name.to_s.gsub(' ', '_'))
      end

      def java_type
        @java_type || 'java.lang.String'
      end

      def js_type
        @js_type || self.java_type
      end

      attr_writer :token_accessor_key

      def token_accessor_key
        @token_accessor_key || Reality::Naming.pascal_case(self.config['claim.name'] || self.name.to_s.gsub(' ', '_'))
      end

      def standard_claim?
        %w(Name FamilyName GivenName MiddleName NickName Profile Picture Website Email EmailVerified Gender Birthdate Zoneinfo Locale PhoneNumber PhoneNumberVerified PreferredUsername).include?(self.token_accessor_key)
      end

      def protocol
        @protocol || 'openid-connect'
      end

      attr_writer :protocol_mapper

      def protocol_mapper
        @protocol_mapper || 'oidc-usermodel-property-mapper'
      end

      attr_writer :consent_required

      def consent_required?
        @consent_required.nil? ? false : !!@consent_required
      end

      attr_writer :consent_text

      def consent_text
        @consent_text || (consent_required? ? "${#{Reality::Naming.camelize(name.to_s.gsub(' ', '_'))}}" : '')
      end

      attr_writer :config

      def config
        @config || {}
      end
    end

    class RemoteClient < Domgen.ParentedElement(:keycloak_repository)
      def initialize(keycloak_repository, name, options = {}, &block)
        @name = name
        super(keycloak_repository, options, &block)
      end

      attr_accessor :name

      include Domgen::Java::BaseJavaGenerator

      java_artifact :ee_remote_client_config, :service, :server, :keycloak, '#{self.name}KeycloakConfig'

      attr_writer :jndi_config_base

      def jndi_config_base
        @jndi_config_base || "#{keycloak_repository.jndi_config_base}/remote-client/#{Reality::Naming.underscore(self.name)}"
      end

      def client_constant_prefix
        "#{Reality::Naming.uppercase_constantize(keycloak_repository.repository.name)}_KEYCLOAK_REMOTE_CLIENT_#{Reality::Naming.uppercase_constantize(name)}"
      end
    end

    class Client < Domgen.ParentedElement(:keycloak_repository)
      def initialize(keycloak_repository, key, options = {}, &block)
        @key = key
        super(keycloak_repository, options, &block)
      end

      include Domgen::Java::BaseJavaGenerator

      java_artifact :keycloak_filter, :filter, :server, :keycloak, '#{qualified_class_name}KeycloakFilter'
      java_artifact :keycloak_filter_interface, :filter, :server, :keycloak, '#{qualified_class_name}KeycloakUrlFilter'
      java_artifact :abstract_keycloak_filter, :filter, :server, :keycloak, 'Abstract#{qualified_class_name}KeycloakUrlFilterImpl'
      java_artifact :standard_keycloak_filter, :filter, :server, :keycloak, '#{qualified_class_name}KeycloakUrlFilterImpl'
      java_artifact :keycloak_config_resolver, :filter, :server, :keycloak, '#{qualified_class_name}KeycloakConfigResolver'
      java_artifact :config_service, :servlet, :server, :keycloak, '#{qualified_class_name}KeycloakConfigServlet'
      java_artifact :js_service, :servlet, :server, :keycloak, '#{qualified_class_name}KeycloakJsServlet'
      java_artifact :js_min_service, :servlet, :server, :keycloak, '#{qualified_class_name}KeycloakMinJsServlet'
      java_artifact :token, :data_type, :client, :keycloak, '#{qualified_class_name}Token'
      java_artifact :id_token, :data_type, :client, :keycloak, '#{qualified_class_name}IdToken'

      def qualified_type_name
        "#{default_client? ? '' : Reality::Naming.pascal_case(keycloak_repository.repository.name)}#{Reality::Naming.pascal_case(name)}"
      end

      def qualified_class_name
        "#{qualified_type_name}Client"
      end

      attr_writer :custom_filter

      def custom_filter?
        @custom_filter.nil? ? false : !!@custom_filter
      end

      attr_writer :protected_url_patterns

      def protected_url_patterns
        @protected_url_patterns ||= ["/#{local_admin_url}"]
      end

      def protects_application_urls?
        protected_url_patterns.any?{|url| url != "/#{local_admin_url}"}
      end

      attr_writer :jndi_config_base

      def jndi_config_base
        @jndi_config_base || "#{keycloak_repository.jndi_config_base}/client/#{name}"
      end

      def jndi_debug_key
        "#{jndi_config_base}_debug"
      end

      attr_reader :key

      attr_writer :client_id

      def env_constant_prefix
        "#{Reality::Naming.uppercase_constantize(keycloak_repository.repository.name)}#{default_client? ? '' : "_#{Reality::Naming.uppercase_constantize(key)}"}"
      end

      def client_id
        "{{#{env_constant_prefix}_NAME}}"
      end

      def client_constant_prefix
        "#{Reality::Naming.uppercase_constantize(keycloak_repository.repository.name)}_KEYCLOAK_CLIENT#{default_client? ? '' : "_#{Reality::Naming.uppercase_constantize(key)}"}"
      end

      def default_client?
        repository_name = keycloak_repository.repository.name
        Reality::Naming.underscore(repository_name) == key.to_s
      end

      attr_writer :name

      def name
        @name || Reality::Naming.underscore(key.to_s)
      end

      attr_writer :root_url

      def root_url
        @root_url || ''
      end

      attr_writer :base_url

      def base_url
        @base_url || ''
      end

      attr_writer :origin

      def origin
        @origin || "{{#{env_constant_prefix}_ORIGIN}}"
      end

      # Local url for clients capabilities
      attr_writer :local_client_url

      def local_client_url
        @local_client_url || "#{keycloak_repository.base_keycloak_client_url}/#{name}"
      end

      attr_writer :local_config_url

      def local_config_url
        @local_config_url || "/#{local_client_url}/keycloak.json"
      end

      attr_writer :local_admin_url

      def local_admin_url
        @local_admin_url || "#{local_client_url}/admin"
      end

      attr_writer :admin_url

      def admin_url
        @admin_url || "{{#{env_constant_prefix}_URL}}/#{local_admin_url}"
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
        @direct_access_grants.nil? ? false : !!@direct_access_grants
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
        @full_scope_allowed.nil? ? false : !!@full_scope_allowed
      end

      attr_writer :surrogate_auth_required

      def surrogate_auth_required?
        @surrogate_auth_required.nil? ? false : !!@surrogate_auth_required
      end

      attr_writer :always_display_in_console

      def always_display_in_console?
        @always_display_in_console.nil? ? true : !!@always_display_in_console
      end

      attr_writer :default_roles

      def default_roles
        @default_roles ||= []
      end

      attr_writer :redirect_uris

      def redirect_uris
        @redirect_uris ||= ["{{#{env_constant_prefix}_URL}}/*"]
      end

      attr_writer :web_origins

      def web_origins
        @web_origins ||= (keycloak_repository.repository.gwt? ? [origin] : [])
      end

      def ssl_required=(ssl_required)
        valid_values = %w(all external none)
        raise "ssl_required value '#{ssl_required}' is invalid. Must be one of #{valid_values.inspect}" unless valid_values.include?(ssl_required)
        @ssl_required = ssl_required
      end

      def ssl_required
        @ssl_required || 'external'
      end

      def enable_cors?
        @enable_cors.nil? ? true : !!@enable_cors
      end

      attr_writer :enable_cors

      attr_accessor :cors_max_age

      attr_accessor :cors_allowed_methods

      attr_accessor :cors_allowed_headers

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

      def pre_complete
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
              :token_accessor_key => 'Name',
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

      def add_groups_claim
        c = claim('groups',
                  :config =>
                    {
                      'id.token.claim' => 'false',
                      'access.token.claim' => 'true',
                      'claim.name' => 'groups'
                    })

        c.protocol_mapper = 'oidc-group-membership-mapper'
        c.java_type = 'java.util.List<String>'
        c.js_type = 'elemental2.core.JsArray<String>'
        c
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

      def keycloak_version=(keycloak_version)
        valid_versions = %w(5 11)
        raise "Invalid keycloak version #{keycloak_version}. Valid versions include #{valid_versions}" unless valid_versions.include?(keycloak_version.to_s)
        @keycloak_version = keycloak_version
      end

      def keycloak_version
        @keycloak_version.nil? ? '5' : @keycloak_version
      end

      java_artifact :gwt_token_service, :service, :client, :keycloak, '#{repository.name}KeycloakTokenService'
      java_artifact :mock_keycloak_sting_fragment, :test, :client, :keycloak, 'Mock#{repository.name}KeycloakFragment', :sub_package => 'util'
      java_artifact :client_definitions, nil, :shared, :keycloak, '#{repository.name}KeycloakClients'
      java_artifact :test_module, :test, :server, :keycloak, '#{repository.name}KeycloakServicesModule', :sub_package => 'util'
      java_artifact :test_auth_service_implementation, :test, :server, :keycloak, 'Test#{repository.keycloak.auth_service_implementation_name}', :sub_package => 'util'
      java_artifact :integration_test_module, :test, :integration, :keycloak, '#{repository.name}KeycloakTestModule', :sub_package => 'util'

      def client_ioc_package
        repository.gwt.client_ioc_package
      end

      def auth_service_implementation_name
        self.repository.service_by_name(self.auth_service_name).ejb.service_implementation_name
      end

      def qualified_auth_service_implementation_name
        self.repository.service_by_name(self.auth_service_name).ejb.qualified_service_implementation_name
      end

      attr_writer :auth_service_name

      def auth_service_name
        @auth_service_name || "#{auth_service_module}.#{repository.name}AuthService"
      end

      attr_writer :auth_service_module

      def auth_service_module
        if @auth_service_module.nil?
          @auth_service_module =
            repository.data_module_by_name?(repository.name) ? repository.name : repository.data_modules[0].name
        end
        @auth_service_module
      end

      attr_writer :jndi_config_base

      def jndi_config_base
        @jndi_config_base || "#{Reality::Naming.underscore(repository.name)}/keycloak"
      end

      # Relative url for base of all keycloak configuration
      attr_writer :base_keycloak_client_url

      def base_keycloak_client_url
        @base_keycloak_client_url || '.keycloak'
      end

      def has_local_auth_service?
        repository.application.code_deployable?
      end

      # Does this application generate any tokens as part of it's operation?
      # or does it rely on other applications to generate tokens and then
      # will accept their tokens.
      def generates_tokens?
        has_local_auth_service? && self.clients.any?{|c| !c.bearer_only?}
      end

      def default_client
        Domgen.error('default_client called when local auth service is not enabled.') unless has_local_auth_service?
        key = Reality::Naming.underscore(repository.name.to_s)
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

      Domgen.target_manager.target(:client, :repository, :facet_key => :keycloak)

      def remote_client_by_key?(key)
        !!remote_client_map[key.to_s]
      end

      def remote_client_by_key(key)
        raise "No keycloak remote_client with key #{key} defined." unless remote_client_map[key.to_s]
        remote_client_map[key.to_s]
      end

      def remote_client(key, options = {}, &block)
        raise "Keycloak remote_client with id #{key} already defined." if remote_client_map[key.to_s]
        remote_client_map[key.to_s] = Domgen::Keycloak::RemoteClient.new(self, key, options, &block)
      end

      def remote_clients
        remote_client_map.values
      end

      Domgen.target_manager.target(:remote_client, :repository, :facet_key => :keycloak)

      def pre_complete
        self.clients.each do |client|
          client.pre_complete
        end
        if repository.ee?
          repository.ee.cdi_scan_excludes << 'org.bouncycastle.**'
          repository.ee.cdi_scan_excludes << 'org.jboss.logging.**'
          repository.ee.cdi_scan_excludes << 'org.keycloak.**'
          repository.ee.cdi_scan_excludes << 'org.apache.commons.codec.**'
          repository.ee.cdi_scan_excludes << 'org.apache.commons.logging.**'
          repository.ee.cdi_scan_excludes << 'org.apache.http.**'
          repository.ee.add_integration_test_module(self.integration_test_module_name, self.qualified_integration_test_module_name)
        end
        if repository.ejb? && has_local_auth_service?
          self.repository.service(self.auth_service_name) unless self.repository.service_by_name?(self.auth_service_name)
          self.repository.service_by_name(self.auth_service_name).tap do |s|
            s.ejb.bind_in_tests = false
            s.ejb.generate_base_test = false
            s.disable_facets_not_in(:ejb)
            s.method(:IsAuthenticated) do |m|
              m.returns(:boolean)
            end
            self.default_client.claims.each do |claim|
              s.method("Get#{claim.java_accessor_key}") do |m|
                m.returns(claim.java_type)
              end
            end
          end
        end
      end

      def pre_verify
        if repository.gwt?
          if repository.application.user_experience?
            repository.gwt.sting_test_includes << repository.keycloak.qualified_mock_keycloak_sting_fragment_name
          else
            repository.gwt.sting_test_injector_includes << repository.keycloak.qualified_mock_keycloak_sting_fragment_name
          end
        end
        if repository.ejb? && self.has_local_auth_service?
          repository.ejb.add_flushable_test_module(self.test_module_name, self.qualified_test_module_name)
          repository.ejb.add_test_class_content(<<-JAVA)

  public void setupAccount( #{self.default_client.claims.collect {|claim| "@javax.annotation.Nonnull final #{claim.java_type} #{Reality::Naming.camelize(claim.java_accessor_key)}"}.join(', ') } )
  {
    toObject( #{self.qualified_test_auth_service_implementation_name }.class, s( #{repository.service_by_name(self.auth_service_name).ejb.qualified_service_name }.class ) ).setupAccount( #{self.default_client.claims.collect {|claim| Reality::Naming.camelize(claim.java_accessor_key)}.join(', ') } );
  }
          JAVA
        end
      end

      private

      def remote_client_map
        @remote_clients ||= {}
      end

      def client_map
        unless @clients
          @clients = {}
          default_client if has_local_auth_service?
        end
        @clients
      end
    end
  end
end
