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
  module AutoBean
    class AutoBeanStruct < Domgen.ParentedElement(:struct)
      attr_writer :name

      def name
        @name || struct.name
      end

      def qualified_name
        "#{struct.data_module.auto_bean.data_type_package}.#{self.name}"
      end
    end

    class AutoBeanbStructField < Domgen.ParentedElement(:field)
      include Domgen::Java::ImitJavaCharacteristic

      def name
        field.name
      end

      protected

      def characteristic
        field
      end
    end

    class AutoBeanEnumeration < Domgen.ParentedElement(:enumeration)
      def name
        "#{enumeration.name}"
      end

      def qualified_name
        "#{enumeration.data_module.auto_bean.data_type_package}.#{name}"
      end
    end

    class AutoBeanPackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::ImitJavaPackage
    end

    class AutoBeanApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::ClientJavaApplication

      def factory_name
        "#{repository.name}Factory"
      end

      def qualified_factory_name
        "#{repository.auto_bean.data_type_package}.#{self.factory_name}"
      end
    end
  end

  FacetManager.define_facet(:auto_bean,
                            {
                              Struct => Domgen::AutoBean::AutoBeanStruct,
                              StructField => Domgen::AutoBean::AutoBeanbStructField,
                              EnumerationSet => Domgen::AutoBean::AutoBeanEnumeration,
                              DataModule => Domgen::AutoBean::AutoBeanPackage,
                              Repository => Domgen::AutoBean::AutoBeanApplication
                            },
                            [:json])

end
