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
    VALID_ENTITY_FACETS = [:sql, :mssql, :pgsql, :sql_analysis]
    VALID_ANALYSIS_FACETS = VALID_ENTITY_FACETS + [:ee, :ejb, :action]

    class HandwrittenCorruptionCheck
      attr_reader :id
      attr_reader :owner
      attr_reader :required_data_modules
      attr_reader :category
      attr_reader :description
      attr_reader :common_table_expression
      attr_reader :sql
      attr_reader :query_option

      def initialize(id, owner, required_data_modules, values)
        @id = id
        @owner = owner
        @required_data_modules = required_data_modules.freeze
        @category = values.fetch('Category')
        @description = values.fetch('Description')
        @common_table_expression = values['CommonTableExpression']
        @sql = values.fetch('Sql')
        @query_option = values['QueryOption']
        freeze
      end
    end
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

      attr_writer :corruption_checks_test_base

      def corruption_checks_test_base
        @corruption_checks_test_base || repository.jpa.qualified_standalone_entity_test_name
      end

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

      attr_writer :handwritten_corruption_checks_directory

      def handwritten_corruption_checks
        @handwritten_corruption_checks ||= load_handwritten_corruption_checks.freeze
      end

      def data_modules_referenced_by_sql(sql)
        repository.data_modules.select do |data_module|
          data_module.sql? &&
            sql.match?(/(?<![A-Za-z0-9_])(?:\[#{Regexp.escape(data_module.sql.schema)}\]|#{Regexp.escape(data_module.sql.schema)})\s*\./i)
        end
      end

      def generated_corruption_checks
        @generated_corruption_checks ||= repository.data_modules.flat_map do |data_module|
          next [] unless data_module.sql_analysis?
          data_module.sql_analysis.corruption_checks.collect do |sql|
            required_modules = ([data_module] + data_modules_referenced_by_sql(sql)).
              reject { |required_module| required_module == analysis_data_module }.
              uniq
            {
              :owner => data_module,
              :required_data_modules => required_modules,
              :sql => sql
            }.freeze
          end
        end.freeze
      end

      def corruption_check_owner?(data_module)
        generated_corruption_checks.any? { |check| check[:owner] == data_module } ||
          handwritten_corruption_checks.any? { |check| check.owner == data_module }
      end

      def corruption_registration_sql_for_owner(data_module)
        generated = generated_corruption_checks.
          select { |check| check[:owner] == data_module }.
          collect { |check| decorate_generated_corruption_check(check) }
        handwritten = handwritten_corruption_checks.
          select { |check| check.owner == data_module }.
          collect { |check| handwritten_corruption_check_sql(check) }
        (generated + handwritten).join("\n")
      end

      def corruption_registration_sql(data_modules)
        selected_modules = data_modules.to_set
        generated = generated_corruption_checks.select do |check|
          check[:required_data_modules].all? { |data_module| selected_modules.include?(data_module) }
        end.collect { |check| decorate_generated_corruption_check(check) }
        handwritten = handwritten_corruption_checks.select do |check|
          check.required_data_modules.all? { |data_module| selected_modules.include?(data_module) }
        end.collect { |check| handwritten_corruption_check_sql(check) }
        (generated + handwritten).join("\n")
      end

      def profile_requirement_guard_sql(owner, sql)
        required_modules = data_modules_referenced_by_sql(sql).
          reject { |data_module| data_module == owner || data_module == analysis_data_module }
        return nil if required_modules.empty?
        names = required_modules.collect { |data_module| "(#{sql_string(data_module.name)})" }.join(',')
        profile_module_table = analysis_data_module.entity_by_name(:TestProfileModule).sql.qualified_table_name
        "OBJECT_ID('#{profile_module_table}') IS NULL OR NOT EXISTS (SELECT R.[Name] FROM (VALUES #{names}) R([Name]) WHERE NOT EXISTS (SELECT 1 FROM #{profile_module_table} PM WHERE PM.[Name] = R.[Name]))"
      end

      def pre_complete
        unless repository.data_module_by_name?(self.analysis_data_module_name)
          repository.data_module(self.analysis_data_module_name)
        end
        analysis_data_module = self.analysis_data_module
        analysis_data_module.disable_facets_not_in(Domgen::SqlAnalysis::VALID_ANALYSIS_FACETS)

        analysis_data_module.entity(:CorruptionCheck) do |t|
          t.disable_facets_not_in(Domgen::SqlAnalysis::VALID_ANALYSIS_FACETS)
          t.sql.row_source = :deployment
          t.integer(:Id, :primary_key => true)
          t.string(:OwnerModule, 100)
          t.text(:RequiredModules)
          t.string(:Category, 50)
          t.string(:Description, 500, :unique => true)
          t.text(:CommonTableExpression, :nullable => true)
          t.text(:Sql)
          t.text(:QueryOption, :nullable => true)
        end

        analysis_data_module.entity(:TestProfile) do |t|
          t.disable_facets_not_in(Domgen::SqlAnalysis::VALID_ANALYSIS_FACETS)
          t.sql.row_source = :deployment
          t.string(:Name, 100, :primary_key => true)
          t.string(:PersistenceFingerprint, 64)
        end

        analysis_data_module.entity(:TestProfileModule) do |t|
          t.disable_facets_not_in(Domgen::SqlAnalysis::VALID_ANALYSIS_FACETS)
          t.sql.row_source = :deployment
          t.string(:Name, 100, :primary_key => true)
          t.string(:SchemaName, 100)
          t.boolean(:CheckConstraints)
        end

        analysis_data_module.entity(:DataIssue) do |t|
          t.integer(:Id, :primary_key => true)
          t.string(:Category, 50)
          t.string(:Description, 500, :unique => true)
          t.text(:ViewSql, :nullable => true)
        end
      end

      private

      def decorate_generated_corruption_check(check)
        table_name = corruption_check_entity.sql.qualified_table_name
        sql = check[:sql].dup
        insert_prefix = "INSERT INTO #{table_name}("
        replacement = "#{insert_prefix}#{corruption_check_entity.attribute_by_name(:OwnerModule).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:RequiredModules).sql.quoted_column_name},"
        Domgen.error("Unable to decorate generated corruption check owned by #{check[:owner].name}") unless sql.sub!(insert_prefix, replacement)
        values = "VALUES (#{sql_string(check[:owner].name)},#{sql_string(check[:required_data_modules].collect(&:name).join(','))},"
        Domgen.error("Unable to decorate generated corruption check values owned by #{check[:owner].name}") unless sql.sub!(/VALUES\s*\(/, values)
        sql
      end

      def handwritten_corruption_check_sql(check)
        attributes = [
          corruption_check_entity.attribute_by_name(:OwnerModule),
          corruption_check_entity.attribute_by_name(:RequiredModules),
          corruption_check_entity.attribute_by_name(:Category),
          corruption_check_entity.attribute_by_name(:Description),
          corruption_check_entity.attribute_by_name(:CommonTableExpression),
          corruption_check_entity.attribute_by_name(:Sql),
          corruption_check_entity.attribute_by_name(:QueryOption)
        ]
        values = [
          check.owner.name,
          check.required_data_modules.collect(&:name).join(','),
          check.category,
          check.description,
          check.common_table_expression,
          check.sql,
          check.query_option
        ]
        "INSERT INTO #{corruption_check_entity.sql.qualified_table_name}(#{attributes.collect { |attribute| attribute.sql.quoted_column_name }.join(',')})\n  VALUES (#{values.collect { |value| sql_string(value) }.join(',')})\nGO"
      end

      def sql_string(value)
        value.nil? ? 'NULL' : "'#{value.to_s.gsub("'", "''")}'"
      end

      def load_handwritten_corruption_checks
        return [] unless @handwritten_corruption_checks_directory
        checks = []
        descriptions = {}
        ids = {}
        Dir.glob(File.join(@handwritten_corruption_checks_directory, '*.yml')).sort.each do |filename|
          owner_name = File.basename(filename, '.yml')
          owner = repository.data_module_by_name(owner_name)
          values = YAML.safe_load(File.read(filename), :permitted_classes => [], :aliases => false)
          values.each do |id, check_values|
            id = Integer(id)
            required_names = check_values.fetch('RequiredModules')
            required_modules = required_names.collect { |name| repository.data_module_by_name(name) }
            Domgen.error("Handwritten corruption check #{id} owned by #{owner.name} must require its owner") unless required_modules.include?(owner)
            observed_modules = data_modules_referenced_by_sql([check_values['CommonTableExpression'], check_values.fetch('Sql')].compact.join("\n")).
              reject { |data_module| data_module == analysis_data_module }
            unless observed_modules.to_set == required_modules.to_set
              Domgen.error("Handwritten corruption check #{id} declares #{required_modules.collect(&:name).sort.join(', ')} but SQL touches #{observed_modules.collect(&:name).sort.join(', ')}")
            end
            description = check_values.fetch('Description')
            Domgen.error("Duplicate handwritten corruption check id #{id}") if ids[id]
            Domgen.error("Duplicate handwritten corruption check description #{description}") if descriptions[description]
            ids[id] = true
            descriptions[description] = true
            checks << Domgen::SqlAnalysis::HandwrittenCorruptionCheck.new(id,
                                                                           owner,
                                                                           required_modules,
                                                                           check_values)
          end
        end
        checks.sort_by(&:id)
      end
    end

    facet.enhance(Entity) do
      def validation_values
        @validation_values ||= {}
      end
      def validations
        validation_values.values
      end

      def validation_by_name(name)
        validation = validation_values[name.to_s]
        Domgen.error("No validation named #{name} defined on table #{qualified_table_name}") unless validation
        validation
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
        !sql_id_hierarchy_check.empty? || !sql_relationships_match_check.empty? || !sql_declared_validations_check.empty?
      end

      def corruption_checks
        sql_id_hierarchy_check + sql_relationships_match_check + sql_declared_validations_check
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
            entity.sql.validations.sort_by{|validation|validation.name.to_s}.select{|v| !v.invariant_negative_sql.nil? }.each do |validation|
              unless entity.sql_analysis.validation?("DeclaredValidationCheck" + validation.name.to_s)
                sql_declared_validations_check <<
                  "INSERT INTO #{corruption_check_entity.sql.qualified_table_name}(#{corruption_check_entity.attribute_by_name(:Category).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:Description).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:CommonTableExpression).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:Sql).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:QueryOption).sql.quoted_column_name})
  VALUES ('EntityValidation', 'Enforce the validation #{entity.sql.qualified_table_name}.#{validation.name}: #{ (validation.description || '').gsub("'","''")}',#{cte = validation.invariant_common_table_expression; cte.nil? ? "NULL" : "'" + (cte.strip.gsub("'","''") + "\n'")},'#{validation.invariant_negative_sql.gsub("'","''").strip}',#{option = validation.query_option; option.nil? ? "NULL" : "'" + option.gsub("'","''") + "'"})
GO"
              end
            end
          end
        end
        data_module.entities.select{|entity|entity.sql?}.each do |entity|
          entity.attributes.select{|attribute|attribute.sql? && attribute.reference? && :many != attribute.inverse.multiplicity}.each do |attribute|
            if entity.sql_analysis.validation?("#{entity.name}ReferenceMultiplicity")
              entity_validation = entity.sql_analysis.validation_by_name("#{entity.name}ReferenceMultiplicity")
              sql_declared_validations_check <<
                "INSERT INTO #{corruption_check_entity.sql.qualified_table_name}(#{corruption_check_entity.attribute_by_name(:Category).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:Description).sql.quoted_column_name},#{corruption_check_entity.attribute_by_name(:Sql).sql.quoted_column_name})
  VALUES ('Reference Multiplicity', 'The reference #{attribute.qualified_name} to #{attribute.referenced_entity.qualified_name} must be a multiplicity of #{attribute.inverse.multiplicity}','#{entity_validation.negative_sql}')
GO"
            else
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
