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
  module GwtRpc
    class GwtService < Domgen.ParentedElement(:service)
      include Domgen::Java::BaseJavaGenerator

      attr_writer :rpc_prefix

      def rpc_prefix
        @rpc_prefix || "GwtRpc"
      end

      attr_writer :facade_prefix

      def facade_prefix
        @facade_prefix || (outer_service? ? "" : "Gwt")
      end

      def outer_service?
        !service.imit?
      end

      def use_autobean_structs?
        service.data_module.facet_enabled?(:auto_bean)
      end

      attr_writer :xsrf_protected

      def xsrf_protected?
        @xsrf_protected.nil? ? false : @xsrf_protected
      end

      attr_writer :facade_service_name

      def facade_service_name
        @facade_service_name || "#{facade_prefix}#{service.name}"
      end

      def qualified_facade_service_name
        "#{outer_service? ? parent.parent.gwt_rpc.client_service_package : parent.parent.gwt_rpc.client_internal_service_package}.#{facade_service_name}"
      end

      java_artifact :proxy, :service, :client, :gwt_rpc, '#{facade_service_name}Impl', :sub_package => 'internal'
      java_artifact :rpc_service, :service, :shared, :gwt_rpc, '#{rpc_prefix}#{service.name}'
      java_artifact :async_rpc_service, :service, :shared, :gwt_rpc, '#{rpc_service_name}Async'
      java_artifact :servlet, :servlet, :server, :gwt_rpc, '#{rpc_service_name}Servlet'
    end

    class GwtMethod < Domgen.ParentedElement(:method)
      def name
        Domgen::Naming.camelize(method.name)
      end

      attr_writer :cancelable

      def cancelable?
        @cancelable.nil? ? false : @cancelable
      end
    end

    class GwtModule < Domgen.ParentedElement(:data_module)
      include Domgen::Java::ClientServerJavaPackage

      attr_writer :server_servlet_package

      def server_servlet_package
        @server_servlet_package || resolve_package(:server_servlet_package)
      end

      protected

      def facet_key
        :gwt_rpc
      end
    end

    class GwtReturn < Domgen.ParentedElement(:result)

      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    class GwtParameter < Domgen.ParentedElement(:parameter)
      include Domgen::Java::ImitJavaCharacteristic

      # Does the parameter come from the environment?
      def environmental?
        !!@environment_key
      end

      attr_reader :environment_key

      def environment_key=(environment_key)
        raise "Unknown environment_key #{environment_key}" unless valid_environment_key?(environment_key)
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
        raise "environment_value invoked for non-environmental value" unless environmental?
        return "findCookie(getThreadLocalRequest(),\"#{environment_key.to_s[15,100]}\")" if environment_key_is_cookie?(environment_key)
        value = self.class.environment_key_set[environment_key]
        return value if value

      end

      def self.environment_key_set
        {
          "request:session:id" => 'getThreadLocalRequest().getSession(true).getId()',
          "request:permutation-strong-name" => 'getPermutationStrongName()',
          "request:locale" => 'getThreadLocalRequest().getLocale().toString()',
          "request:remote-host" => 'getThreadLocalRequest().getRemoteHost()',
          "request:remote-address" => 'getThreadLocalRequest().getRemoteAddr()',
          "request:remote-port" => 'getThreadLocalRequest().getRemotePort()',
          "request:remote-user" => 'getThreadLocalRequest().getRemoteUser()',
        }
      end
      protected

      def characteristic
        parameter
      end
    end

    class GwtException < Domgen.ParentedElement(:exception)
      include Domgen::Java::BaseJavaGenerator

      java_artifact :name, :data_type, :shared, :gwt_rpc, 'GwtRpc#{exception.name}Exception'
    end

    class GwtApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      attr_writer :module_name

      def module_name
        @module_name || Domgen::Naming.underscore(repository.name)
      end

      java_artifact :rpc_services_module, :ioc, :client, :gwt_rpc, '#{repository.name}GwtRpcServicesModule'
      java_artifact :mock_services_module, :ioc, :client, :gwt_rpc, '#{repository.name}MockGwtServicesModule'
      java_artifact :services_module, :ioc, :client, :gwt_rpc, '#{repository.name}GwtServicesModule'

      attr_writer :client_ioc_package

      def client_ioc_package
        @client_ioc_package || "#{client_package}.ioc"
      end

      attr_writer :server_servlet_package

      def server_servlet_package
        @server_servlet_package || "#{server_package}.servlet"
      end

      attr_writer :services_module_name

      protected

      def facet_key
        :gwt
      end
    end
  end

  FacetManager.define_facet(:gwt_rpc,
                            {
                              Service => Domgen::GwtRpc::GwtService,
                              Method => Domgen::GwtRpc::GwtMethod,
                              Parameter => Domgen::GwtRpc::GwtParameter,
                              Result => Domgen::GwtRpc::GwtReturn,
                              Exception => Domgen::GwtRpc::GwtException,
                              DataModule => Domgen::GwtRpc::GwtModule,
                              Repository => Domgen::GwtRpc::GwtApplication
                            }, [:gwt])
end
