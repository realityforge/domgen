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
  FacetManager.facet(:berk) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :abstract_environment_service, :service, :server, :berk, 'Abstract#{repository.name}EnvironmentServiceImpl'
      java_artifact :standard_environment_service, :service, :server, :berk, '#{repository.name}EnvironmentServiceImpl'
      java_artifact :test_module, :service, :server, :berk, '#{repository.name}BerkTestModule'

      attr_writer :custom_environment_service

      def custom_environment_service?
        @custom_environment_service.nil? ? false : !!@custom_environment_service
      end

      attr_writer :short_test_code

      def short_test_code
        @short_test_code || 'bs'
      end

      attr_writer :jndi_env_base

      def jndi_env_base
        @jndi_env_base || "#{Reality::Naming.underscore(repository.name)}/env/setting"
      end

      def pre_complete
        if repository.gwt?
          repository.gwt.add_test_module('BerkSettingsManagerModule', 'iris.berk.client.test.util.SettingsManagerModule')
          repository.gwt.add_test_module('BerkMockGwtServicesModule', 'iris.berk.client.test.util.BerkMockGwtServicesModule')
          repository.gwt.add_ux_test_factory(short_test_code, 'iris.berk.client.test.util.BerkStructFactory')
          repository.gwt.add_gin_module('BerkModule', 'iris.berk.client.ioc.BerkModule')
        end
        if repository.ejb?
          repository.ejb.add_test_module(self.test_module_name, self.qualified_test_module_name)
        end
      end
    end
  end
end
