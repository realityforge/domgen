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
  FacetManager.facet(:restygwt => [:gwt, :jaxrs]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      attr_writer :module_name

      def module_name
        @module_name || Reality::Naming.underscore(repository.name)
      end

      def client_ioc_package
        repository.gwt.client_ioc_package
      end

      java_artifact :services_module, :ioc, :client, :gwt, '#{repository.name}RestyGwtServicesModule'

      protected

      def facet_key
        :gwt
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::ClientServerJavaPackage

      protected

      def facet_key
        :gwt
      end
    end

    facet.enhance(Exception) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :name, :data_type, :client, :gwt, '#{exception.name}Exception'
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :facade_service, :service, :client, :gwt, '#{service.name}'
      java_artifact :proxy, :service, :client, :gwt, '#{facade_service}Proxy'
      java_artifact :service, :service, :client, :gwt, 'RestGwt#{service.name}'
    end

    facet.enhance(Parameter) do
      include Domgen::Java::ImitJavaCharacteristic

      # Does the parameter come from the environment?
      def environmental?
        !!@environment_key
      end

      attr_reader :environment_key

      def environment_key=(environment_key)
        Domgen.error("Unknown environment_key #{environment_key}") unless self.class.environment_key_set.include?(environment_key)
        @environment_key = environment_key
      end

      def environment_value
        raise 'environment_value invoked for non-environmental value' unless environmental?
        self.class.environment_key_set[environment_key]
      end

      def self.environment_key_set
        {
          'request:session:id' => 'getThreadLocalRequest().getSession(true).getId()',
          'request:permutation-strong-name' => 'getPermutationStrongName()',
          'request:locale' => 'getThreadLocalRequest().getLocale().toString()',
          'request:remote-host' => 'getThreadLocalRequest().getRemoteHost()',
          'request:remote-address' => 'getThreadLocalRequest().getRemoteAddr()',
          'request:remote-port' => 'getThreadLocalRequest().getRemotePort()',
          'request:remote-user' => 'getThreadLocalRequest().getRemoteUser()',
        }
      end

      protected

      def characteristic
        parameter
      end
    end

    facet.enhance(Result) do
      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        result
      end
    end
  end
end
