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
  module JWS
    class JwsClass < Domgen.ParentedElement(:service)
      attr_writer :port_type_name

      def port_type_name
        @port_type_name || web_service_name
      end

      attr_writer :port_name

      def port_name
        @port_name || "#{web_service_name}Port"
      end

      attr_writer :web_service_name

      def web_service_name
        @web_service_name || service.name.to_s
      end

      attr_writer :wsdl_name

      def wsdl_name
        @wsdl_name || "#{service.data_module.repository.name}/#{service.data_module.name}/#{web_service_name}.wsdl"
      end

      attr_writer :system_id

      def system_id
        @system_id || "#{service.data_module.jws.namespace}/#{web_service_name}.wsdl"
      end

      def namespace
        @namespace || service.data_module.repository.jws.namespace
      end

      attr_writer :service_name

      def service_name
        @service_name || "#{service.name}Service"
      end

      def qualified_service_name
        "#{service.data_module.jws.service_package}.#{service_name}"
      end

      def java_service_name
        "#{web_service_name}WS"
      end

      def qualified_java_service_name
        "#{service.data_module.jws.service_package}.#{java_service_name}"
      end

      def boundary_implementation_name
        "#{web_service_name}WSBoundaryEJB"
      end

      def qualified_boundary_implementation_name
        "#{service.data_module.jws.service_package}.#{boundary_implementation_name}"
      end
    end

    class JwsParameter < Domgen.ParentedElement(:parameter)
      def name
        Domgen::Naming.camelize(parameter.name)
      end

      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    class JwsMethod < Domgen.ParentedElement(:service)
      def name
        Domgen::Naming.camelize(service.name)
      end
    end

    class JwsPackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::EEJavaPackage

      def namespace
        @namespace || "#{data_module.repository.jws.namespace}/#{data_module.name}"
      end
    end

    class JwsApplication < Domgen.ParentedElement(:repository)
      attr_writer :service_name

      # The name of the service under which web services will be anchored
      def service_name
        @service_name || repository.name
      end

      attr_writer :namespace

      def namespace
        @namespace || "#{base_namespace}/#{service_name}"
      end

      attr_writer :base_namespace

      def base_namespace
        @base_namespace || "http://example.com"
      end
    end

    class JwsReturn < Domgen.ParentedElement(:result)

      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    class JwsException < Domgen.ParentedElement(:exception)
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.jws.data_type_package}.#{name}"
      end
    end
  end

  FacetManager.define_facet(:jws,
                            {
                              Service => Domgen::JWS::JwsClass,
                              Method => Domgen::JWS::JwsMethod,
                              Parameter => Domgen::JWS::JwsParameter,
                              Exception => Domgen::JWS::JwsException,
                              Result => Domgen::JWS::JwsReturn,
                              DataModule => Domgen::JWS::JwsPackage,
                              Repository => Domgen::JWS::JwsApplication
                            },
                            [:jaxb])
end
