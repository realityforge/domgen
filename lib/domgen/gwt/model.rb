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
  module GWT
    class GwtEnumeration < Domgen.ParentedElement(:enumeration)
      def name
        "#{enumeration.name}"
      end

      def qualified_name
        "#{enumeration.data_module.gwt.client_data_type_package}.#{name}"
      end
    end

    class GwtStruct < Domgen.ParentedElement(:struct)
      attr_writer :interface_name

      def interface_name
        @interface_name || struct.name.to_s
      end

      def qualified_name
        self.qualified_interface_name
      end

      def qualified_interface_name
        "#{struct.data_module.gwt.client_data_type_package}.#{interface_name}"
      end

      attr_writer :jso_name

      def jso_name
        @jso_name || "Jso#{struct.name}"
      end

      def qualified_jso_name
        "#{struct.data_module.gwt.client_data_type_package}.#{jso_name}"
      end

      attr_writer :java_name

      def java_name
        @java_name || "Java#{struct.name}"
      end

      def qualified_java_name
        "#{struct.data_module.gwt.client_data_type_package}.#{java_name}"
      end

      def factory_name
        "#{struct.name}Factory"
      end

      def qualified_factory_name
        "#{struct.data_module.gwt.client_data_type_package}.#{self.factory_name}"
      end
    end

    class GwtStructField < Domgen.ParentedElement(:field)
      include Domgen::Java::ImitJavaCharacteristic

      def name
        field.name
      end

      protected

      def characteristic
        field
      end
    end

    class GwtEvent < Domgen.ParentedElement(:message)
      attr_writer :event_name

      def event_name
        @event_name || "#{message.name}Event"
      end

      def qualified_event_name
        "#{message.data_module.gwt.client_event_package}.#{event_name}"
      end

      attr_writer :event_handler_name

      def event_handler_name
        @event_handler_name || "#{event_name}Handler"
      end

      def qualified_event_handler_name
        "#{message.data_module.gwt.client_event_package}.#{event_handler_name}"
      end
    end

    class GwtEventParameter < Domgen.ParentedElement(:parameter)
      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    class GwtModule < Domgen.ParentedElement(:data_module)
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

    class GwtReturn < Domgen.ParentedElement(:result)

      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    class GwtApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::JavaClientServerApplication

      attr_writer :client_event_package

      def client_event_package
        @client_event_package || "#{client_package}.event"
      end

      protected

      def facet_key
        :gwt
      end
    end
  end

  FacetManager.define_facet(:gwt,
                            {
                              EnumerationSet => Domgen::GWT::GwtEnumeration,
                              Struct => Domgen::GWT::GwtStruct,
                              StructField => Domgen::GWT::GwtStructField,
                              Message => Domgen::GWT::GwtEvent,
                              MessageParameter => Domgen::GWT::GwtEventParameter,
                              DataModule => Domgen::GWT::GwtModule,
                              Repository => Domgen::GWT::GwtApplication
                            },
                            [:java])
end
