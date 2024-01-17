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
  module SqlAnalysis
    VALID_ANALYSIS_FACETS = [:sql, :mssql, :pgsql, :ee, :ejb, :jpa, :sql_analysis]
  end

  FacetManager.facet(:sql_analysis => [:sql]) do |facet|
    facet.description = <<-DESC
      A facet that is used to perform analysis of the database. It is used as a tool to find
      inconsistent data values.
    DESC

    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      attr_writer :analysis_data_module_name

      java_artifact :abstract_corruption_checks_test, :test, :server, :sql_analysis, 'Abstract#{repository.name}CorruptionChecksTest', :sub_package => 'util'

      def analysis_data_module_name
        @analysis_data_module_name || 'Analysis'
      end

      def analysis_data_module
        repository.data_module_by_name(self.analysis_data_module_name)
      end

      def corruption_check_entity
        self.analysis_data_module.entity_by_name(:CorruptionCheck)
      end

      def data_issue_entity
        self.analysis_data_module.entity_by_name(:DataIssue)
      end

      def pre_complete
        unless repository.data_module_by_name?(self.analysis_data_module_name)
          repository.data_module(self.analysis_data_module_name)
        end
        analysis_data_module = self.analysis_data_module
        analysis_data_module.disable_facets_not_in(Domgen::SqlAnalysis::VALID_ANALYSIS_FACETS)
        analysis_data_module.jpa.short_test_code = 'sql_analysis'

        analysis_data_module.entity(:CorruptionCheck) do |t|
          t.disable_facets_not_in(Domgen::SqlAnalysis::VALID_ANALYSIS_FACETS)
          t.sql.load_from_fixture = true
          t.jpa.generate_metamodel = false
          t.integer(:Id, :primary_key => true)
          t.string(:Category, 50)
          t.string(:Description, 500, :unique => true)
          t.text(:CommonTableExpression, :nullable => true)
          t.text(:Sql)

          t.query(:GetByDescription)
        end

        analysis_data_module.entity(:DataIssue) do |t|
          t.jpa.generate_metamodel = false
          t.integer(:Id, :primary_key => true)
          t.string(:Category, 50)
          t.string(:Description, 500, :unique => true)
          t.text(:ViewSql, :nullable => true)
        end
      end
    end

    facet.enhance(Entity) do
      def validation_values
        @validation_values ||= {}
      end
      def validations
        validation_values.values
      end

      def validation?(name)
        !!validation_values[name.to_s]
      end
      def validation(name, options = {}, &block)
        Domgen.error("Validation named #{name} already defined on table #{qualified_table_name}") if validation?(name)
        validation = Domgen::Sql::Validation.new(self, name, options, &block)
        validation_values[name.to_s] = validation
        validation
      end
    end

    facet.enhance(DataModule) do

      def sql_id_hierarchy_check
        (@sql_id_hierarchy_check ||= [])
      end

      def sql_relationships_match_check
        (@sql_relationships_match_check ||= [])
      end

      def sql_declared_validations_check
        (@sql_declared_validations_check ||= [])
      end

      def entities_to_analyze_id_namespace
        data_module.entities.select(&:sql_analysis?).select { |entity| entity.abstract? && entity.extends.nil? }
      end

      def references_to_analyze
        data_module.entities.
          select { |entity| entity.sql_analysis? && entity.concrete? && entity.transaction_time? }.
          collect { |entity| entity.attributes.select { |attribute| attribute.sql_analysis? && attribute.reference? && attribute.referenced_entity.sql_analysis? && attribute.referenced_entity.transaction_time? } }.
          flatten
      end

      def entities_with_validations
        data_module.entities.select(&:sql_analysis?).select { |entity| !entity.sql.validations.empty? }
      end

      def standard_corruption_checks?
        !entities_to_analyze_id_namespace.empty? || !references_to_analyze.empty? || !entities_with_validations.empty?
      end

      def post_complete
        entities = data_module.sql_analysis.entities_to_analyze_id_namespace
        corruption_check_entity = data_module.repository.sql_analysis.corruption_check_entity
        unless entities.empty?
          entities.each do |entity|
            sql_id_hierarchy_check <<
              "INSERT INTO #{corruption_check_entity.sql.qualified_table_name}(#{corruption_check_entity.attribute_by_name(:Category).sql.quoted_column_name}, #{corruption_check_entity.attribute_by_name(:Description).sql.quoted_column_name}, #{corruption_check_entity.attribute_by_name(:Sql).sql.quoted_column_name})
  VALUES ('Id Namespace', 'An Id must not be appear in multiple tables in the #{entity.qualified_name} hierarchy','
SELECT #{entity.primary_key.sql.quoted_column_name}, COUNT(*) AS IDCount
 FROM (
#{entity.concrete_subtypes.select { |entity| entity.sql_analysis? }.collect do |subtype|
                "SELECT #{entity.primary_key.sql.quoted_column_name}, ''#{subtype.name}'' AS Type FROM #{subtype.sql.qualified_table_name}"
              end.join("\nUNION\n")}
 ) f
 GROUP BY #{entity.primary_key.sql.quoted_column_name}
 HAVING COUNT(*) > 1')
