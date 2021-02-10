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
  module Appconfig
    class SystemSetting < Domgen.ParentedElement(:appconfig_repository)
      attr_reader :key

      def initialize(appconfig_repository, key, options = {}, &block)
        @key = key
        raise "Supplied key for system_setting has non alphanumeric and non underscore characters. key = '#{key}'" unless key.to_s.gsub(/[^0-9A-Za-z_]/, '') == key.to_s
        appconfig_repository.send(:register_system_setting, self)
        super(appconfig_repository, options, &block)
      end

      attr_writer :key_value

      # Key used to access flag in database
      def key_value
        @key_value.nil? ? self.key.to_s : @key_value
      end

      attr_writer :initial_value

      # Initial value set during database import if not already set
      def initial_value
        @initial_value
      end

      attr_writer :feature_flag

      def feature_flag?
        @feature_flag.nil? ? false : !!@feature_flag
      end
    end
  end

  FacetManager.facet(:appconfig) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :feature_flag_container, nil, :shared, :appconfig, '#{repository.name}FeatureFlags'
      java_artifact :system_setting_container, nil, :shared, :appconfig, '#{repository.name}SystemSettings'

      attr_writer :short_test_code

      def short_test_code
        @short_test_code || 'ac'
      end

      attr_writer :all_settings_defined

      def all_settings_defined?
        @all_settings_defined.nil? ? true : !!@all_settings_defined
      end

      def system_setting(key, options = {}, &block)
        Domgen::Appconfig::SystemSetting.new(self, key, options, &block)
      end

      def feature_flag(key, options = {}, &block)
        system_setting(key, {:initial_value => true}.merge(options.merge(:feature_flag => true)), &block)
      end

      def system_setting_by_name?(key)
        system_setting_map[key.to_s]
      end

      def system_setting_by_name(key)
        system_setting = system_setting_map[key.to_s]
        Domgen.error("Unable to locate feature flag #{key}") unless system_setting
        system_setting
      end

      def feature_flags?
        system_settings.any?{|s| s.feature_flag?}
      end

      def system_settings?
        system_setting_map.size > 0
      end

      def system_settings
        system_setting_map.values
      end

      def pre_complete
        repository.jaxrs.extensions << 'iris.appconfig.server.rest.SystemSettingRestService' if repository.jaxrs?
      end

      def pre_verify
        if repository.jpa?
          repository.jpa.application_artifact_fragments << "iris.appconfig#{repository.pgsql? ? '.pg' : ''}:app-config-server"
          repository.jpa.add_test_factory(short_test_code, 'iris.appconfig.server.test.util.AppConfigFactory')
          repository.jpa.add_test_module('AppConfigPersistenceTestModule', 'iris.appconfig.server.test.util.AppConfigPersistenceTestModule')
          repository.jpa.add_test_module('AppConfigRepositoryModule', 'iris.appconfig.server.test.util.AppConfigRepositoryModule')
          repository.jpa.add_flushable_test_module('AppConfigServicesModule', 'iris.appconfig.server.test.util.AppConfigServicesModule')
        end
      end

      protected

      def register_system_setting(system_setting)
        Domgen.error("Attempting to redefine system setting '#{system_setting.key}'") if system_setting_map[system_setting.key.to_s]
        system_setting_map[system_setting.key.to_s] = system_setting
      end

      def system_setting_map
        @system_setting ||= {}
      end
    end
  end
end
