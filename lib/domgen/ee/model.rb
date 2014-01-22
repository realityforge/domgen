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
  module EE
    class EeExceptionParameter < Domgen.ParentedElement(:parameter)
      include Domgen::Java::EEJavaCharacteristic

      def name
        parameter.name
      end

      protected

      def characteristic
        parameter
      end
    end

    class EeException < Domgen.ParentedElement(:exception)
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.ee.service_package}.#{name}"
      end
    end

    class EeStruct < Domgen.ParentedElement(:struct)
      attr_writer :name

      def name
        @name || struct.name
      end

      def qualified_name
        "#{struct.data_module.ee.data_type_package}.#{self.name}"
      end
    end

    class EebStructField < Domgen.ParentedElement(:field)
      include Domgen::Java::EEJavaCharacteristic

      def name
        field.name
      end

      protected

      def characteristic
        field
      end
    end

    class EeEnumeration < Domgen.ParentedElement(:enumeration)
      def name
        "#{enumeration.name}"
      end

      def qualified_name
        "#{enumeration.data_module.ee.data_type_package}.#{name}"
      end
    end

    class EePackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::EEJavaPackage
    end

    class EeApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::ServerJavaApplication

      def version
        @version || '6'
      end

      def version=(version)
        raise "Unknown version '#{version}'" unless ['6', '7'].include?(version)
        @version = version
      end
    end
  end

  FacetManager.define_facet(:ee,
                            {
                              Exception => Domgen::EE::EeException,
                              ExceptionParameter => Domgen::EE::EeExceptionParameter,
                              Struct => Domgen::EE::EeStruct,
                              StructField => Domgen::EE::EebStructField,
                              EnumerationSet => Domgen::EE::EeEnumeration,
                              DataModule => Domgen::EE::EePackage,
                              Repository => Domgen::EE::EeApplication
                            },
                            [:java])

end
