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
  module JMX
    class JmxClass < Domgen.ParentedElement(:service)
      attr_writer :service_name

      def service_name
        @service_name || "#{service.name}MXBean"
      end

      def qualified_service_name
        "#{service.data_module.jmx.service_package}.#{service_name}"
      end
    end

    class JmxParameter < Domgen.ParentedElement(:parameter)
      def name
        Domgen::Naming.camelize(parameter.name)
      end

      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    class JmxMethod < Domgen.ParentedElement(:service)
      def name
        Domgen::Naming.camelize(service.name)
      end
    end

    class JmxReturn < Domgen.ParentedElement(:result)
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    class JmxException < Domgen.ParentedElement(:exception)
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.jmx.data_type_package}.#{name}"
      end
    end

    class JmxPackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::EEJavaPackage
    end

    class JmxApplication < Domgen.ParentedElement(:repository)
      attr_writer :domain_name

      def domain_name
        @domain_name || repository.name
      end
    end
  end

  FacetManager.define_facet(:jmx,
                            {
                              Service => Domgen::JMX::JmxClass,
                              Method => Domgen::JMX::JmxMethod,
                              Parameter => Domgen::JMX::JmxParameter,
                              Exception => Domgen::JMX::JmxException,
                              Result => Domgen::JMX::JmxReturn,
                              DataModule => Domgen::JMX::JmxPackage,
                              Repository => Domgen::JMX::JmxApplication
                            },
                            [:java])
end
