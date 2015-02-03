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
  FacetManager.facet(:ee => [:java]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::JavaClientServerApplication

      def version
        @version || '7'
      end

      def use_cdi=(use_cdi)
        @use_cdi = use_cdi
      end

      def use_cdi?
        !!@use_cdi
      end

      attr_writer :server_event_package

      def server_event_package
        @server_event_package || "#{server_package}.event"
      end


      def version=(version)
        Domgen.error("Unknown version '#{version}'") unless %w(6 7).include?(version)
        @version = version
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
