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
  module Sync
    VALID_MASTER_FACETS = [:application, :sql, :mssql, :pgsql, :ee, :ejb, :java, :jpa, :sync, :syncrecord, :appconfig]
    VALID_SYNC_TEMP_FACETS = [:application, :sql, :mssql, :pgsql, :sync, :syncrecord, :appconfig]
  end

  FacetManager.facet(:sync => [:syncrecord, :sql]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :test_module, :test, :server, :sync, '#{repository.name}SyncServerModule', :sub_package => 'util'
      java_artifact :remote_sync_service, :service, :client, :sync, 'Remote#{repository.name}SyncService'
      java_artifact :remote_sync_service_impl, :service, :client, :sync, 'AbstractRemote#{repository.name}SyncServiceImpl'

      def standalone=(standalone)
        @standalone = standalone
      end

      # Return false if the Data => SyncTemp && SyncTemp => Master stages occurs in a separate process
      def standalone?
        @standalone.nil? ? true : !!@standalone
      end

      attr_writer :mapping_source_attribute

      def mapping_source_attribute
        @mapping_source_attribute || 'MappingSource'
      end

      attr_writer :master_data_module

      def master_data_module
        @master_data_module || 'Master'
      end

      attr_writer :sync_temp_data_module

      def sync_temp_data_module
        @sync_temp_data_module || 'SyncTemp'
      end

      def sync_out_of_master?
        @sync_out_of_master.nil? ? true : !!@sync_out_of_master
      end

      attr_writer :sync_out_of_master

      def pre_pre_complete
        unless repository.data_module_by_name?(self.master_data_module)
          repository.data_module(self.master_data_module)
        end
        master_data_module = repository.data_module_by_name(self.master_data_module)
        master_data_module.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)
        master_data_module.sync.master_sync_persistent_unit = nil unless self.standalone?

        unless repository.data_module_by_name?(self.sync_temp_data_module)
          repository.data_module(self.sync_temp_data_module)
        end

        master_data_module.entity(self.mapping_source_attribute) do |t|
          t.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS + [:transaction_time])
          t.sync.synchronize = false
          t.enable_facet(:transaction_time)
          t.string(:Code, 5, :primary_key => true)
        end unless master_data_module.entity_by_name?(self.mapping_source_attribute)
      end

      def pre_complete
        master_data_module = repository.data_module_by_name(self.master_data_module)

        master_data_module.service(:SyncTempPopulationService) do |s|
          s.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)
          if s.ejb?
            s.ejb.generate_boundary = false
            s.ejb.bind_in_tests = false
            s.ejb.generate_base_test = false
          end

          s.method(:PreSync) do |m|
            m.text(:MappingSourceCode)
          end
          s.method(:PostSync) do |m|
            m.text(:MappingSourceCode)
          end

          master_data_module.sync.entities_to_synchronize.collect do |entity|
            s.method("Count#{entity.qualified_name.gsub('.', '')}") do |m|
              m.text(:MappingSourceCode)
              m.returns(:integer)
            end
            s.method("Verify#{entity.qualified_name.gsub('.', '')}") do |m|
              m.text(:MappingSourceCode)
              m.parameter(:Recorder, 'iris.syncrecord.server.service.SynchronizationRecorder')
            end
            s.method("Populate#{entity.qualified_name.gsub('.', '')}") do |m|
              m.text(:MappingSourceCode)
              m.datetime(:At)
              m.parameter(:Recorder, 'iris.syncrecord.server.service.SynchronizationRecorder')
            end
            s.method("Reset#{entity.qualified_name.gsub('.', '')}") do |m|
              m.text(:MappingSourceCode)
              m.datetime(:At)
              m.parameter(:Recorder, 'iris.syncrecord.server.service.SynchronizationRecorder')
            end
            s.method("Finalize#{entity.qualified_name.gsub('.', '')}") do |m|
              m.text(:MappingSourceCode)
              m.datetime(:At)
              m.parameter(:Recorder, 'iris.syncrecord.server.service.SynchronizationRecorder')
            end
          end
        end unless master_data_module.service_by_name?(:SyncTempPopulationService)

        if self.sync_out_of_master?
          master_data_module.service(:SynchronizationService) do |s|
            s.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)
            s.ejb.generate_boundary = false if s.ejb?
            s.method(:SynchronizeDataSource) do |m|
              m.text(:MappingSourceCode)
              m.returns('iris.syncrecord.server.data_type.SyncStatusDTO')
            end
          end unless master_data_module.service_by_name?(:SynchronizationService)

          unless master_data_module.exception_by_name?(:BadSyncSequence)
            master_data_module.exception(:BadSyncSequence, 'java.exception_category' => :runtime) do |e|
              e.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)
            end
          end

          master_data_module.service(:SynchronizationContext) do |s|
            s.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)
            if s.ejb?
              s.ejb.generate_boundary = true
              s.ejb.generate_base_test = false
            end

            s.method(:PreSync) do |m|
              m.parameter(:Recorder, 'iris.syncrecord.server.service.SynchronizationRecorder')
            end

            s.method(:PostSync) do |m|
              m.parameter(:Recorder, 'iris.syncrecord.server.service.SynchronizationRecorder')
            end

            s.method(:SyncComplete)

            master_data_module.sync.entities_to_synchronize.each do |entity|
              s.method(:"Query#{entity.data_module.name}#{entity.name}Updates") do |m|
                m.text(:MappingSourceCode)
                m.returns('java.lang.Object[]', :collection_type => :sequence)
              end
              if entity.sync.support_remove?
                s.method(:"Query#{entity.data_module.name}#{entity.name}Removals") do |m|
                  m.text(:MappingSourceCode)
                  m.returns('java.lang.Object[]', :collection_type => :sequence)
                end
              end

              s.method(:"CreateOrUpdate#{entity.data_module.name}#{entity.name}") do |m|
                m.text(:MappingSourceCode)
                m.parameter(:Record, 'java.lang.Object[]')
                m.returns(:boolean, :description => 'Return true on create, false on update')
              end
              if entity.sync.support_remove?
                s.method(:"Remove#{entity.data_module.name}#{entity.name}") do |m|
                  m.integer(:MasterId)
                  m.parameter(:Id, entity.primary_key.jpa.java_type(:boundary), :nullable => true)
                  m.returns(:boolean, :description => 'Return true on remove from non-master, false if not required')
                end
                s.method(:"Mark#{entity.data_module.name}#{entity.name}RemovalsPreSync") do |m|
                  m.text(:MappingSourceCode)
                  m.returns(:integer, :description => 'The number of records changed')
                end
              end

              if entity.sync.enable_bulk_sync?
                s.method(:"BulkCreate#{entity.data_module.name}#{entity.name}") do |m|
                  m.text(:MappingSourceCode)
                  m.returns(:integer, :description => 'The number of records inserted')
                end
                # The following methods are an in progress implementation of bulk sync actions
                s.method(:"GetSqlToDirectlyInsert#{entity.data_module.name}#{entity.name}") do |m|
                  m.text(:MappingSourceCode)
                  m.returns(:text)
                end
                s.method(:"GetSqlToMarkInserted#{entity.data_module.name}#{entity.name}AsSynchronized") do |m|
                  m.text(:MappingSourceCode)
                  m.returns(:text)
                end
                if entity.sync.update_via_sync?
                  s.method(:"GetSqlToDirectlyUpdate#{entity.data_module.name}#{entity.name}") do |m|
                    m.text(:MappingSourceCode)
                    m.returns(:text)
                  end
                  s.method(:"GetSqlToMarkUpdated#{entity.data_module.name}#{entity.name}AsSynchronized") do |m|
                    m.text(:MappingSourceCode)
                    m.returns(:text)
                  end
                end
                if entity.sync.support_remove?
                  s.method(:"GetSqlToDirectlyDelete#{entity.data_module.name}#{entity.name}") do |m|
                    m.text(:MappingSourceCode)
                    m.returns(:text)
                  end
                  s.method(:"GetSqlToMarkDeleted#{entity.data_module.name}#{entity.name}AsSynchronized") do |m|
                    m.text(:MappingSourceCode)
                    m.returns(:text)
                  end
                end
              end
            end
          end unless master_data_module.service_by_name?(:SynchronizationContext)
        end

        self.repository.data_modules.each do |dm|
          dm.entities.each do |e|
            e.attributes.each do |a|
              if !e.sync? && a.reference? && a.referenced_entity.sync? && a.referenced_entity.sync.support_remove?
                # These are attributes on non-synchronized entities that reference synchronized
                # entities that can be removed. We need to create an appropriate query so that during
                # sync we can verify that it is ok to synchronize a delete
                query_name = "CountBy#{a.name}"
                e.dao.query(query_name).disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS) unless e.dao.query_by_name?(query_name)
              end
            end
          end
        end
      end

      def pre_verify
        repository.ejb.add_flushable_test_module(self.test_module_name, self.qualified_test_module_name) if repository.ejb? && self.standalone?
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::EEClientServerJavaPackage

      # Artifacts to sync out of Master
      java_artifact :sync_ejb, :service, :server, :sync, 'SynchronizationServiceImpl'
      java_artifact :sync_service_test, :service, :server, :sync, 'AbstractExtendedSynchronizationServiceImplTest'
      java_artifact :sync_context_impl, :service, :server, :sync, 'AbstractSynchronizationContext'

      # Artifacts to sync into Master
      java_artifact :sync_temp_factory, :service, :server, :sync, 'SyncTempFactory'
      java_artifact :abstract_master_sync_ejb, :service, :server, :sync, 'AbstractMasterSyncServiceImpl'
      java_artifact :abstract_sync_temp_population_impl, :service, :server, :sync, 'AbstractSyncTempPopulationServiceImpl'
      java_artifact :sync_temp_to_master_sync_service_test, :service, :server, :sync, 'AbstractSyncTempToMasterSyncServiceImplTest'
      java_artifact :master_to_core_sync_service_test, :service, :server, :sync, 'AbstractMasterToCoreSyncServiceImplTest'

      def master_sync_persistent_unit
        raise 'master_sync_persistent_unit invoked when not master_data_module' unless master_data_module?
        return nil if @master_sync_persistent_unit_nil
        @master_sync_persistent_unit || data_module.repository.jpa.include_default_unit? ? data_module.repository.name : nil
      end

      def master_sync_persistent_unit=(master_sync_persistent_unit)
        raise 'master_sync_persistent_unit= invoked when not master_data_module' unless master_data_module?
        @master_sync_persistent_unit_nil = master_sync_persistent_unit.nil?
        @master_sync_persistent_unit = master_sync_persistent_unit
      end

      def entities_to_synchronize
        raise 'entities_to_synchronize invoked when not master_data_module' unless master_data_module?
        data_module.repository.data_modules.select {|d| d.sync?}.collect do |dm|
          dm.entities.select {|e| e.concrete? && e.sync? && e.sync.synchronize?}
        end.flatten
      end

      def master_data_module?
        data_module.repository.sync.master_data_module.to_s == data_module.name.to_s
      end

      def sync_temp_data_module?
        data_module.repository.sync.sync_temp_data_module.to_s == data_module.name.to_s
      end

      def entity_prefix=(entity_prefix)
        raise "Can not set entity_prefix on #{data_module.name} as it is the master data_module" if master_data_module?
        raise "Can not set entity_prefix on #{data_module.name} as it is the sync_temp data_module" if sync_temp_data_module?
        @entity_prefix = entity_prefix
      end

      def entity_prefix
        raise "Attempted to invoke entity_prefix on #{data_module.name}, but not valid as it is the master data_module" if master_data_module?
        raise "Attempted to invoke entity_prefix on #{data_module.name}, but not valid as it is the sync_temp data_module" if sync_temp_data_module?
        @entity_prefix || ''
      end
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :test_service, :test, :server, :sync, 'TestSyncTempPopulationServiceImpl', :sub_package => 'util'

      def sync_temp_population_service?
        service.data_module.name.to_s == service.data_module.repository.sync.master_data_module.to_s &&
          service.name.to_s == 'SyncTempPopulationService'
      end
    end

    facet.enhance(Attribute) do
      def custom_transform?
        @custom_transform.nil? ? false : !!@custom_transform
      end

      def custom_transform=(custom_transform)
        @custom_transform = custom_transform
      end

      def manual_sync=(manual_sync)
        raise "Attempted to invoke manual_sync= on #{attribute.qualified_name}, but not valid as it is not a reference" unless attribute.reference?
        @manual_sync = !!manual_sync
      end

      def manual_sync?
        @manual_sync.nil? ? false : @manual_sync
      end
    end

    facet.enhance(Entity) do
      attr_writer :support_remove

      def support_remove?
        @support_remove.nil? ? true : !!@support_remove
      end

      attr_writer :support_unmanaged

      # Return true if this entity supports entity instances other than those that come through synchronization
      def support_unmanaged?
        @support_unmanaged.nil? ? true : !!@support_unmanaged
      end

      attr_writer :test_factory_defaults_to_unmanaged

      def test_factory_defaults_to_unmanaged?
        support_unmanaged? && (@test_factory_defaults_to_unmanaged.nil? ? true : !!@test_factory_defaults_to_unmanaged)
      end

      def core_entity=(core_entity)
        @core_entity = core_entity
      end

      def core_entity
        raise "Attempted to invoke core_entity on entity #{entity.qualified_name} when not a master entity" unless core_entity?
        @core_entity
      end

      def core_entity?
        !@core_entity.nil?
      end

      def master_entity=(master_entity)
        @master_entity = master_entity
      end

      def master_entity
        raise "Attempted to invoke master_entity on entity #{entity.qualified_name} when not synchronizing entity" unless synchronize?
        @master_entity
      end

      def core?
        !self.master? && !self.sync_temp? && self.entity.qualified_name.to_s != "#{self.entity.data_module.repository.sync.master_data_module}.#{self.entity.data_module.repository.sync.mapping_source_attribute}"
      end

      def master?
        self.core_entity?
      end

      def references_requiring_manual_sync
        entity.referencing_attributes.select {|a| (!a.sync? || a.sync.manual_sync?) && a.referenced_entity.sql?}
      end

      def managed_references_requiring_manual_sync
        entity.referencing_attributes.select {|a| a.sync? && !a.sync.manual_sync? && a.entity.sync.core?}
      end

      def references_not_requiring_manual_sync
        entity.referencing_attributes.select {|a| !a.set_once? && !a.immutable? && a.sync? && a.entity.sync.core? && !a.sync.manual_sync? && a.referenced_entity.sql?}
      end

      attr_writer :recursive

      # Is the entity recursive?
      # i.e. Do the sync operations need to repeat until 0 actions
      def recursive?
        @recursive.nil? ? (entity.sync.attributes_to_synchronize.any? {|a| a.reference? && a.referenced_entity.name == entity.sync.master_entity.name}) : !!@recursive
      end

      def sync_temp_entity=(sync_temp_entity)
        @sync_temp_entity = sync_temp_entity
      end

      def sync_temp_entity
        raise "Attempted to invoke sync_temp_entity on entity #{entity.qualified_name} when not synchronizing entity" unless synchronize?
        @sync_temp_entity
      end

      def sync_temp=(sync_temp)
        @sync_temp = sync_temp
      end

      def sync_temp?
        @sync_temp.nil? ? false : @sync_temp
      end

      def synchronize=(synchronize)
        raise "Attempted to synchronize master entity #{entity.qualified_name}" if master? && synchronize
        raise "Attempted to synchronize sync_temp entity #{entity.qualified_name}" if sync_temp? && synchronize
        @synchronize = synchronize
      end

      def synchronize?
        !master? && !sync_temp? && @synchronize.nil? ? true : @synchronize
      end

      def entity_prefix=(entity_prefix)
        @entity_prefix = entity_prefix
      end

      def entity_prefix
        @entity_prefix || entity.data_module.sync.entity_prefix
      end

      def attributes_to_synchronize
        entity.sync.master_entity.attributes.select do |a|
          a.sync? && !a.primary_key? && ![:MasterSynchronized, :CreatedAt, :DeletedAt, :MasterId].include?(a.name) &&
            !(a.reference? && !a.referenced_entity.sync.master?)
        end
      end

      def attributes_to_update
        attributes_to_synchronize.select {|a| !a.immutable?}
      end

      attr_writer :delete_via_sync

      def delete_via_sync?
        self.support_remove? && (@delete_via_sync.nil? ? true : !!@delete_via_sync)
      end

      def update_via_sync?
        entity.attributes.select do |a|
          a.sync? &&
            !a.primary_key? &&
            !a.immutable? &&
            ![:MasterSynchronized, :CreatedAt, :DeletedAt, :MasterId].include?(a.name) &&
            (
            !a.reference? ||
              a.referenced_entity.sync? && a.referenced_entity.sync.synchronize?
            )
        end.size > 0
      end

      attr_writer :enable_bulk_sync

      def enable_bulk_sync?
        @enable_bulk_sync.nil? ? supports_bulk_sync? : !!@enable_bulk_sync
      end

      def supports_bulk_sync?
        entity.attributes.select do |a|
          a.reference? && a.referenced_entity == entity
        end.empty?
      end

      def master_data_module
        entity.data_module.repository.sync.master_data_module
      end

      def sync_temp_data_module
        entity.data_module.repository.sync.sync_temp_data_module
      end

      def pre_complete
        return unless synchronize?

        if support_unmanaged?
          self.entity.attributes.select { |a| a.reference? && a.referenced_entity.sync? && a.referenced_entity.sync.support_remove? }.each do |a|
            if self.entity.referencing_attributes.empty?
              # Generate a deletedUnmanagedByX query for Leaf entities so that a reasonable implementation can
              # be generated in AbstractSynchronizationContext for these types of entities
              self.entity.query("DeleteUnmanagedBy#{a.name}", 'jpa.jpql' => "O.#{Reality::Naming.camelize(a.name)} = :#{a.name} AND O.masterId IS NULL", :standard_query => true).disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)
            else
              # Method used in AbstractSynchronizationContext as a reasonable implementation so sync can abort
              # if any exist
              self.entity.query("CountUnmanagedBy#{a.name}", 'jpa.jpql' => "O.#{Reality::Naming.camelize(a.name)} = :#{a.name} AND O.masterId IS NULL", :standard_query => true).disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)
            end
          end
        end

        master_data_module = entity.data_module.repository.data_module_by_name(entity.data_module.repository.sync.master_data_module)
        master_data_module.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)

        sync_temp_data_module = entity.data_module.repository.data_module_by_name(entity.data_module.repository.sync.sync_temp_data_module)
        sync_temp_data_module.disable_facets_not_in(Domgen::Sync::VALID_SYNC_TEMP_FACETS)

        if self.entity.attribute_by_name?(:MasterId)
          master_id_attribute = self.entity.attribute_by_name(:MasterId)
          support_unmanaged = self.entity.sync.support_unmanaged?
          nullable_master_id = master_id_attribute.nullable?
          if support_unmanaged && !nullable_master_id
            Domgen.error("Entity #{self.entity.qualified_name} supports un-synchronized entities but does not have a nullable MasterId")
          elsif !support_unmanaged && nullable_master_id
            Domgen.error("Entity #{self.entity.qualified_name} does not support un-synchronized entities but does have a nullable MasterId")
          end
        else
          self.entity.integer(:MasterId,
                              :nullable => self.entity.sync.support_unmanaged?,
                              :immutable => true,
                              :description => 'Id of the entity from which this entity was synced',
                              '-facets' => [:sync, :arez, :gwt])
        end
        self.entity.jpa.create_default(:MasterId => 'null') if self.entity.sync? && self.entity.sync.support_unmanaged?
        self.entity.jpa.create_default(:CreatedAt => 'now()', :DeletedAt => 'null', :MasterId => 'null') if self.entity.transaction_time? && self.entity.sync.support_unmanaged?

        sync_temp_data_module.entity("#{self.entity.sync.entity_prefix}#{self.entity.name}") do |e|
          e.disable_facets_not_in(Domgen::Sync::VALID_SYNC_TEMP_FACETS)

          self.entity.sync.sync_temp_entity = e
          e.sync.sync_temp = true
          e.abstract = self.entity.abstract?
          e.final = self.entity.final?
          e.extends = self.entity.extends

          if self.entity.extends.nil?
            e.integer(:SyncTempId,
                      :primary_key => true,
                      :generated_value => true,
                      'sql.generator_type' => :sequence,
                      'sql.sequence_name' => "#{sql_name(:table, self.entity.name)}Seq")

            e.reference("#{self.master_data_module}.#{self.entity.data_module.repository.sync.mapping_source_attribute}", :name => :MappingSource, 'sql.column_name' => 'MappingSource', :description => 'A reference for originating system')
            e.string(:MappingKey, 255, :immutable => true, :description => 'Change to cause an instance with the same MappingId and MappingSource, to be recreated in Master.')
            e.string(:MappingId, 50, :description => 'The ID of entity in originating system')
            e.sql.index([:MappingId, :MappingSource, :SyncTempId])
          end

          self.entity.attributes.select {|a| !a.inherited?}.each do |a|
            next if a.primary_key?
            next if [:CreatedAt, :DeletedAt].include?(a.name)
            next unless a.sync?

            Domgen.error("Can not yet synchronize entity structs as in #{a.qualified_name}") if a.struct?

            name = a.name
            attribute_type = a.attribute_type

            options = {}

            options[:collection_type] = a.collection_type
            options[:nullable] = a.nullable?

            if a.reference?
              attribute_type = :text
              name = "#{name}MappingId"
              options[:length] = 50
            elsif a.enumeration?
              options[:enumeration] = a.enumeration
              options[:length] = a.length if a.enumeration.textual_values?
            elsif a.text?
              options[:length] = a.length
              options[:min_length] = a.min_length
              options[:allow_blank] = a.allow_blank?
            end
            options[:abstract] = a.abstract?

            e.attribute(name, attribute_type, options)

            if a.reference?
              filter = a.nullable? ? "#{e.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL" : nil
              e.sql.index([:MappingSource, name], :filter => filter, :include_attribute_names => [:MappingKey, :MappingId])
            end
          end
        end

        master_data_module.entity("#{self.entity.sync.entity_prefix}#{self.entity.name}") do |e|
          e.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)

          self.entity.sync.master_entity = e
          e.sync.core_entity = self
          e.abstract = self.entity.abstract?
          e.final = self.entity.final?
          e.extends = self.entity.extends

          if self.entity.extends.nil?
            e.integer(:Id,
                      :primary_key => true,
                      :generated_value => true,
                      'sql.generator_type' => :sequence,
                      'sql.sequence_name' => "#{sql_name(:table, self.entity.name)}Seq")

            e.reference(self.entity.data_module.repository.sync.mapping_source_attribute, :name => :MappingSource, :immutable => true, 'sql.column_name' => 'MappingSource', :description => 'A reference for originating system')
            e.string(:MappingKey, 255, :immutable => true, :description => 'Uniquely defines an instance with same MappingId and MappingSource.')
            e.string(:MappingId, 50, :immutable => true, :description => 'The ID of entity in originating system')
            e.boolean(:MasterSynchronized, :description => 'Set to true if synchronized from master tables into the main data area')

            filter = self.entity.sync.support_remove? ? "#{e.sql.dialect.quote(:DeletedAt)} IS NULL" : nil
            e.sql.index([:MappingId, :MappingKey, :MappingSource], :unique => true, :filter => filter)
            e.sql.index([:MappingSource, :MappingId], :include_attribute_names => [:Id], :filter => filter)
          end

          unless self.entity.abstract?
            self.entity.sql.foreign_key([:MasterId], e.qualified_name, [:Id], :defer_creation => true, :on_delete => :no_action)
          end

          self.entity.attributes.select {|a| (!a.inherited? && !a.primary_key?) || (a.primary_key? && self.entity.concrete?)}.each do |a|
            next unless a.sync?

            # For self referential, non-transaction time entities, we have to set sql.on_delete
            # attribute otherwise sync will fail to remove the entity during synchronization
            if a.reference? && a.referenced_entity.qualified_name == a.entity.qualified_name && !entity.transaction_time? && entity.sync.support_remove?
              a.sql.on_delete = :set_null
            end

            options = {}
            Domgen.error("Can not yet synchronize entity structs as in #{a.qualified_name}") if a.struct?
            options[:referenced_entity] = a.referenced_entity.name if a.reference?
            name = a.name
            attribute_type = a.attribute_type

            if a.primary_key?
              name = self.entity.name
              attribute_type = :reference
              options[:referenced_entity] = a.entity.qualified_name
              options[:nullable] = true
              options['sql.on_delete'] = :set_null
              options['sql.defer_creation'] = true
              options['inverse.multiplicity'] = :zero_or_one
              options['jpa.persistent'] = true
              options[:abstract] = false
              options[:override] = false
            else
              options[:abstract] = a.abstract?
            end

            if a.enumeration?
              options[:enumeration] = a.enumeration
              options[:length] = a.length if a.enumeration.textual_values?
            end
            if a.text?
              options[:length] = a.length
              options[:min_length] = a.min_length
              options[:allow_blank] = a.allow_blank?
            end
            if a.reference? && a.inverse.traversable?
              options['inverse.traversable'] = true
              options['inverse.name'] = a.inverse.name
              options['inverse.multiplicity'] = a.inverse.multiplicity
            end
            options[:collection_type] = a.collection_type
            options[:nullable] = a.nullable? || a.primary_key?
            options[:immutable] = !a.primary_key? && a.immutable?
            options[:set_once] = a.set_once?

            # We can not guarantee that fields will be unique as the ordering of
            # updates in the synchronization process will not guarantee this condition.
            # However we generate checks in sync code so this should never happen.
            # However we can get problems synchronizing from Master into non-Master tables
            # as ordering can still lead to uniqueness constraints being violated during
            # the sync process and aborting the sync action. However sync_ejb.java.erb will
            # continue synchronization for all entities in a type so that hopefully the next
            # synchronization will allow all entities to flow through. This will not work if
            # entities have multiple unique fields and there is no ordering of operations that
            # will allow it to proceed. In this case, administrator intervention is required.
            options[:unique] = false

            e.attribute(name, attribute_type, options)

            if a.primary_key?
              e.sql.index([name], :unique => true, :filter => "#{e.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL")
              # Duplicate the index as sometimes want to query where there is no entity in Core
              e.sql.index([name])

              link_constraint_sql =
                self.entity.sync.support_remove? ?
                  "#{e.sql.dialect.quote(:MasterSynchronized)} = #{e.sql.dialect.quote_value(false)} OR #{e.sql.dialect.quote(:DeletedAt)} IS NOT NULL OR #{e.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL" :
                  "#{e.sql.dialect.quote(:MasterSynchronized)} = #{e.sql.dialect.quote_value(false)} OR #{e.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL"

              e.sql.constraint(:CoreLinkedIfSyncAndNonDeleted, :sql => link_constraint_sql, :standard => true)
            end

            if a.reference?
              # Create an index to speed up validity checking when column is sparsely populated
              e.sql.index([name], :index_name => "IX_#{self.entity.name}_#{name}_ALL", :include_attribute_names => [:MappingKey, :MappingId, :MappingSource])
              prefix = a.nullable? ? "#{e.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL AND " : ''
              filter = a.transaction_time? && a.referenced_entity.sync.support_remove? ? "#{prefix}#{e.sql.dialect.quote(:DeletedAt)} IS NULL" : nil
              e.sql.index([name], :filter => filter, :include_attribute_names => [:MappingKey, :MappingId, :MappingSource])
            end

            if a.unique?
              # If entity is a transaction time entity, and an uniqueness index that filters out logically deleted entities
              if entity.transaction_time?
                existing_constraint = self.entity.unique_constraints.find do |uq|
                  uq.attribute_names.length == 1 && uq.attribute_names[0].to_s == a.name.to_s
                end
                existing_index = self.entity.sql.indexes.find do |i|
                  i.attribute_names.length == 1 && i.attribute_names[0].to_s == a.name.to_s
                end
                if existing_constraint.nil? && existing_index.nil?
                  self.entity.sql.index([a.name], :unique => true, :filter => "#{e.sql.dialect.quote(:DeletedAt)} IS NULL")
                end
              end
            end
          end

          # update indexes in the original entity, if it is a transaction time entity so filtering can be specified
          if self.entity.transaction_time?
            e.enable_facet(:transaction_time) unless e.transaction_time?
            # Ugly call of hook that does the setup of transaction time infrastructure
            e.transaction_time.pre_pre_complete
            self.entity.sql.indexes.each do |index|
              next if index.cluster?

              unless index.attribute_names.include?(:DeletedAt) || index.attribute_names.include?(:CreatedAt)
                unless index.filter && (index.filter =~ Regexp.new(Regexp.escape(e.sql.dialect.quote(:DeletedAt))) || index.filter =~ Regexp.new(Regexp.escape('DeletedAt')) || index.filter =~ Regexp.new(Regexp.escape(e.sql.dialect.quote(:CreatedAt))) || index.filter =~ Regexp.new(Regexp.escape('CreatedAt')))
                  index.filter = (index.filter.nil? ? '' : "(#{index.filter}) AND ") + "#{entity.sql.dialect.quote(:DeletedAt)} IS NULL"
                end
              end
            end

            entity.sync.references_not_requiring_manual_sync.each do |a|
              a.entity.query("FindAllBy#{a.name}") unless a.entity.query_by_name?("FindAllBy#{a.name}")
            end
          end

          unless self.entity.transaction_time?
            e.disable_facet(:transaction_time) if e.transaction_time?
            e.datetime(:CreatedAt, :immutable => true) unless e.attribute_by_name?(:CreatedAt)
            if self.entity.sync.support_remove? && !e.attribute_by_name?(:DeletedAt)
              e.datetime(:DeletedAt, :set_once => true, :nullable => true)
            end
          end

          if e.concrete?
            e.query(:FindByMappingSourceAndMappingId)
            e.query(:GetByMappingSourceAndMappingId)
            if self.entity.sync.support_remove?
              e.jpa.test_create_default(self.entity.name => 'null', :MasterSynchronized => 'false', :CreatedAt => 'now()', :DeletedAt => 'null')
              e.jpa.test_create_default(self.entity.name => 'null', :MasterSynchronized => 'false', :MappingKey => 'mappingId', :CreatedAt => 'now()', :DeletedAt => 'null')
              e.jpa.test_create_default(self.entity.name => 'null', :MasterSynchronized => 'false', :MappingSource => 'findOrCreateDefaultMappingSource()', :MappingKey => "java.lang.String.valueOf( org.realityforge.guiceyloops.shared.ValueUtil.nextId( \"#{e.qualified_name}\") )", :MappingId => "java.lang.String.valueOf( org.realityforge.guiceyloops.shared.ValueUtil.nextId( \"#{e.qualified_name}\" ) - 1 )", :CreatedAt => 'now()', :DeletedAt => 'null' )
            else
              e.jpa.test_create_default(self.entity.name => 'null', :MasterSynchronized => 'false', :CreatedAt => 'now()')
              e.jpa.test_create_default(self.entity.name => 'null', :MasterSynchronized => 'false', :MappingKey => 'mappingId', :CreatedAt => 'now()')
              e.jpa.test_create_default(self.entity.name => 'null', :MasterSynchronized => 'false', :MappingSource => 'findOrCreateDefaultMappingSource()', :MappingKey => "java.lang.String.valueOf( org.realityforge.guiceyloops.shared.ValueUtil.nextId( \"#{e.qualified_name}\" ) )", :MappingId => "java.lang.String.valueOf( org.realityforge.guiceyloops.shared.ValueUtil.nextId( \"#{e.qualified_name}\" ) - 1 )", :CreatedAt => 'now()' )
            end
            e.jpa.test_create_default(self.entity.name => 'null', :MasterSynchronized => 'false', :MappingKey => 'mappingId')
            e.jpa.test_create_default(self.entity.name => 'null', :MasterSynchronized => 'false')
            if self.entity.sync.support_remove?
              e.jpa.test_update_default({ self.entity.name => nil, :MasterSynchronized => 'false', :MappingSource => nil, :MappingKey => nil, :MappingId => nil, :DeletedAt => nil }, :force_refresh => true)
            else
              e.jpa.test_update_default({ self.entity.name => nil, :MasterSynchronized => 'false', :MappingSource => nil, :MappingKey => nil, :MappingId => nil }, :force_refresh => true)
            end
            if self.entity.sync.support_remove?
              delete_defaults = {}
              e.attributes.each do |a|
                delete_defaults[a.name] = nil unless a.generated_value? || a.immutable? || !a.jpa?
              end
              delete_defaults[:MasterSynchronized] = 'false'
              delete_defaults[:DeletedAt] = 'new java.util.Date()'
              e.jpa.test_update_default(delete_defaults, :force_refresh => true, :factory_method_name => "mark#{e.name}AsDeleted")
            end
            e.query(:CountUnsynchronizedByMappingSource,
                    'jpa.standard_query' => true,
                    'jpa.jpql' => 'O.mappingSource = :MappingSource AND O.masterSynchronized = false')
            e.sql.index([:MappingSource], :filter => "#{e.sql.dialect.quote(:MasterSynchronized)} = #{e.sql.dialect.quote_value(false)}")

            # no_ql? assumes that it will be defined by a later stage as a standard_query or a build failure will occur
            self.entity.dao.queries.select { |q| q.sync? && q.jpa? && q.jpa.no_ql? }.each do |o|
              e.query(o.name) do |q|
                o.parameters.each do |p|
                  options = {}
                  if p.enumeration?
                    options[:enumeration] = p.enumeration
                    options[:length] = p.length if p.enumeration.textual_values?
                  end
                  if p.text?
                    options[:length] = p.length
                    options[:min_length] = p.min_length
                    options[:allow_blank] = p.allow_blank?
                  end
                  options[:collection_type] = p.collection_type
                  options[:nullable] = p.nullable?
                  q.parameter(p.name, p.parameter_type, options)
                end
              end
            end
          end
        end

        unless self.entity.abstract?
          validation_name = 'MasterIdLinkedCorrectly'
          unless self.entity.sql.validation?(validation_name)
            m = self.entity.sync.master_entity
            guard = "UPDATE(#{self.entity.attribute_by_name(:MasterId).sql.quoted_column_name})"
            suffix = nil
            if self.entity.transaction_time?
              guard = "UPDATE(#{self.entity.attribute_by_name(:DeletedAt).sql.quoted_column_name}) OR #{guard}"
              suffix = " AND M.#{m.attribute_by_name(:DeletedAt).sql.quoted_column_name} IS NOT NULL AND I.#{self.entity.attribute_by_name(:DeletedAt).sql.quoted_column_name} IS NULL"
            elsif self.entity.sync.support_remove?
              suffix = " AND M.#{m.attribute_by_name(:DeletedAt).sql.quoted_column_name} IS NOT NULL"
            end

            sql = nil
            if self.entity.sync.support_unmanaged?
              sql = <<-SQL
