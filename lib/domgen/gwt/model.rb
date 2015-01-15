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
  FacetManager.facet(:gwt => [:java, :json, :jackson]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      attr_writer :client_event_package

      def client_event_package
        @client_event_package || "#{client_package}.event"
      end

      java_artifact :async_callback, :service, :client, :gwt, '#{repository.name}AsyncCallback'
      java_artifact :async_error_callback, :service, :client, :gwt, '#{repository.name}AsyncErrorCallback'

      protected

      def facet_key
        :gwt
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
