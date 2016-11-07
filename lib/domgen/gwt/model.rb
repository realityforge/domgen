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
  module Gwt
    class Entrypoint < Domgen.ParentedElement(:gwt_repository)
      def initialize(gwt_repository, name, options = {}, &block)
        @name = name
        super(gwt_repository, options, &block)
      end

      include Domgen::Java::BaseJavaGenerator

      java_artifact :entrypoint, nil, :client, :gwt, '#{qualified_name}'
      java_artifact :entrypoint_module, :ioc, :client, :gwt, '#{qualified_name}EntrypointModule'
      java_artifact :gwt_module, :modules, nil, :gwt, '#{qualified_name}EntrypointSupport'

      def modules_package
        entrypoint.gwt_repository.modules_package
      end

      def qualified_application_name
        "#{gwt_repository.repository.gwt.client_package}.#{qualified_name}App"
      end

      def qualified_name
        Domgen::Naming.pascal_case(name)
      end

      attr_reader :name
    end
  end

  FacetManager.facet(:gwt => [:java, :json]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      attr_writer :module_name

      def module_name
        @module_name || Domgen::Naming.underscore(repository.name)
      end

      attr_writer :client_event_package

      def client_event_package
        @client_event_package || "#{client_package}.event"
      end

      java_artifact :async_callback, :service, :client, :gwt, '#{repository.name}AsyncCallback'
      java_artifact :async_error_callback, :service, :client, :gwt, '#{repository.name}AsyncErrorCallback'
      java_artifact :abstract_application, nil, :client, :gwt, 'Abstract#{repository.name}App'
      java_artifact :aggregate_module, :ioc, :client, :gwt, '#{repository.name}Module'

      java_artifact :dev_module, :modules, nil, :gwt, '#{repository.name}DevSupport'
      java_artifact :prod_module, :modules, nil, :gwt, '#{repository.name}ProdSupport'
      java_artifact :app_module, :modules, nil, :gwt, '#{repository.name}AppSupport'
      java_artifact :model_module, :modules, nil, :gwt, '#{repository.name}ModelSupport'

      attr_writer :modules_package

      def modules_package
        @modules_package || "#{repository.java.base_package}.modules"
      end

      attr_writer :client_ioc_package

      def client_ioc_package
        @client_ioc_package || "#{client_package}.ioc"
      end

      attr_writer :enable_entrypoints

      def enable_entrypoints?
        @enable_entrypoints.nil? ? true : !!@enable_entrypoints
      end

      def default_entrypoint
        key = Domgen::Naming.underscore(repository.name.to_s)
        entrypoint(key) unless entrypoint_by_name?(key)
        entrypoint_by_key(key)
      end

      def entrypoint_by_name?(name)
        !!entrypoint_map[name.to_s]
      end

      def entrypoint_by_key(name)
        raise "No gwt entrypoint with name #{name} defined." unless entrypoint_map[name.to_s]
        entrypoint_map[name.to_s]
      end

      def entrypoint(name, options = {}, &block)
        raise "Gwt entrypoint with key #{name} already defined." if entrypoint_map[name.to_s]
        entrypoint_map[name.to_s] = Domgen::Gwt::Entrypoint.new(self, name, options, &block)
      end

      def entrypoints
        return [] unless enable_entrypoints?
        entrypoint_map.values
      end

      TargetManager.register_target('gwt.entrypoint', :repository, :gwt, :entrypoints)

      def pre_complete
        if repository.ee?
          repository.ee.cdi_scan_excludes << "#{repository.gwt.client_package}.**"
          repository.ee.cdi_scan_excludes << 'org.realityforge.gwt.**'
          repository.ee.cdi_scan_excludes << 'com.google.web.**'
          repository.ee.cdi_scan_excludes << 'com.google.gwt.**'
        end
      end

      protected

      def facet_key
        :gwt
      end

      private

      def entrypoint_map
        raise "Attempted to retrieve gwt entrypoints on #{repository.name} when entrypoints not defined." unless enable_entrypoints?
        unless @entrypoints
          @entrypoints = {}
          default_entrypoint
        end
        @entrypoints
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::ClientServerJavaPackage

      attr_writer :client_data_type_package

      def client_data_type_package
        @client_data_type_package || resolve_package(:client_data_type_package)
      end

      attr_writer :client_event_package

      def client_event_package
        @client_event_package || resolve_package(:client_event_package)
      end

      protected

      def facet_key
        :gwt
      end
    end

    facet.enhance(Message) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :event, :event, :client, :gwt, '#{message.name}Event'
    end

    facet.enhance(MessageParameter) do
      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    facet.enhance(Struct) do
      include Domgen::Java::BaseJavaGenerator

      # Needed to hook into standard java type resolution code
      def qualified_name
        self.qualified_interface_name
      end

      attr_writer :generate_overlay

      def generate_overlay?
        @generate_overlay.nil? ? true : !!@generate_overlay
      end

      java_artifact :interface, :data_type, :client, :gwt, '#{struct.name}'
      java_artifact :jso, :data_type, :client, :gwt, 'Jso#{struct.name}'
      java_artifact :java, :data_type, :client, :gwt, 'Java#{struct.name}'
      java_artifact :factory, :data_type, :client, :gwt, '#{struct.name}Factory'
    end

    facet.enhance(StructField) do
      include Domgen::Java::ImitJavaCharacteristic

      def name
        field.name
      end

      protected

      def characteristic
        field
      end
    end

    facet.enhance(EnumerationSet) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :name, :data_type, :client, :gwt, '#{enumeration.name}'
    end
  end
end
