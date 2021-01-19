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

Domgen::Generator.define([:pgsql],
                         "#{File.dirname(__FILE__)}/templates",
                         []) do |g|
  g.template_set(:pgsql => [:sql_dbt_config]) do |template_set|
    template_set.erb_template(:repository,
                              'pgsql_database_setup.sql.erb',
                              'db-hooks/pre/database_setup.sql')
    template_set.erb_template(:data_module,
                              'pgsql_ddl.sql.erb',
                              '#{data_module.sql.schema}/schema.sql')
    template_set.erb_template(:data_module,
                              'pgsql_finalize.sql.erb',
                              '#{data_module.sql.schema}/finalize/schema_finalize.sql')
  end
end
