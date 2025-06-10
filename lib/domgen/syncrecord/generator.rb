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

Domgen::Generator.define([:syncrecord],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper]) do |g|
  g.template_set(:syncrecord_abstract_service) do |template_set|
    template_set.erb_template(:service,
                              'abstract_service.java.erb',
                              'main/java/#{service.syncrecord.qualified_abstract_service_name.gsub(".","/")}.java',
                              :guard => 'service.syncrecord.sync_methods?')
    template_set.erb_template(:repository,
                              'sync_record_locks.java.erb',
                              'main/java/#{repository.syncrecord.qualified_sync_record_locks_name.gsub(".","/")}.java',
                              :guard => 'repository.syncrecord.sync_methods?')
    template_set.erb_template(:repository,
                              'test_module.java.erb',
                              'test/java/#{repository.syncrecord.qualified_test_module_name.gsub(".","/")}.java',
                              :guard => 'repository.syncrecord.sync_methods?')
  end

  g.template_set(:syncrecord_control_rest_service) do |template_set|
    template_set.erb_template(:repository,
                              'control_rest_service.java.erb',
                              'main/java/#{repository.syncrecord.qualified_control_rest_service_name.gsub(".","/")}.java',
                              :additional_facets => [:jaxrs],
                              :guard => 'repository.syncrecord.sync_methods?')
  end

  g.template_set(:syncrecord_sql) do |template_set|
    template_set.erb_template(:repository,
                              'cleanup_historic.sql.erb',
                              'import-hooks/post/cleanup_historic_datasources.sql',
                              :guard => 'repository.syncrecord.data_sources?')
  end

  g.template_set(:syncrecord_datasources) do |template_set|
    template_set.erb_template(:repository,
                              'datasources.java.erb',
                              'main/java/#{repository.syncrecord.qualified_datasources_name.gsub(".","/")}.java',
                              :guard => 'repository.syncrecord.data_sources?')
  end
end
