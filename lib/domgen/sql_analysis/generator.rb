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

Domgen::Generator.define([:sql_analysis],
                         "#{File.dirname(__FILE__)}/templates",
                         []) do |g|
  g.template_set(:sql_analysis_sql) do |template_set|
    template_set.erb_template(:data_module,
                              'corruption_checks.erb',
                              '#{data_module.repository.sql_analysis.analysis_data_module.sql.schema}/finalize/#{data_module.name}_corruption_checks.sql',
                              :guard => 'data_module.sql_analysis.standard_corruption_checks?')
    template_set.erb_template(:repository,
                              'mssql_check_corruptions.sql.erb',
                              '#{repository.sql_analysis.analysis_data_module.sql.schema}/stored-procedures/#{repository.sql_analysis.analysis_data_module.sql.schema}.spCheckCorruptions.sql',
                              :additional_facets => [:mssql])
    template_set.erb_template(:repository,
                              'mssql_perform_checks.sql.erb',
                              '#{repository.sql_analysis.analysis_data_module.sql.schema}/stored-procedures/#{repository.sql_analysis.analysis_data_module.sql.schema}.spPerformChecks.sql',
                              :additional_facets => [:mssql])
  end
end
