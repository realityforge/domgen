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

      def use_autobean_structs?
        service.data_module.facet_enabled?(:auto_bean)
      end

      attr_writer :xsrf_protected

      def xsrf_protected?
        @xsrf_protected.nil? ? false : @xsrf_protected
      end

      attr_writer :facade_service_name

      def facade_service_name
        @facade_service_name || service.name
      end

      def qualified_facade_service_name
        "#{service.data_module.gwt_rpc.client_service_package}.#{facade_service_name}"
      end

      def proxy_name
        "#{facade_service_name}Proxy"
      end

      def qualified_proxy_name
        "#{qualified_facade_service_name}Proxy"
      end

      attr_writer :rpc_service_name

      def rpc_service_name
        @rpc_service_name || "Gwt#{service.name}"
      end

      def qualified_service_name
        "#{service.data_module.gwt_rpc.shared_service_package}.#{rpc_service_name}"
      end

      def async_rpc_service_name
        "#{rpc_service_name}Async"
      end

      def qualified_async_rpc_service_name
        "#{service.data_module.gwt_rpc.shared_service_package}.#{async_rpc_service_name}"
      end

      def servlet_name
        @servlet_name || "#{rpc_service_name}Servlet"
      end

      def qualified_servlet_name
        "#{service.data_module.gwt_rpc.server_servlet_package}.#{servlet_name}"
      end
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
        @server_servlet_package || "#{data_module.repository.gwt_rpc.server_servlet_package}.#{package_key}"
        #@server_servlet_package || "#{parent_facet.server_servlet_package}.#{package_key}"
      end

      protected

      def facet_key
        :gwt
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
        raise "Unknown environment_key #{environment_key}" unless self.class.environment_key_set.include?(environment_key)
        @environment_key = environment_key
      end

      def environment_value
        raise "environment_value invoked for non-environmental value" unless environmental?
        self.class.environment_key_set[environment_key]
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
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.gwt_rpc.shared_data_type_package}.#{name}"
      end
    end

    class GwtApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::JavaClientServerApplication

      attr_writer :module_name

      def module_name
        @module_name || Domgen::Naming.underscore(repository.name)
      end

      attr_writer :rpc_services_module_name

      def rpc_services_module_name
        @rpc_services_module_name || "#{repository.name}GwtRpcServicesModule"
      end

      def qualified_rpc_services_module_name
        "#{client_ioc_package}.#{rpc_services_module_name}"
      end

      attr_writer :mock_services_module_name

      def mock_services_module_name
        @mock_services_module_name || "#{repository.name}MockGwtServicesModule"
      end

      def qualified_mock_services_module_name
        "#{client_ioc_package}.#{mock_services_module_name}"
      end

      attr_writer :client_ioc_package

      def client_ioc_package
        @client_ioc_package || "#{client_package}.ioc"
      end

      attr_writer :server_servlet_package

      def server_servlet_package
        @server_servlet_package || "#{server_package}.servlet"
      end

      attr_writer :services_module_name

      def services_module_name
        @services_module_name || "#{repository.name}GwtServicesModule"
      end

      def qualified_services_module_name
        "#{client_ioc_package}.#{services_module_name}"
      end

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
