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
  class Sync
    VALID_MASTER_FACETS = [:sql, :mssql, :pgsql, :ee, :ejb, :java, :jpa, :sync]
    VALID_SYNC_TEMP_FACETS = [:sql, :mssql, :pgsql, :sync]
  end

  FacetManager.facet(:sync => [:sql]) do |facet|
    facet.enhance(Repository) do

      def transaction_time=(transaction_time)
        @transaction_time = transaction_time
      end

      def transaction_time?
        @transaction_time.nil? ? false : !!@transaction_time
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

      def pre_complete
        unless repository.data_module_by_name?(self.master_data_module)
          repository.data_module(self.master_data_module)
        end
        master_data_module = repository.data_module_by_name(self.master_data_module)

        unless repository.data_module_by_name?(self.sync_temp_data_module)
          repository.data_module(self.sync_temp_data_module)
        end

        master_data_module.entity(self.mapping_source_attribute) do |t|
          t.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)
          t.sync.synchronize = false
          t.string(:Code, 5, :primary_key => true)
        end unless master_data_module.entity_by_name?(self.mapping_source_attribute)

        master_data_module.service(:SyncTempPopulationService) do |s|
          s.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)
          if s.ejb?
            s.ejb.generate_boundary = false
            s.ejb.standard_implementation = false
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

          master_data_module.service(:SynchronizationContext) do |s|
            s.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)
            s.ejb.generate_boundary = false if s.ejb?

            master_data_module.sync.entities_to_synchronize.collect do |e|
              # Assume that the synchronization process will correctly handle
              # deletion of referenced entities and thus no special handling required
              e.sync.references_requiring_manual_sync.each do |a|
                s.method("Remove#{a.entity.data_module.name}#{a.entity.name}RelatedTo#{a.referenced_entity.data_module.name}#{a.referenced_entity.name}Via#{a.name}") do |m|
                  m.reference(e.qualified_name)
                end
              end
            end

            master_data_module.sync.entities_to_synchronize.each do |entity|
              unless entity.primary_key.generated_value?
                s.method("Generate#{entity.data_module.name}#{entity.name}Key") do |m|
                  entity.attributes.select { |a| !a.primary_key? && a.sql? && a.jpa? && a.sync? }.each do |a|
                    options = {}
                    options[:collection_type] = a.collection_type
                    options[:nullable] = a.nullable?

                    attribute_type = a.attribute_type
                    if a.reference?
                      attribute_type = a.referenced_entity.primary_key.attribute_type
                    elsif a.enumeration?
                      options[:enumeration] = a.enumeration
                      options[:length] = a.length if a.enumeration.textual_values?
                    elsif a.text?
                      options[:length] = a.length
                      options[:min_length] = a.min_length
                      options[:allow_blank] = a.allow_blank?
                    end

                    m.parameter(a.name, attribute_type, options)
                  end
                  # TODO Should probably support reference primary keys by passing other options
                  m.returns(entity.primary_key.attribute_type)
                end
              end

              s.method(:"GetSqlToRetrieve#{entity.data_module.name}#{entity.name}ListToUpdate") do |m|
                m.text(:MappingSourceCode)
                m.returns(:text)
              end
              if entity.sync.update_via_sync?
                # The following methods are an in progress implementation of bulk sync actions
                s.method(:"GetSqlToDirectlyUpdate#{entity.data_module.name}#{entity.name}") do |m|
                  m.text(:MappingSourceCode)
                  m.returns(:text)
                end
                s.method(:"GetSqlToMarkUpdated#{entity.data_module.name}#{entity.name}AsSynchronized") do |m|
                  m.text(:MappingSourceCode)
                  m.returns(:text)
                end
              end
              s.method(:"GetSqlToDirectlyDelete#{entity.data_module.name}#{entity.name}") do |m|
                m.text(:MappingSourceCode)
                m.returns(:text)
              end
              s.method(:"GetSqlToMarkDeleted#{entity.data_module.name}#{entity.name}AsSynchronized") do |m|
                m.text(:MappingSourceCode)
                m.returns(:text)
              end
              s.method(:"GetSqlToRetrieve#{entity.data_module.name}#{entity.name}ListToRemove") do |m|
                m.text(:MappingSourceCode)
                m.returns(:text)
              end
              entity.attributes.select { |a| a.sync? && a.sync.custom_transform? }.each do |attribute|
                s.method(:"Transform#{entity.data_module.name}#{entity.name}#{attribute.name}") do |m|
                  options = {:nullable => attribute.nullable?}
                  attribute_type = attribute.reference? ? attribute.referenced_entity.primary_key.attribute_type : attribute.attribute_type
                  m.parameter(:Value, attribute_type, options)
                  m.returns(attribute_type, options)
                end
              end
            end
          end unless master_data_module.service_by_name?(:SynchronizationContext)
        end
      end
    end

    facet.enhance(DataModule) do
      def transaction_time=(transaction_time)
        @transaction_time = transaction_time
      end

      def transaction_time?
        @transaction_time.nil? ? data_module.repository.sync.transaction_time? : !!@transaction_time
      end


      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::EEClientServerJavaPackage

      # Artifacts to sync out of Master
      java_artifact :sync_ejb, :service, :server, :sync, 'SynchronizationServiceEJB'
      java_artifact :sync_service_test, :service, :server, :sync, 'AbstractExtendedSynchronizationServiceEJBTest'
      java_artifact :sync_context_impl, :service, :server, :sync, 'AbstractSynchronizationContext'

      # Artifacts to sync into Master
      java_artifact :sync_temp_factory, :service, :server, :sync, 'SyncTempFactory'
      java_artifact :abstract_master_sync_ejb, :service, :server, :sync, 'AbstractMasterSyncServiceEJB'
      java_artifact :abstract_sync_temp_population_impl, :service, :server, :sync, 'AbstractSyncTempPopulationServiceImpl'
      java_artifact :master_sync_service_test, :service, :server, :sync, 'AbstractMasterSyncServiceEJBTest'

      def entities_to_synchronize
        raise 'entities_to_synchronize invoked when not master_data_module' unless master_data_module?
        data_module.repository.data_modules.select { |d| d.sync? }.collect do |dm|
          dm.entities.select { |e| e.concrete? && e.sync? && e.sync.synchronize? }
        end.flatten
      end

      def master_data_module?
        data_module.repository.sync.master_data_module == data_module.name
      end

      def sync_temp_data_module?
        data_module.repository.sync.sync_temp_data_module == data_module.name
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
      def master_entity=(master_entity)
        @master_entity = master_entity
      end

      def master_entity
        raise "Attempted to invoke master_entity on entity #{entity.qualified_name} when not synchronizing entity" unless synchronize?
        @master_entity
      end

      def master=(master)
        @master = master
      end

      def master?
        @master.nil? ? false : @master
      end

      def transaction_time=(transaction_time)
        @transaction_time = transaction_time
      end

      def transaction_time?
        @transaction_time.nil? ? entity.data_module.sync.transaction_time? : !!@transaction_time
      end

      def references_requiring_manual_sync
        entity.referencing_attributes.select {|a| (!a.sync? || a.sync.manual_sync?) && a.referenced_entity.sql? }
      end

      attr_writer :recursive

      # Is the entity recursive?
      # i.e. Do the sync operations need to repeat until 0 actions
      def recursive?
        @recursive.nil? ? (entity.sync.attributes_to_synchronize.any? { |a| a.reference? && a.referenced_entity.name == entity.sync.master_entity.name }) : !!@recursive
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
          a.sync? && !a.primary_key? && ![:MasterSynchronized, :CreatedAt, :DeletedAt].include?(a.name) &&
            !(a.reference? && !a.referenced_entity.sync.master?)
        end
      end

      def attributes_to_update
        attributes_to_synchronize.select{|a|!a.immutable?}
      end

      def update_via_sync?
        entity.attributes.select do |a|
          a.sync? && !a.primary_key? &&
          (!entity.sync.transaction_time? || ![:CreatedAt, :DeletedAt].include?(a.name)) &&
            !(a.reference? && !a.referenced_entity.sync.master?)
        end
      end

      def master_data_module
        entity.data_module.repository.sync.master_data_module
      end

      def sync_temp_data_module
        entity.data_module.repository.sync.sync_temp_data_module
      end

      def pre_complete
        return unless synchronize?

        if entity.sync.transaction_time?
          self.entity.datetime(:CreatedAt, :immutable => true) unless entity.attribute_by_name?(:CreatedAt)
          self.entity.datetime(:DeletedAt, :set_once => true, :nullable => true) unless entity.attribute_by_name?(:DeletedAt)
          self.entity.jpa.default_jpql_criterion = 'O.deletedAt IS NULL'

          self.entity.unique_constraints.each do |constraint|
            # Force the creation of the index with filter specified. Parallels behavious in sql facet.
            index = self.entity.sql.index(constraint.attribute_names, :unique => true)
            index.filter = "#{self.entity.sql.dialect.quote(:DeletedAt)} IS NULL"
          end
        end
        self.entity.jpa.detachable = true if self.entity.jpa?

        master_data_module = entity.data_module.repository.data_module_by_name(entity.data_module.repository.sync.master_data_module)
        master_data_module.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)

        sync_temp_data_module = entity.data_module.repository.data_module_by_name(entity.data_module.repository.sync.sync_temp_data_module)
        sync_temp_data_module.disable_facets_not_in(Domgen::Sync::VALID_SYNC_TEMP_FACETS)

        sync_temp_data_module.entity("#{self.entity.sync.entity_prefix}#{self.entity.name}") do |e|
          e.disable_facets_not_in(Domgen::Sync::VALID_SYNC_TEMP_FACETS)

          self.entity.sync.sync_temp_entity = e
          e.sync.sync_temp = true
          e.abstract = self.entity.abstract?
          e.final = self.entity.final?
          e.extends = self.entity.extends

          if self.entity.extends.nil?
            e.integer(:SyncTempID,
                      :primary_key => true,
                      :generated_value => true,
                      'sql.generator_type' => :sequence,
                      'sql.sequence_name' => "#{sql_name(:table, self.entity.name)}Seq")

            e.reference("#{self.master_data_module}.#{self.entity.data_module.repository.sync.mapping_source_attribute}", :name => :MappingSource, 'sql.column_name' => 'MappingSource', :description => 'A reference for originating system')
            e.string(:MappingKey, 255, :immutable => true, :description => 'Change to cause an instance with the same MappingID and MappingSource, to be recreated in Master.')
            e.string(:MappingID, 50, :description => 'The ID of entity in originating system')
          end

          self.entity.attributes.select { |a| !a.inherited? }.each do |a|
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
              name = "#{name}MappingID"
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
                e.sql.index([:MappingSource, name], :filter => filter, :include_attribute_names => [:MappingKey, :MappingID])
            end
          end
        end

        master_data_module.entity("#{self.entity.sync.entity_prefix}#{self.entity.name}") do |e|
          e.disable_facets_not_in(Domgen::Sync::VALID_MASTER_FACETS)

          self.entity.sync.master_entity = e
          e.sync.master = true
          e.abstract = self.entity.abstract?
          e.final = self.entity.final?
          e.extends = self.entity.extends

          if self.entity.extends.nil?
            e.integer(:ID,
                      :primary_key => true,
                      :generated_value => true,
                      'sql.generator_type' => :sequence,
                      'sql.sequence_name' => "#{sql_name(:table, self.entity.name)}Seq")

            e.reference(self.entity.data_module.repository.sync.mapping_source_attribute, :name => :MappingSource, :immutable => true, 'sql.column_name' => 'MappingSource', :description => 'A reference for originating system')
            e.string(:MappingKey, 255, :immutable => true, :description => 'Uniquely defines an instance with same MappingID and MappingSource.')
            e.string(:MappingID, 50, :immutable => true, :description => 'The ID of entity in originating system')
            e.boolean(:MasterSynchronized, :description => 'Set to true if synchronized from master tables into the main data area')

            e.sql.index([:MappingID, :MappingKey, :MappingSource], :unique => true, :filter => "#{e.sql.dialect.quote(:DeletedAt)} IS NULL")
            e.sql.index([:MappingSource, :MappingID], :include_attribute_names => [:ID], :filter => "#{e.sql.dialect.quote(:DeletedAt)} IS NULL")
          end

          self.entity.attributes.select { |a| !a.inherited? || a.primary_key? }.each do |a|
            next unless a.sync?

            options = {}
            Domgen.error("Can not yet synchronize entity structs as in #{a.qualified_name}") if a.struct?
            options[:referenced_entity] = a.referenced_entity.name if a.reference?
            name = a.name
            attribute_type = a.attribute_type

            if a.primary_key?
              name = a.entity.root_entity.name
              attribute_type = :reference
              options[:referenced_entity] = a.entity.qualified_name
              options[:nullable] = true
              options['sql.on_delete'] = :set_null
              options['jpa.persistent'] = true
              options[:abstract] = a.entity.abstract?
              options[:override] = !a.entity.extends.nil?
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
            options[:collection_type] = a.collection_type
            options[:nullable] = a.nullable? || a.primary_key?
            options[:immutable] = !a.primary_key? && a.immutable?
            options[:set_once] = a.set_once?
            options[:unique] = a.unique?

            e.attribute(name, attribute_type, options)

            if a.primary_key?
              e.sql.index([name], :unique => true, :filter => "#{e.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL")
            end

            if a.reference?
              # Create an index to speed up validity checking when column is sparsely populated
              prefix = a.nullable? ? "#{e.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL AND " : ''
              e.sql.index([name], :filter => "#{prefix}#{e.sql.dialect.quote(:DeletedAt)} IS NULL", :include_attribute_names => [:MappingKey, :MappingID])
            end
          end
          self.entity.unique_constraints.each do |constraint|
            e.sql.index(constraint.attribute_names, :unique => true, :filter => "#{e.sql.dialect.quote(:DeletedAt)} IS NULL")
          end

          unless entity.sync.transaction_time?
            e.datetime(:CreatedAt, :immutable => true) unless e.attribute_by_name?(:CreatedAt)
            e.datetime(:DeletedAt, :set_once => true, :nullable => true) unless e.attribute_by_name?(:DeletedAt)
          end

          if e.concrete?
            e.query(:FindByMappingSourceAndMappingID)
            e.query(:GetByMappingSourceAndMappingID)
            e.jpa.test_create_default(e.root_entity.name => 'null', :MasterSynchronized => 'false', :CreatedAt => 'new java.util.Date()', :DeletedAt => 'null')
            e.jpa.test_create_default(e.root_entity.name => 'null', :MasterSynchronized => 'false', :MappingKey => 'mappingID', :CreatedAt => 'new java.util.Date()', :DeletedAt => 'null')
            e.jpa.test_create_default(e.root_entity.name => 'null', :MasterSynchronized => 'false', :MappingKey => 'mappingID')
            e.jpa.test_create_default(e.root_entity.name => 'null', :MasterSynchronized => 'false')
            e.jpa.test_create_default(:CreatedAt => 'new java.util.Date()', :DeletedAt => 'null')
            e.jpa.test_update_default({e.root_entity.name => nil, :MasterSynchronized => 'false', :MappingSource => nil, :MappingKey => nil, :MappingID => nil, :CreatedAt => nil, :DeletedAt => nil}, :force_refresh => true)
            e.jpa.test_update_default({e.root_entity.name => nil, :MasterSynchronized => 'false', :MappingSource => nil, :MappingKey => nil, :MappingID => nil}, :force_refresh => true)
            e.jpa.test_update_default({:CreatedAt => nil, :DeletedAt => nil}, :force_refresh => true)
            delete_defaults = {}
            e.attributes.each do |a|
              delete_defaults[a.name] = nil unless a.generated_value? || a.immutable? || !a.jpa?
            end
            delete_defaults[:MasterSynchronized] = 'false'
            delete_defaults[:DeletedAt] = 'new java.util.Date()'
            e.jpa.test_update_default(delete_defaults, :force_refresh => true, :factory_method_name => "mark#{e.name}AsDeleted")
            e.query(:CountByMappingSource)
            e.query(:CountUnsynchronizedByMappingSource,
                    'jpa.jpql' => 'O.mappingSource = :MappingSource AND O.masterSynchronized = false')

            if entity.sync.transaction_time?
              entity.jpa.test_create_default(:CreatedAt => 'new java.util.Date()', :DeletedAt => 'null')
               if entity.imit?
                 attributes = entity.attributes.select{|a|%w(CreatedAt DeletedAt).include?(a.name.to_s) && a.imit? }.collect{|a|a.name.to_s}
                 if attributes.size > 0
                   defaults = {}
                   defaults[:CreatedAt] = 'new java.util.Date()' if attributes.include?('CreatedAt')
                   defaults[:DeletedAt] = 'null' if attributes.include?('DeletedAt')
                   entity.imit.test_create_default(defaults)
                 end
               end
            end
          end
        end
      end
    end
  end
end
