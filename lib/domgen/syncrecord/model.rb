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
  module Syncrecord
    class DataSource < Domgen.ParentedElement(:syncrecord_repository)
      attr_reader :key

      def initialize(syncrecord_repository, key, options = {}, &block)
        @key = key
        raise "Supplied key for datasource has non alphanumeric and non underscore characters. key = '#{key}'" unless key.to_s.gsub(/[^0-9A-Za-z_]/, '') == key.to_s
        syncrecord_repository.send(:register_data_source, self)
        super(syncrecord_repository, options, &block)
      end

      attr_writer :key_value

      # Key used to access flag in database
      def key_value
        @key_value.nil? ? self.key.to_s : @key_value
      end
    end
  end

  FacetManager.facet(:syncrecord => [:appconfig]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :datasources, nil, :shared, :syncrecord, '#{repository.name}DataSources'
      java_artifact :sync_record_locks, :service, :server, :syncrecord, '#{repository.name}SyncRecordLocks'
      java_artifact :control_rest_service, :rest, :server, :syncrecord, '#{repository.name}SyncControlRestService'
      java_artifact :test_module, :test, :server, :syncrecord, '#{repository.name}SyncRecordTestModule', :sub_package => 'util'

      attr_writer :short_test_code

      def short_test_code
        @short_test_code || 'sr'
      end

      def data_source(key, options = {}, &block)
        Domgen::Syncrecord::DataSource.new(self, key, options, &block)
      end

      def data_source_by_name?(key)
        data_source_map[key.to_s]
      end

      def data_source_by_name(key)
        data_source = data_source_map[key.to_s]
        Domgen.error("Unable to locate data source #{key}") unless data_source
        data_source
      end

      def data_sources?
        data_source_map.size > 0
      end

      def data_sources
        data_source_map.values
      end

      def sync_methods?
        self.sync_methods.size > 0
      end

      def sync_methods
        repository.data_modules.select { |d| d.syncrecord? }.collect do |data_module|
          data_module.services.select { |s| s.syncrecord? }.collect do |service|
            service.syncrecord.sync_methods
          end
        end.flatten
      end

      attr_writer :keycloak_client

      def keycloak_client
        @keycloak_client || (repository.application? && !repository.application.user_experience? ? repository.keycloak.default_client.key : :api)
      end

      def pre_complete
        if repository.jaxrs?
          repository.jaxrs.extensions << 'iris.syncrecord.server.rest.SyncStatusService'
          if repository.syncrecord.sync_methods?
            repository.jaxrs.extensions << repository.syncrecord.qualified_control_rest_service_name
          end
        end
        if repository.keycloak?
          client =
            repository.keycloak.client_by_key?(self.keycloak_client) ?
              repository.keycloak.client_by_key(self.keycloak_client) :
              repository.keycloak.client(self.keycloak_client)
          client.protected_url_patterns << "/#{repository.jaxrs? ? repository.jaxrs.path : 'api'}/sync/*"
        end

        if repository.jpa?
          repository.jpa.application_artifact_fragments << "iris.syncrecord#{repository.pgsql? ? '.pg' : ''}:sync-record-server"
          repository.jpa.add_test_factory(short_test_code, 'iris.syncrecord.server.test.util.SyncRecordFactory')
        end
      end

      def pre_verify
        if repository.ejb?
          if repository.syncrecord.sync_methods?
            repository.ejb.add_test_module(self.test_module_name, self.qualified_test_module_name)
          end
          repository.ejb.add_flushable_test_module('SyncRecordServicesModule', 'iris.syncrecord.server.test.util.SyncRecordServicesModule')
          repository.jpa.add_test_module('SyncRecordPersistenceTestModule', 'iris.syncrecord.server.test.util.SyncRecordPersistenceTestModule')
          repository.jpa.add_test_module('SyncRecordRepositoryModule', 'iris.syncrecord.server.test.util.SyncRecordRepositoryModule')
        end
      end

      protected

      def register_data_source(data_source)
        Domgen.error("Attempting to redefine data source '#{data_source.key}'") if data_source_map[data_source.key.to_s]
        data_source_map[data_source.key.to_s] = data_source
      end

      def data_source_map
        @data_sources ||= {}
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :abstract_service, :service, :server, :syncrecord, 'Abstract#{service.name}Impl'

      def sync_methods?
        self.sync_methods.size > 0
      end

      def sync_methods
        service.methods.select { |m| m.syncrecord? && m.syncrecord.sync? }
      end

      def multi_sync?
        @multi_sync.nil? ? false : @multi_sync
      end

      attr_writer :multi_sync

      def extends
        self.custom_extends || "iris.syncrecord.server.service.#{multi_sync? ? 'StandardMultiSyncService' : 'StandardSyncService'}"
      end

      attr_accessor :custom_extends
    end

    facet.enhance(Method) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :sync

      def sync?
        @sync.nil? ? false : !!@sync
      end

      def lock_name=(lock_name)
        self.sync = true
        @lock_name = lock_name
      end

      def lock_name
        @lock_name || method.qualified_name.to_s.gsub('#', '.')
      end

      def data_source_is_parameter?
        !method.parameters.empty?
      end

      def data_source
        raise "Attempted to access data_source on #{method.qualified_name} when method is not a sync method" unless sync?
        raise "Attempted to access data_source on #{method.qualified_name} when data_source is specified by parameter" if data_source_is_parameter?
        @data_source ||= data_source_by_name(method.qualified_name.to_s.gsub('#', '.'))
      end

      def data_source=(data_source)
        self.sync = true
        @data_source = data_source_by_name(data_source)
      end

      def feature_flag
        raise "Attempted to access feature_flag on #{method.qualified_name} when method is not a sync method" unless sync?
        @feature_flag ||= feature_flag_by_name(method.qualified_name.to_s.gsub('#', '.'))
      end

      def feature_flag=(feature_flag)
        self.sync = true
        @feature_flag = feature_flag_by_name(feature_flag)
      end

      protected

      def pre_verify
        unless sync?
          method.disable_facet(:syncrecord)
          return
        end

        # For creation of feature flag if not explicitly specified
        self.feature_flag
        # For creation of data source if not explicitly specified
        self.data_source unless data_source_is_parameter?
      end

      def perform_verify
        if method.return_value.return_type.to_s != 'iris.syncrecord.server.data_type.SyncStatusDTO'
          Domgen.error("Expected return type of #{method.qualified_name} to be 'iris.syncrecord.server.data_type.SyncStatusDTO' as it is syncrecord.sync method. Actual return type is '#{method.return_value.return_type}'")
        end
        if method.exceptions.size != 0
          Domgen.error("Expected no exceptions on #{method.qualified_name} as it is syncrecord.sync method.")
        end
        if method.parameters.size > 1 || (method.parameters.size == 1 && method.parameters[0].parameter_type != :text)
          Domgen.error("Expected 0 parameters or one parameter specifying data source on #{method.qualified_name} as it is syncrecord.sync method.")
        end
      end

      def data_source_by_name(data_source)
        syncrecord = method.data_module.repository.syncrecord
        name = data_source.to_s.gsub(/[#.]/, '_')
        syncrecord.data_source_by_name?(name) ? syncrecord.data_source_by_name(name) : syncrecord.data_source(name, :key_value => data_source)
      end

      def feature_flag_by_name(feature_flag)
        appconfig = method.data_module.repository.appconfig
        name = feature_flag.to_s.gsub(/[#.]/, '_')
        feature_flag = appconfig.system_setting_by_name?(name) ? appconfig.system_setting_by_name(name) : appconfig.feature_flag(name, :key_value => feature_flag)
        Domgen.error("Feature flag '#{feature_flag}' referenced by #{method.qualified_name} is not a feature flag but a system setting") unless feature_flag.feature_flag?
        feature_flag
      end
    end
  end
end
