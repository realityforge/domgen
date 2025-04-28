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
  FacetManager.facet(:ee => [:application, :java]) do |facet|
    facet.suggested_facets << :redfish

    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      def add_custom_jndi_resource(name)
        custom_jndi_resources[name] = Reality::Naming.uppercase_constantize(name.gsub(/^#{Reality::Naming.underscore(repository.name)}\/env\//,'').gsub(/^#{Reality::Naming.underscore(repository.name)}\//,'').gsub('/','_'))
      end

      def custom_jndi_resources?
        !custom_jndi_resources.empty?
      end

      def custom_jndi_resources
        (@custom_jndi_resources ||= {})
      end

      def version
        @version || '7'
      end

      attr_writer :web_metadata_complete

      def web_metadata_complete?
        @web_metadata_complete.nil? ? false : @web_metadata_complete
      end

      def web_xml_content_fragments
        @web_xml_content_fragments ||= []
      end

      def web_xml_fragments
        @web_xml_fragments ||= []
      end

      def resolved_web_xml_fragments
        self.web_xml_fragments.collect do |fragment|
          repository.read_file(fragment)
        end
      end

      def cdi_scan_excludes
        @cdi_scan_excludes ||= []
      end

      # A beans.xml is created in both the model and server components
      ['', 'model_'].each do |prefix|
        class_eval <<-RUBY
          def #{prefix}bean_discovery_mode=(mode)
            Domgen.error("Unknown \#{prefix}bean discovery mode '\#{mode}'") unless %w(all annotated none).include?(mode)
            @#{prefix}bean_discovery_mode = mode
          end

          def #{prefix}bean_discovery_mode
            @#{prefix}bean_discovery_mode ||= 'annotated'
          end

          def #{prefix}beans_xml_content_fragments
            @#{prefix}beans_xml_content_fragments ||= []
          end

          def #{prefix}beans_xml_fragments
            @#{prefix}beans_xml_fragments ||= []
          end

          def resolved_#{prefix}beans_xml_fragments
            self.#{prefix}beans_xml_fragments.collect do |fragment|
              repository.read_file(fragment)
            end
          end
        RUBY
      end

      attr_writer :server_event_package

      def server_event_package
        @server_event_package || "#{server_package}.event"
      end

      def version=(version)
        Domgen.error("Unknown version '#{version}'") unless %w(6 7).include?(version)
        @version = version
      end

      java_artifact :aggregate_data_type_test, :test, :server, :ee, '#{repository.name}AggregateDataTypeTest', :sub_package => 'util'
      java_artifact :jndi_resource_constants, nil, :server, :ee, '#{repository.name}JndiConstants'
      java_artifact :message_module, :test, :server, :ee, '#{repository.name}MessagesModule', :sub_package => 'util'
    end

    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage

      attr_writer :server_event_package

      def server_event_package
        @server_event_package || resolve_package(:server_event_package)
      end

      attr_writer :support_default_parameters

      def support_default_parameters?
        @support_default_parameters.nil? ? false : !!@support_default_parameters
      end
    end

    facet.enhance(Message) do
      include Domgen::Java::BaseJavaGenerator

      def name
        "#{message.name}"
      end

      def qualified_name
        "#{message.data_module.ee.server_event_package}.#{name}"
      end

      attr_writer :generate_test_literal

      def generate_test_literal?
        @generate_test_literal.nil? ? true : !!@generate_test_literal
      end

      attr_writer :module_local

      def module_local?
        @module_local.nil? ? false : !!@module_local
      end

      java_artifact :message_literal, :test, :server, :ee, '#{message.name}TypeLiteral', :sub_package => 'util'
    end

    facet.enhance(MessageParameter) do
      include Domgen::Java::EEJavaCharacteristic

      def name
        parameter.name
      end

      protected

      def characteristic
        parameter
      end
    end

    facet.enhance(EnumerationSet) do
      include Domgen::Java::BaseJavaGenerator

      def name
        "#{enumeration.name}"
      end

      def qualified_name
        "#{enumeration.data_module.ee.server_data_type_package}.#{name}"
      end

      def interfaces
        @interfaces ||= []
      end

      java_artifact :abstract_enumeration_test, :data_type, :server, :ee, 'Abstract#{enumeration.name}Test'
      java_artifact :enumeration_test, :data_type, :server, :ee, '#{enumeration.name}Test'

      attr_writer :module_local

      def module_local?
        @module_local.nil? ? false : !!@module_local
      end
    end

    facet.enhance(Struct) do
      attr_writer :name

      def name
        @name || struct.name
      end

      def qualified_name
        "#{struct.data_module.ee.server_data_type_package}.#{self.name}"
      end

      attr_writer :module_local

      def module_local?
        @module_local.nil? ? false : !!@module_local
      end
    end

    facet.enhance(StructField) do
      include Domgen::Java::EEJavaCharacteristic

      def name
        field.name
      end

      protected

      def characteristic
        field
      end
    end

    facet.enhance(Exception) do
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.ee.server_service_package}.#{name}"
      end

      attr_writer :module_local

      def module_local?
        @module_local.nil? ? false : !!@module_local
      end

      def non_module_local_parent_qualified_name
        e = self.exception
        while e
          return e.ee.qualified_name unless module_local?
          e = e.extends.nil? ? nil : e.data_module.exception_by_name(e.extends)
        end
        return self.exception.java.standard_extends
      end

      attr_writer :support_default_parameters

      def support_default_parameters?
        @support_default_parameters.nil? ? exception.data_module.ee.support_default_parameters? : !!@support_default_parameters
      end
    end

    facet.enhance(ExceptionParameter) do
      include Domgen::Java::EEJavaCharacteristic

      def name
        parameter.name
      end

      protected

      def characteristic
        parameter
      end
    end
  end
end
