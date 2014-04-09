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
  FacetManager.facet(:ejb => [:ee]) do |facet|
    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :name

      def name
        @name || service.qualified_name
      end

      def service_ejb_name
        "#{service.data_module.repository.name}.#{service.ejb.name}"
      end

      def boundary_name
        "#{name}Boundary"
      end

      def boundary_ejb_name
        "#{service.data_module.repository.name}.#{service.ejb.boundary_name}"
      end

      java_artifact :service, :service, :server, :ee, '#{service.name}'
      java_artifact :boundary_interface, :service, :server, :ee, 'Local#{service_name}Boundary'
      java_artifact :remote_service, :service, :server, :ee, 'Remote#{service_name}'
      java_artifact :boundary_implementation, :service, :server, :ee, '#{service_name}BoundaryEJB', :sub_package => 'internal'

      attr_accessor :boundary_extends

      attr_writer :local

      def local?
        @local.nil? ? true : @local
      end

      def remote=(remote)
        self.local = !remote
      end

      def remote?
        !local?
      end

      attr_accessor :generate_boundary

      def generate_boundary?
        if @generate_boundary.nil?
          return service.jmx? ||
            service.jws? ||
            service.methods.any? { |method| method.parameters.any? { |parameter| parameter.reference? } }
        else
          return @generate_boundary
        end
      end
    end

    facet.enhance(Parameter) do
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    facet.enhance(Result) do
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    facet.enhance(Exception) do
      attr_writer :rollback

      def rollback?
        @rollback.nil? ? true : @rollback
      end
    end
  end
end
