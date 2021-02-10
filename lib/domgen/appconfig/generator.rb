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

Domgen::Generator.define([:appconfig],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper]) do |g|
  g.template_set(:appconfig_feature_flag_container) do |template_set|
    template_set.erb_template(:repository,
                              'feature_flag_container.java.erb',
                              'main/java/#{repository.appconfig.qualified_feature_flag_container_name.gsub(".","/")}.java',
                              :guard => 'repository.appconfig.feature_flags?')
    template_set.erb_template(:repository,
                              'system_setting_container.java.erb',
                              'main/java/#{repository.appconfig.qualified_system_setting_container_name.gsub(".","/")}.java',
                              :guard => 'repository.appconfig.system_settings.any?{|s|!s.feature_flag?}')
  end

  g.template_set(:appconfig_mssql) do |template_set|
    template_set.erb_template(:repository,
                              'feature_flag_mssql_populator.sql.erb',
                              'db-hooks/post/#{repository.name}_FeatureFlagPopulator.sql',
                              :guard => 'repository.appconfig.system_settings?')
  end

  g.template_set(:appconfig_pgsql) do |template_set|
    template_set.erb_template(:repository,
                              'feature_flag_populator.sql.erb',
                              'db-hooks/post/#{repository.name}_FeatureFlagPopulator.sql',
                              :additional_facets => [:mssql],
                              :guard => 'repository.appconfig.system_settings?')
  end
end
