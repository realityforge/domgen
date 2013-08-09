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
  module RestGWT
    class RestGwtService < Domgen.ParentedElement(:service)
      attr_writer :facade_service_name

      def facade_service_name
        @facade_service_name || service.name
      end

      def qualified_facade_service_name
        "#{service.data_module.gwt.client_service_package}.#{facade_service_name}"
      end

      def proxy_name
        "#{facade_service_name}Proxy"
      end

      def qualified_proxy_name
        "#{qualified_facade_service_name}Proxy"
      end

      attr_writer :service_name

      def service_name
        @service_name || "RestGwt#{service.name}"
      end

      def qualified_service_name
        "#{service.data_module.gwt.client_service_package}.#{service_name}"
      end
    end

    class RestGwtMethod < Domgen.ParentedElement(:method)
      def name
        Domgen::Naming.camelize(method.name)
      end
    end

    class RestGwtModule < Domgen.ParentedElement(:data_module)
      include Domgen::Java::ClientServerJavaPackage

      attr_writer :server_servlet_package

      def server_servlet_package
        @server_servlet_package || "#{parent_facet.server_servlet_package}.#{package_key}"
      end

      protected

      def facet_key
        :gwt
      end
    end

    class RestGwtReturn < Domgen.ParentedElement(:result)

      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    class RestGwtParameter < Domgen.ParentedElement(:parameter)
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

    class RestGwtException < Domgen.ParentedElement(:exception)
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.gwt.client_data_type_package}.#{name}"
      end
    end

    class RestGwtApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::JavaClientServerApplication

      attr_writer :module_name

      def module_name
        @module_name || Domgen::Naming.underscore(repository.name)
      end

      attr_writer :client_ioc_package

      def client_ioc_package
        @client_ioc_package || "#{client_package}.ioc"
      end

      attr_writer :services_module_name

      def services_module_name
        @services_module_name || "#{repository.name}RestyGwtServicesModule"
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

  FacetManager.define_facet(:restygwt,
                            {
                              Service => Domgen::RestGWT::RestGwtService,
                              Method => Domgen::RestGWT::RestGwtMethod,
                              Parameter => Domgen::RestGWT::RestGwtParameter,
                              Exception => Domgen::RestGWT::RestGwtException,
                              Result => Domgen::RestGWT::RestGwtReturn,
                              DataModule => Domgen::RestGWT::RestGwtModule,
                              Repository => Domgen::RestGWT::RestGwtApplication
                            }, [:gwt, :jaxrs])
end
