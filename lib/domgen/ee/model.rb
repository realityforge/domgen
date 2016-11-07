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
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      def version
        @version || '7'
      end

      def use_cdi=(use_cdi)
        @use_cdi = use_cdi
      end

      def use_cdi?
        @use_cdi.nil? ? true : false
      end

      def bean_discovery_mode=(mode)
        Domgen.error("Unknown bean discovery mode '#{mode}'") unless %w(all annotated none).include?(mode)
        @bean_discovery_mode = mode
      end

      def bean_discovery_mode
        @bean_discovery_mode ||= 'annotated'
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

      def beans_xml_content_fragments
        @beans_xml_content_fragments ||= []
      end

      def beans_xml_fragments
        @beans_xml_fragments ||= []
      end

      def resolved_beans_xml_fragments
        self.beans_xml_fragments.collect do |fragment|
          repository.read_file(fragment)
        end
      end

      attr_writer :server_event_package

      def server_event_package
        @server_event_package || "#{server_package}.event"
      end


      def version=(version)
        Domgen.error("Unknown version '#{version}'") unless %w(6 7).include?(version)
        @version = version
      end

      java_artifact :abstract_filter, :filter, :server, :ee, 'Abstract#{repository.name}Filter'
      java_artifact :abstract_app_server, :test, :server, :ee, 'Abstract#{repository.name}AppServer', :sub_package => 'util'
      java_artifact :app_server_factory, :test, :server, :ee, '#{repository.name}AppServerFactory', :sub_package => 'util'
      java_artifact :abstract_integration_test, :test, :server, :ee, 'Abstract#{repository.name}GlassFishTest', :sub_package => 'util'
      java_artifact :deploy_test, :test, :server, :ee, '#{repository.name}DeployTest', :sub_package => 'util'

      def qualified_base_integration_test_name
        "#{server_util_test_package}.#{base_integration_test_name}"
      end

      attr_writer :base_integration_test_name

      def base_integration_test_name
        @base_integration_test_name || abstract_integration_test_name.gsub(/^Abstract/,'')
      end

      def qualified_app_server_name
        "#{server_util_test_package}.#{app_server_name}"
      end

      attr_writer :app_server_name

      def app_server_name
        @app_server_name || abstract_app_server_name.gsub(/^Abstract/,'')
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage

      attr_writer :server_event_package

      def server_event_package
        @server_event_package || resolve_package(:server_event_package)
      end

    end

    facet.enhance(Message) do
      def name
        "#{message.name}"
      end

      def qualified_name
        "#{message.data_module.ee.server_event_package}.#{name}"
      end
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
      def name
        "#{enumeration.name}"
      end

      def qualified_name
        "#{enumeration.data_module.ee.server_data_type_package}.#{name}"
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
