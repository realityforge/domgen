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
    VALID_ANALYSIS_FACETS = [:sql, :mssql, :pgsql, :ee, :jpa, :sql_analysis]
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
          t.integer(:Id, :primary_key => true)
          t.string(:Category, 50)
          t.string(:Description, 500, :unique => true)
          t.text(:Sql)

          t.query(:GetByDescription)
        end

        analysis_data_module.entity(:DataIssue) do |t|
          t.integer(:Id, :primary_key => true)
          t.string(:Category, 50)
          t.string(:Description, 500, :unique => true)
          t.text(:ViewSql, :nullable => true)
        end
      end
    end

    facet.enhance(DataModule) do
      def entities_to_analyze_id_namespace
        data_module.entities.select(&:sql_analysis?).select {|entity| entity.abstract? && entity.extends.nil?}
      end

      def references_to_analyze
        data_module.entities.
          select {|entity| entity.sql_analysis? && entity.concrete? && entity.transaction_time?}.
          collect {|entity| entity.attributes.select {|attribute| attribute.sql_analysis? && attribute.reference? && attribute.referenced_entity.sql_analysis? && attribute.referenced_entity.transaction_time?}}.
          flatten
      end

      def standard_corruption_checks?
        !entities_to_analyze_id_namespace.empty? || !references_to_analyze.empty?
      end
    end
  end
end
