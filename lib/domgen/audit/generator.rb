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

Domgen::Generator.define([:audit],
                         "#{File.dirname(__FILE__)}/templates",
                         []) do |g|

  g.template_set(:audit_psql) do |template_set|
    template_set.erb_template(:entity,
                              'psql_view.sql.erb',
                              '#{entity.data_module.sql.schema}/views/#{entity.data_module.sql.schema}.vw#{entity.name}.sql',
                              :additional_facets => [:pgsql])
  end

  g.template_set(:audit_mssql) do |template_set|
    template_set.erb_template(:entity,
                              'mssql_view.sql.erb',
                              '#{entity.data_module.sql.schema}/views/#{entity.data_module.sql.schema}.vw#{entity.name}.sql',
                              :additional_facets => [:mssql])
    template_set.erb_template(:entity,
                              'mssql_finalize.sql.erb',
                              '#{entity.data_module.sql.schema}/finalize/#{entity.data_module.sql.schema}.vw#{entity.name}_finalize.sql',
                              :additional_facets => [:mssql])
    template_set.erb_template(:entity,
                              'mssql_triggers.sql.erb',
                              '#{entity.data_module.sql.schema}/triggers/#{entity.data_module.sql.schema}.vw#{entity.name}_triggers.sql',
                              :additional_facets => [:mssql])
  end
end
