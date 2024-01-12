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
  FacetManager.facet(:jws => [:jaxb]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      attr_writer :api_package

      def api_package
        @api_package || "#{repository.java.base_package}.api"
      end

      attr_writer :fake_service_package

      def fake_service_package
        @fake_service_package || "#{repository.java.base_package}.fake"
      end

      java_artifact :constants_container, nil, :shared, :jws, '#{repository.name}JwsConstants'
      java_artifact :handler_resolver, nil, :api, :jws, '#{repository.name}HandlerResolver'

      attr_writer :service_name

      # The name of the service under which web services will be anchored
      def service_name
        @service_name || repository.name
      end

      attr_writer :namespace

      def namespace
        @namespace || "#{repository.xml.base_namespace}/#{service_name}"
      end

      attr_writer :base_url

      def base_url
        @base_url || '/api/soap'
      end

      attr_writer :url

      def url
        @url || "#{base_url}/#{repository.name}"
      end

      def handlers
        @handlers ||= []
      end

      def pre_complete
        repository.ee.cdi_scan_excludes << "#{api_package}.**" if repository.ee?
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage

      def namespace
        @namespace || "#{data_module.repository.jws.namespace}/#{data_module.name}"
      end

      attr_writer :api_package

      def api_package
        @api_package || resolve_package(:api_package, data_module.repository.jws)
      end

      attr_writer :fake_service_package

      def fake_service_package
        @fake_service_package || resolve_package(:fake_service_package, data_module.repository.jws)
      end

      attr_writer :url

      def url
        @url || "#{data_module.repository.jws.url}/#{data_module.name}"
      end

      attr_writer :server_ws_service_package

      def server_ws_service_package
        @server_ws_service_package.nil? ? "#{server_service_package}.ws" : @server_ws_service_package
      end

      attr_writer :server_internal_ws_service_package

      def server_internal_ws_service_package
        @server_internal_ws_service_package.nil? ? "#{server_service_package}.ws.internal" : @server_internal_ws_service_package
      end
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :type_converter, nil, :api, :jws, '#{service.name}TypeConverter'

      def qualified_api_interface_name
        "#{api_package}.#{web_service_name}"
      end

      def qualified_api_endpoint_name
        "#{api_package}.#{web_service_name}Service"
      end

      def api_package
        "#{service.data_module.jws.api_package}.#{Reality::Naming.underscore(web_service_name.gsub(/Service$/, ''))}"
      end

      def boundary_ejb_name
        "#{service.data_module.repository.name}.#{service.data_module.name}.#{service.jws.java_service_name}"
      end

      def qualified_exception_name(exception)
        "#{api_package}.#{exception.ee.name}"
      end

      attr_writer :url

      def url
        @url || "#{service.data_module.jws.url}/#{web_service_name}"
      end

      attr_writer :servlet_name

      def servlet_name
        @servlet_name || "#{service.qualified_name.to_s.gsub('.', '')}Servlet"
      end

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
        @system_id || "#{namespace}.wsdl"
      end

      def namespace
        @namespace || "#{service.data_module.jws.namespace}/#{web_service_name}"
      end

      def referenced_structs
        structs = []

        service.methods.select { |method| method.jws? }.each do |method|
          method.parameters.select { |field| field.struct? }.each do |field|
            structs << field.referenced_struct
          end
          structs << method.return_value.referenced_struct if method.return_value.struct?
        end
        structs = structs.uniq

        to_process = structs.dup
        processed = []

        until to_process.empty?
          struct = to_process.pop
          next if processed.include?(struct)
          processed << struct
          struct.fields.select { |field| field.struct? }.each do |field|
            structs << field.referenced_struct
          end
        end

        structs.uniq
      end

      java_artifact :service, :service, :server, :ee, '#{web_service_name}Service'
      java_artifact :java_service, :service, :server, :jws, '#{web_service_name}WS', :sub_package => 'ws'
      java_artifact :boundary_implementation, :service, :server, :jws, '#{web_service_name}WSBoundaryEJB', :sub_package => 'ws.internal'

      def pre_verify
        jws_active = false
        service.methods.each do |method|
          next unless method.jws?
          jws_active = true
        end
        service.disable_facet(:jws) unless jws_active
      end
    end

    facet.enhance(Method) do
      def name
        Reality::Naming.camelize(method.name)
      end

      def input_action
        "#{method.service.jws.namespace}/#{method.service.jws.web_service_name}/#{method.name}Request"
      end

      def output_action
        "#{method.service.jws.namespace}/#{method.service.jws.web_service_name}/#{method.name}Response"
      end

      # Return true if this methods parameters are all compatible with soap protocol
      def compatible?
        compatible = true

        method.parameters.each do |parameter|
          compatible = false unless characteristic_compatible?(parameter)
          break unless compatible
        end

        compatible = false unless characteristic_compatible?(method.return_value)

        compatible
      end

      def pre_complete
        method.disable_facet(:jws) unless compatible?
      end

      private

      def characteristic_compatible?(characteristic)
        return false unless characteristic.jws?

        return true if !characteristic.characteristic_type.nil? && characteristic.characteristic_type.name == :void
        return false if characteristic.non_standard_type?
        return false if characteristic.enumeration? && !characteristic.enumeration.jws?
        return false if characteristic.reference? && !characteristic.referenced_entity.jws?
        return false if characteristic.struct? && !characteristic.referenced_struct.jws?
        true
      end
    end

    facet.enhance(Parameter) do
      def name
        Reality::Naming.camelize(parameter.name)
      end

      include Domgen::Java::EEJavaCharacteristic

      attr_writer :empty_list_to_null

      def empty_list_to_null?
        @empty_list_to_null.nil? ? false : !!@empty_list_to_null
      end

      def post_verify
        raise "Parameter '#{parameter.qualified_name}' is a nullable collection without 'jws.empty_list_to_null' property set to true. This is unsupported in the jws facet." if parameter.nullable? && parameter.collection? && !empty_list_to_null?
      end

      protected

      def characteristic
        parameter
      end
    end

    facet.enhance(Result) do
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    facet.enhance(Exception) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :fault_info, :service, :server, :jws, '#{exception.name}ExceptionInfo', :sub_package => 'ws'
      java_artifact :name, :service, :server, :jws, '#{exception.name}_Exception', :sub_package => 'ws'

      attr_writer :namespace

      def namespace
        @namespace || exception.data_module.jws.namespace
      end

      def fault_action(method)
        "#{method.service.jws.namespace}/#{method.service.jws.web_service_name}/#{method.name}/Fault/#{exception.jws.name}"
      end
    end
  end
end
