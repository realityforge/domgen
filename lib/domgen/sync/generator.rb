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

Domgen::Generator.define([:sync],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper, Domgen::JPA::Helper]) do |g|
  g.template_set(:sync_core_ejb) do |template_set|
    template_set.erb_template(:data_module,
                              'sync_ejb.java.erb',
                              'main/java/#{data_module.sync.qualified_sync_ejb_name.gsub(".","/")}.java',
                              :guard => 'data_module.sync.master_data_module? && data_module.repository.sync.sync_out_of_master?')
    template_set.erb_template(:data_module,
                              'sync_context_impl.java.erb',
                              'main/java/#{data_module.sync.qualified_sync_context_impl_name.gsub(".","/")}.java',
                              :guard => 'data_module.sync.master_data_module? && data_module.repository.sync.sync_out_of_master?')
    template_set.erb_template(:data_module,
                              'sync_service_test.java.erb',
                              'test/java/#{data_module.sync.qualified_sync_service_test_name.gsub(".","/")}.java',
                              :guard => 'data_module.sync.master_data_module? && data_module.repository.sync.sync_out_of_master?',
                              :additional_helpers => [Domgen::Sync::SyncTestHelper])
  end
  g.template_set(:sync_remote_sync_service) do |template_set|
      template_set.erb_template(:repository,
                                'remote_sync_service.java.erb',
                                'main/java/#{repository.sync.qualified_remote_sync_service_name.gsub(".","/")}.java',
                                :guard => '!repository.sync.standalone?')
      template_set.erb_template(:repository,
                                'remote_sync_service_impl.java.erb',
                                'main/java/#{repository.sync.qualified_remote_sync_service_impl_name.gsub(".","/")}.java',
                                :guard => '!repository.sync.standalone?')
  end
  g.template_set(:sync_master_ejb_impl) do |template_set|
    template_set.erb_template(:data_module,
                              'sync_temp_factory.java.erb',
                              'main/java/#{data_module.sync.qualified_sync_temp_factory_name.gsub(".","/")}.java',
                              :guard => 'data_module.sync.master_data_module?')
    template_set.erb_template(:data_module,
                              'abstract_master_sync_ejb.java.erb',
                              'main/java/#{data_module.sync.qualified_abstract_master_sync_ejb_name.gsub(".","/")}.java',
                              :guard => 'data_module.sync.master_data_module?')
    template_set.erb_template(:data_module,
                              'abstract_sync_temp_population_impl.java.erb',
                              'main/java/#{data_module.sync.qualified_abstract_sync_temp_population_impl_name.gsub(".","/")}.java',
                              :guard => 'data_module.sync.master_data_module?')
  end
  g.template_set(:sync_db_common) do |template_set|
    template_set.erb_template(:entity,
                              'import.sql.erb',
                              '#{entity.data_module.sql.schema}/import/#{entity.data_module.sql.schema}.#{entity.sql.table_name}.sql',
                              :guard => 'entity.data_module.sync.sync_temp_data_module? && !entity.abstract?')
  end
  g.template_set(:sync_sql) do |template_set|
    template_set.erb_template(:data_module,
                              'binary_to_base64.sql.erb',
                              '#{data_module.sql.schema}/functions/#{data_module.sql.schema}.fnConvertBinaryToBase64.sql',
                              :additional_facets => [:mssql],
                              :guard => 'data_module.sync.sync_temp_data_module?')
    template_set.erb_template(:data_module,
                              'mssql_remove_sync_temp_query_plans.sql.erb',
                              '#{data_module.sql.schema}/stored-procedures/#{data_module.sql.schema}.spRemoveCachedSyncTempQueryPlans.sql',
                              :additional_facets => [:mssql],
                              :guard => 'data_module.sync.sync_temp_data_module?')
    template_set.erb_template(:data_module,
                              'mssql_reseed_procs.sql.erb',
                              '#{data_module.sql.schema}/stored-procedures/reseed_procs.sql',
                              :guard => 'data_module.sync.sync_temp_data_module?',
                              :additional_facets => [:mssql])
    template_set.erb_template(:data_module,
                              'mssql_remove_master_query_plans.sql.erb',
                              '#{data_module.sql.schema}/stored-procedures/#{data_module.sql.schema}.spRemoveCachedMasterQueryPlans.sql',
                              :additional_facets => [:mssql],
                              :guard => 'data_module.sync.master_data_module?')
  end
  g.template_set(:sync_pgsql) do |template_set|
    template_set.erb_template(:data_module,
                              'pg_reseed_procs.sql.erb',
                              '#{data_module.sql.schema}/stored-procedures/reseed_procs.sql',
                              :additional_facets => [:pgsql],
                              :guard => 'data_module.sync.sync_temp_data_module?')
  end
  %w(test main).each do |type|
    g.template_set(:"sync_master_#{type}_qa") do |template_set|
      template_set.erb_template(:data_module,
                                'master_sync_service_test.java.erb',
                                type + '/java/#{data_module.sync.qualified_master_sync_service_test_name.gsub(".","/")}.java',
                                :guard => 'data_module.sync.master_data_module?')
      template_set.erb_template(:repository,
                                'test_module.java.erb',
                                type + '/java/#{repository.sync.qualified_test_module_name.gsub(".","/")}.java',
                                :guard => 'repository.sync.standalone?')
      template_set.erb_template(:service,
                                'test_service.java.erb',
                                type + '/java/#{service.sync.qualified_test_service_name.gsub(".","/")}.java',
                                :guard => 'service.sync.sync_temp_population_service?')
    end
  end

  g.template_set(:sync_master_ejb => [:sync_master_ejb_impl, :sync_master_test_qa])
  g.template_set(:sync_ejb => [:sync_core_ejb, :sync_master_ejb])
end