SELECT I.#{self.entity.primary_key.sql.quoted_column_name}
FROM inserted I
LEFT JOIN #{m.sql.qualified_table_name} M ON M.#{m.primary_key.sql.quoted_column_name} = I.#{self.entity.attribute_by_name(:MasterId).sql.quoted_column_name}
WHERE I.#{self.entity.attribute_by_name(:MasterId).sql.quoted_column_name} IS NOT NULL AND (M.#{m.primary_key.sql.quoted_column_name} IS NULL OR (M.#{m.attribute_by_name(:MasterSynchronized).sql.quoted_column_name} = #{m.sql.dialect.quote_value(true)}#{suffix}))
              SQL
            elsif suffix
              sql = <<-SQL
SELECT I.#{self.entity.primary_key.sql.quoted_column_name}
FROM inserted I
JOIN #{m.sql.qualified_table_name} M ON M.#{m.primary_key.sql.quoted_column_name} = I.#{self.entity.attribute_by_name(:MasterId).sql.quoted_column_name}
WHERE M.#{m.attribute_by_name(:MasterSynchronized).sql.quoted_column_name} = #{m.sql.dialect.quote_value(true)}#{suffix}
              SQL
            end
            self.entity.sql.validation(validation_name, :standard => true, :negative_sql => sql, :guard => guard) if sql
          end
        end if self.entity.mssql?
      end

      def post_verify
        Domgen.error("Entity #{self.entity.qualified_name} is marked with sync facet as well as sql.load_from_fixture? which is invalid") if self.entity.sql.load_from_fixture?
      end
    end
  end
end
