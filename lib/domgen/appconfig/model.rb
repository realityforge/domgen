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
    class FeatureFlag < Domgen.ParentedElement(:appconfig_repository)
      attr_reader :key

      def initialize(appconfig_repository, key, options = {}, &block)
        @key = key
        raise "Supplied key for feature flag has non alphanumeric and non underscore characters. key = '#{key}'" unless key.to_s.gsub(/[^0-9A-Za-z_]/, '') == key.to_s
        appconfig_repository.send(:register_feature_flag, self)
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
        @initial_value.nil? ? true : !!@initial_value
      end

      attr_writer :disable_in_integration_test

      def disable_in_integration_test?
        @disable_in_integration_test.nil? ? false : !!@disable_in_integration_test
      end
    end
  end

  FacetManager.facet(:appconfig) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :feature_flag_container, nil, :shared, :appconfig, '#{repository.name}FeatureFlags'
      java_artifact :integration_test, :rest, :server, :appconfig, '#{repository.name}AppconfigTest'

      attr_writer :short_test_code

      def short_test_code
        @short_test_code || 'ac'
      end

      def feature_flag(key, options = {}, &block)
        Domgen::Appconfig::FeatureFlag.new(self, key, options, &block)
      end

      def feature_flag_by_name?(key)
        feature_flag_map[key.to_s]
      end

      def feature_flag_by_name(key)
        feature_flag = feature_flag_map[key.to_s]
        Domgen.error("Unable to locate feature flag #{key}") unless feature_flag
        feature_flag
      end

      def feature_flags?
        feature_flag_map.size > 0
      end

      def feature_flags
        feature_flag_map.values
      end

      def pre_complete
        repository.jaxrs.extensions << 'iris.appconfig.server.rest.SystemSettingRestService' if repository.jaxrs?
        repository.jpa.application_artifact_fragments << "iris.appconfig#{repository.pgsql? ? '.pg': ''}:app-config-server" if repository.jpa?
      end

      protected

      def register_feature_flag(feature_flag)
        Domgen.error("Attempting to redefine feature flag '#{feature_flag.key}'") if feature_flag_map[feature_flag.key.to_s]
        feature_flag_map[feature_flag.key.to_s] = feature_flag
      end

      def feature_flag_map
        @feature_flag ||= Domgen::OrderedHash.new
      end
    end
  end
end
