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
  FacetManager.facet(:gwt_rpc => [:gwt, :jackson, :keycloak]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      attr_writer :module_name

      def module_name
        @module_name || Reality::Naming.underscore(repository.name)
      end

      attr_writer :base_api_url

      def base_api_url
        @base_api_url || 'api/rpc'
      end

      attr_writer :api_url

      def api_url
        @api_url || "#{self.base_api_url}/#{repository.gwt.module_name}"
      end

      java_artifact :default_callback, :service, :client, :gwt_rpc, '#{repository.name}DefaultAsyncCallback'
      java_artifact :async_callback_adapter, :service, :client, :gwt_rpc, '#{repository.name}AsyncCallbackAdapter'
      java_artifact :rpc_request_builder, :ioc, :client, :gwt_rpc, '#{repository.name}RpcRequestBuilder'
      java_artifact :rpc_services_sting_fragment, :ioc, :client, :gwt_rpc, '#{repository.name}GwtRpcServicesFragment'
      java_artifact :mock_rpc_services_sting_fragment, :test, :client, :gwt_rpc, 'Mock#{repository.name}GwtRpcServicesFragment', :sub_package => 'util'

      java_artifact :code_server_config, :service, :server, :gwt_rpc, '#{repository.name}CodeServerConfig'
      java_artifact :code_server_config_resources, :service, :server, :gwt_rpc, '#{repository.name}CodeServerConfigResources'

      def client_ioc_package
        repository.gwt.client_ioc_package
      end

      attr_writer :server_servlet_package

      def server_servlet_package
        @server_servlet_package || "#{server_package}.servlet"
      end

      attr_writer :services_module_name

      attr_writer :keycloak_client

      def keycloak_client
        @keycloak_client || (repository.application? && !repository.application.user_experience? ? repository.keycloak.default_client.key : :api)
      end

      def pre_verify
        if repository.keycloak.has_local_auth_service?
          exists = repository.keycloak.client_by_key?(self.keycloak_client)
          client =
            exists ?
              repository.keycloak.client_by_key(self.keycloak_client) :
              repository.keycloak.client(self.keycloak_client)
          unless exists
            client.bearer_only = true
            client.redirect_uris.clear
            client.web_origins.clear
          end
          client.protected_url_patterns << "/#{base_api_url}/*"
        end
        repository.gwt.sting_test_includes << repository.gwt_rpc.qualified_mock_rpc_services_sting_fragment_name
      end

      protected

      def facet_key
        :gwt
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::ClientServerJavaPackage

      attr_writer :server_servlet_package

      def server_servlet_package
        @server_servlet_package || resolve_package(:server_servlet_package)
      end

      attr_writer :api_url

      def api_url
        @api_url || (data_module.name == data_module.repository.name) ? data_module.repository.gwt_rpc.api_url : "#{data_module.repository.gwt_rpc.api_url}/#{Reality::Naming.underscore(data_module.name)}"
      end

      protected

      def facet_key
        :gwt_rpc
      end
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :servlet_path

      def servlet_path
        @servlet_path || service.name
      end

      attr_writer :api_url

      def api_url
        @api_url || "#{service.data_module.gwt_rpc.api_url}/#{self.servlet_path}"
      end

      attr_writer :rpc_prefix

      def rpc_prefix
        @rpc_prefix || 'GwtRpc'
      end

      attr_writer :default_callback

      def default_callback?
        @default_callback.nil? ? true : @default_callback
      end

      attr_writer :service_name

      def service_name
        @service_name || service.name
      end

      def qualified_service_name
        "#{parent.parent.gwt_rpc.client_service_package}.#{service_name}"
      end

      java_artifact :rpc_service, :service, :shared, :gwt_rpc, '#{rpc_prefix}#{service.name}'
      java_artifact :async_rpc_service, :service, :shared, :gwt_rpc, '#{rpc_service_name}Async'
      java_artifact :servlet, :servlet, :server, :gwt_rpc, '#{rpc_service_name}Servlet'
    end

    facet.enhance(Method) do
      def name
        Reality::Naming.camelize(method.name)
      end

      attr_writer :cancelable

      def cancelable?
        @cancelable.nil? ? false : @cancelable
      end

    end

    facet.enhance(Parameter) do
      def characteristic_transport_type
        if parameter.collection?
          collection_transport_type
        elsif parameter.datetime? || parameter.integer? || parameter.reference?
          'double'
        elsif parameter.struct?
          parameter.gwt_rpc.java_component_type(:boundary)
        else
          parameter.gwt_rpc.java_component_type(:transport)
        end
      end

      def collection_transport_type
        base_type =
          if parameter.datetime? || parameter.integer? || parameter.reference?
            'double'
          elsif parameter.struct?
            parameter.gwt_rpc.java_component_type(:boundary)
          else
            parameter.gwt_rpc.java_component_type(:transport)
          end

        "#{base_type}[]"
      end

      def to_characteristic_transport_type
        param = Reality::Naming.camelize(parameter.name)
        if parameter.collection?
          to_collection_transport_type
        elsif parameter.datetime?
          "#{param}.getTime()"
        elsif parameter.enumeration?
          "#{param}.ordinal()"
        elsif parameter.date?
          "#{param}.toString()"
        else
          param
        end
      end

      def to_collection_transport_type
        param = Reality::Naming.camelize(parameter.name)
        if parameter.integer? || parameter.reference?
          "#{param}.stream().mapToDouble(Integer::intValue).toArray()"
        elsif parameter.datetime?
          "#{param}.stream().map(d -> d.getTime()).toArray()"
        elsif parameter.enumeration?
          "#{param}.stream().map(e -> e.ordinal()).toArray()"
        elsif parameter.date?
          "#{param}.stream().map(d -> d.toString()).toArray()"
        else
          "#{param}.toArray( new #{parameter.imit.java_component_type}[ 0 ])"
        end

      end
    end

    facet.enhance(Parameter) do
      include Domgen::Java::ImitJavaCharacteristic

      # Does the parameter come from the environment?
      def environmental?
        !!@environment_key
      end

      attr_reader :environment_key

      def environment_key=(environment_key)
        Domgen.error("Unknown environment_key #{environment_key}") unless valid_environment_key?(environment_key)
        @environment_key = environment_key
      end

      def valid_environment_key?(environment_key)
        self.class.environment_key_set.include?(environment_key) ||
          environment_key_is_cookie?(environment_key)
      end

      def environment_key_is_cookie?(environment_key = self.environment_key)
        environment_key =~ /^request:cookie:.*/
      end

      def environment_value
        Domgen.error('environment_value invoked for non-environmental value') unless environmental?
        return "findCookie(getThreadLocalRequest(),\"#{environment_key.to_s[15, 100]}\")" if environment_key_is_cookie?(environment_key)
        value = self.class.environment_key_set[environment_key]
        return value if value

      end

      def self.environment_key_set
        {
          'request:session:id' => 'getThreadLocalRequest().getSession(true).getId()',
          'request:permutation-strong-name' => 'getPermutationStrongName()',
          'request:locale' => 'getThreadLocalRequest().getLocale().toString()',
          'request:remote-host' => 'getThreadLocalRequest().getRemoteHost()',
          'request:remote-address' => 'getThreadLocalRequest().getRemoteAddr()',
          'request:remote-port' => 'getThreadLocalRequest().getRemotePort()',
          'request:remote-user' => 'getThreadLocalRequest().getRemoteUser()',
          'request' => 'getThreadLocalRequest()',
        }
      end

      protected

      def characteristic
        parameter
      end
    end

    facet.enhance(Result) do
      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    facet.enhance(Exception) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :name, :data_type, :shared, :gwt_rpc, 'GwtRpc#{exception.name}Exception'
    end
  end
end
