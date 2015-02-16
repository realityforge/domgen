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
  class Audit
    VALID_HISTORY_FACETS = [:sql, :audit, :pgsql, :mssql]
  end

  FacetManager.facet(:audit => [:sql]) do |facet|
    facet.enhance(Repository) do

      attr_writer :table_suffix

      def table_suffix
        @table_suffix || 'History'
      end
    end

    facet.enhance(DataModule) do

      attr_writer :table_suffix

      def table_suffix
        @table_suffix || data_module.repository.audit.table_suffix
      end

      def pre_complete
        data_module.entities.each do |original_entity|

          if original_entity.audit?
            unless data_module.enumeration_by_name?(:AuditChangeType)
              data_module.enumeration(:AuditChangeType, :text, :values => %w(I U D)) do |e|
                e.disable_facets_not_in(Domgen::Audit::VALID_HISTORY_FACETS)
              end
            end

            original_entity.jpa.table_name = "vw#{original_entity.name}"
            original_entity.primary_key.sql.generator_type = :sequence
            original_entity.datetime(:AuditStartAt, :immutable => true, 'jpa.persistent' => false) do |a|
              a.disable_facets_not_in(Domgen::Audit::VALID_HISTORY_FACETS)
            end
            end_at_attribute = original_entity.datetime(:AuditEndAt, :set_once => true, :nullable => true, 'jpa.persistent' => false) do |a|
              a.disable_facets_not_in(Domgen::Audit::VALID_HISTORY_FACETS)
            end
            original_entity.relationship_constraint(:lte, :AuditStartAt, :AuditEndAt)

            original_entity.datetime(:AuditLastModifiedAt, :description => 'the last time the entity was modified', 'jpa.persistent' => false) do |a|
              a.disable_facets_not_in(Domgen::Audit::VALID_HISTORY_FACETS)
            end
            original_entity.unique_constraints.each do |c|
              original_entity.sql.index(c.attribute_names, {:unique => true, :filter => "#{end_at_attribute.sql.quoted_column_name} IS NULL"}, true)
            end

            data_module.entity("#{original_entity.name}#{table_suffix}") do |e|
              e.disable_facet(:audit) if e.audit?
              e.disable_facets_not_in(Domgen::Audit::VALID_HISTORY_FACETS)
              e.integer(:Id, :primary_key => true)
              e.enumeration(:Op, :AuditChangeType, :immutable => true)
              e.reference(original_entity.name, :immutable => true, 'sql.on_delete' => :cascade)
              e.datetime(:SnapshotAt, :immutable => true)

              original_entity.attributes.select { |a| !a.immutable? && a.jpa? && a.jpa.persistent? }.each do |a|
                options = {:immutable => true}
                options[:referenced_struct] = a.referenced_struct if a.struct?
                if a.reference?
                  options[:referenced_entity] = a.referenced_entity
                  options['sql.on_delete'] = :cascade
                end
                if a.enumeration?
                  options[:enumeration] = a.enumeration
                  options[:length] = a.length
                end
                if a.text?
                  options[:length] = a.length
                  options[:min_length] = a.min_length
                  options[:allow_blank] = a.allow_blank?
                end
                options[:collection_type] = a.collection_type
                options[:nullable] = a.nullable?
                e.attribute(a.name, a.attribute_type, options)
              end
            end
          end
        end
      end
    end
  end
end