GO"
          end
        end

        references_to_analyze =  data_module.sql_analysis.references_to_analyze
        unless references_to_analyze.empty?
          references_to_analyze.each do |attribute|
            sql_relationships_match_check <<
              "INSERT INTO #{corruption_check_entity.sql.qualified_table_name}(#{corruption_check_entity.attribute_by_name(:Category).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:Description).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:Sql).sql.quoted_column_name})
  VALUES ('Relationship', 'The attribute #{attribute.qualified_name} must reference an object and the object must not be deleted before the #{attribute.entity.qualified_name} is deleted','
SELECT PK.DeletedAt
 FROM
  #{attribute.entity.sql.qualified_table_name} PK
 LEFT JOIN #{if attribute.referenced_entity.final?
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    attribute.referenced_entity.sql.qualified_table_name
             else
               (
                 entity_list = attribute.referenced_entity.compatible_concrete_types
                 entity_list.collect do |subtype|
                   "SELECT #{subtype.primary_key.sql.quoted_column_name}, DeletedAt FROM #{subtype.sql.qualified_table_name}"
                 end.join("\nUNION\n")
               )
             end
              } FK ON PK.#{attribute.sql.column_name} = FK.#{attribute.referenced_entity.primary_key.sql.column_name}
 WHERE
  PK.#{attribute.sql.column_name} IS NOT NULL AND (FK.#{attribute.entity.primary_key.sql.quoted_column_name} IS NULL OR (PK.DeletedAt IS NULL AND FK.DeletedAt IS NOT NULL) OR (PK.DeletedAt > FK.DeletedAt))
')
GO"
          end
        end

        entities_with_validations = data_module.sql_analysis.entities_with_validations
        unless entities_with_validations.empty?
          entities_with_validations.each do |entity|
            entity.sql.validations.select{|v| !v.invariant_negative_sql.nil? }.each do |validation|
              unless entity.sql_analysis.validation?("DeclaredValidationCheck" + validation.name.to_s)
                sql_declared_validations_check <<
                  "INSERT INTO #{corruption_check_entity.sql.qualified_table_name}(#{corruption_check_entity.attribute_by_name(:Category).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:Description).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:CommonTableExpression).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:Sql).sql.quoted_column_name})
  VALUES ('EntityValidation', 'Enforce the validation #{entity.sql.qualified_table_name}.#{validation.name}: #{ (validation.description || '').gsub("'","''")}',#{cte = validation.invariant_common_table_expression; cte.nil? ? "NULL" : "'" + (cte.strip.gsub("'","''") + "\n'")},'#{validation.invariant_negative_sql.gsub("'","''").strip}')
GO"
              end
            end
          end
        end
        data_module.entities.select{|entity|entity.sql?}.each do |entity|
          entity.attributes.select{|attribute|attribute.sql? && attribute.reference? && :many != attribute.inverse.multiplicity}.each do |attribute|
            unless entity.sql_analysis.validation?("DeclaredValidationCheckReferenceMultiplicity")
              sql_declared_validations_check <<
                "INSERT INTO #{corruption_check_entity.sql.qualified_table_name}(#{corruption_check_entity.attribute_by_name(:Category).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:Description).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:Sql).sql.quoted_column_name})
  VALUES ('Reference Multiplicity', 'The reference #{attribute.qualified_name} to #{attribute.referenced_entity.qualified_name} must be a multiplicity of #{attribute.inverse.multiplicity}','
SELECT O.#{attribute.referenced_entity.primary_key.sql.quoted_column_name} AS #{attribute.referenced_entity.name}#{attribute.referenced_entity.primary_key.sql.column_name}, COUNT(S.#{attribute.referenced_entity.primary_key.sql.quoted_column_name}) AS RelatedCount
FROM #{attribute.referenced_entity.sql.qualified_table_name} O
LEFT JOIN #{entity.sql.qualified_table_name} S ON S.#{attribute.sql.quoted_column_name} = O.#{attribute.referenced_entity.primary_key.sql.quoted_column_name}#{if entity.transaction_time?
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         " AND S.DeletedAt IS NULL"
                                                                                                                                                               end}
#{if attribute.referenced_entity.transaction_time?
                                                                                                                                                                       "WHERE O.DeletedAt IS NULL\n"
  end}GROUP BY O.#{attribute.referenced_entity.primary_key.sql.quoted_column_name}
HAVING COUNT(S.#{entity.primary_key.sql.quoted_column_name}) #{:one == attribute.inverse.multiplicity ? '<> 1' : '> 1' }')
GO"
            end
          end
        end
      end
    end
  end
end