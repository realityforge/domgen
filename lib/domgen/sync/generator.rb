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
  module Generator
    module Sync
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      HELPERS = [Domgen::Java::Helper, Domgen::JPA::Helper]
      FACETS = [:sql, :sync]
    end
  end
end
Domgen.template_set(:sync_core_ejb) do |template_set|
  template_set.template(Domgen::Generator::Sync::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Sync::TEMPLATE_DIRECTORY}/sync_ejb.java.erb",
                        'main/java/#{data_module.sync.qualified_sync_ejb_name.gsub(".","/")}.java',
                        Domgen::Generator::Sync::HELPERS,
                        :guard => 'data_module.sync.master_data_module? && data_module.repository.sync.sync_out_of_master?')
  template_set.template(Domgen::Generator::Sync::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Sync::TEMPLATE_DIRECTORY}/sync_context_impl.java.erb",
                        'main/java/#{data_module.sync.qualified_sync_context_impl_name.gsub(".","/")}.java',
                        Domgen::Generator::Sync::HELPERS,
                        :guard => 'data_module.sync.master_data_module? && data_module.repository.sync.sync_out_of_master?')
  template_set.template(Domgen::Generator::Sync::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Sync::TEMPLATE_DIRECTORY}/sync_service_test.java.erb",
                        'test/java/#{data_module.sync.qualified_sync_service_test_name.gsub(".","/")}.java',
                        Domgen::Generator::Sync::HELPERS,
                        :guard => 'data_module.sync.master_data_module? && data_module.repository.sync.sync_out_of_master?')
end
Domgen.template_set(:sync_master_ejb_impl) do |template_set|
  template_set.template(Domgen::Generator::Sync::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Sync::TEMPLATE_DIRECTORY}/sync_temp_factory.java.erb",
                        'main/java/#{data_module.sync.qualified_sync_temp_factory_name.gsub(".","/")}.java',
                        Domgen::Generator::Sync::HELPERS,
                        :guard => 'data_module.sync.master_data_module?')
  template_set.template(Domgen::Generator::Sync::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Sync::TEMPLATE_DIRECTORY}/abstract_master_sync_ejb.java.erb",
                        'main/java/#{data_module.sync.qualified_abstract_master_sync_ejb_name.gsub(".","/")}.java',
                        Domgen::Generator::Sync::HELPERS,
                        :guard => 'data_module.sync.master_data_module?')
  template_set.template(Domgen::Generator::Sync::FACETS,
                        :data_module,
                        "#{Domgen::Generator::Sync::TEMPLATE_DIRECTORY}/abstract_sync_temp_population_impl.java.erb",
                        'main/java/#{data_module.sync.qualified_abstract_sync_temp_population_impl_name.gsub(".","/")}.java',
                        Domgen::Generator::Sync::HELPERS,
                        :guard => 'data_module.sync.master_data_module?')
end
Domgen.template_set(:sync_sql) do |template_set|
  template_set.template(Domgen::Generator::Sync::FACETS + [:mssql],
                        :data_module,
                        "#{Domgen::Generator::Sync::TEMPLATE_DIRECTORY}/binary_to_base64.sql.erb",
                        '#{data_module.name}/functions/#{data_module.name}.fnConvertBinaryToBase64.sql',
                        Domgen::Generator::Sync::HELPERS,
                        :guard => 'data_module.sync.sync_temp_data_module?')
  template_set.template(Domgen::Generator::Sync::FACETS + [:mssql],
                        :data_module,
                        "#{Domgen::Generator::Sync::TEMPLATE_DIRECTORY}/mssql_reseed_procs.sql.erb",
                        '#{data_module.name}/stored-procedures/reseed_procs.sql',
                        Domgen::Generator::Sync::HELPERS,
                        :guard => 'data_module.sync.sync_temp_data_module?')
end
Domgen.template_set(:sync_pgsql) do |template_set|
  template_set.template(Domgen::Generator::Sync::FACETS + [:pgsql],
                        :data_module,
                        "#{Domgen::Generator::Sync::TEMPLATE_DIRECTORY}/pg_reseed_procs.sql.erb",
                        '#{data_module.name}/stored-procedures/reseed_procs.sql',
                        Domgen::Generator::Sync::HELPERS,
                        :guard => 'data_module.sync.sync_temp_data_module?')
end
%w(test main).each do |type|
  Domgen.template_set(:"sync_master_#{type}_qa") do |template_set|
    template_set.template(Domgen::Generator::Sync::FACETS,
                          :data_module,
                          "#{Domgen::Generator::Sync::TEMPLATE_DIRECTORY}/master_sync_service_test.java.erb",
                          type + '/java/#{data_module.sync.qualified_master_sync_service_test_name.gsub(".","/")}.java',
                          Domgen::Generator::Sync::HELPERS,
                          :guard => 'data_module.sync.master_data_module?')
  end
end

Domgen.template_set(:sync_master_ejb => [:sync_master_ejb_impl, :sync_master_test_qa])
Domgen.template_set(:sync_ejb => [:sync_core_ejb, :sync_master_ejb])
