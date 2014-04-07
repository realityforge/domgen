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
      include Domgen::Java::BaseJavaGenerator

      java_artifact :service, :service, :server, :ee, '#{service.name}MXBean'
    end

    class JmxParameter < Domgen.ParentedElement(:parameter)
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    class JmxMethod < Domgen.ParentedElement(:service)
    end

    class JmxReturn < Domgen.ParentedElement(:result)
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    class JmxException < Domgen.ParentedElement(:exception)
    end

    class JmxPackage < Domgen.ParentedElement(:data_module)
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
