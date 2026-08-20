#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Domgen.target_manager.target(:test_profile, :repository, :access_method => :test_profiles)

Domgen::Generator.define([], "#{File.dirname(__FILE__)}/templates", []) do |g|
  g.template_set(:test_profile_manifest) do |template_set|
    template_set.erb_template(:repository,
                              'manifest.json.erb',
                              'test/resources/iris/rose/test_profiles/manifest.json')
  end

  g.template_set(:test_profile_server_architecture) do |template_set|
    template_set.erb_template(:repository,
                              'module_graph.java.erb',
                              'test/java/org/realityforge/rose/architecture/server/RoseServerModuleGraph.java',
                              :name => 'server_module_graph.java',
                              :extra_data => {
                                :realm => :server,
                                :package_name => 'org.realityforge.rose.architecture.server',
                                :class_name => 'RoseServerModuleGraph'
                              })
  end

  g.template_set(:test_profile_client_architecture) do |template_set|
    template_set.erb_template(:repository,
                              'module_graph.java.erb',
                              'test/java/org/realityforge/rose/architecture/user_experience/RoseClientModuleGraph.java',
                              :name => 'client_module_graph.java',
                              :extra_data => {
                                :realm => :client,
                                :package_name => 'org.realityforge.rose.architecture.user_experience',
                                :class_name => 'RoseClientModuleGraph'
                              })
  end

  g.template_set(:test_profile_client) do |template_set|
    client_guard = 'test_profile.client? && test_profile.data_modules(:client).any?(&:arez?)'
    template_set.erb_template(:test_profile,
                              'client_profile_injector.java.erb',
                              'test/java/iris/rose/client/test/util/profile/Abstract#{test_profile.java_name}TestInjector.java',
                              :guard => client_guard)
    template_set.erb_template(:test_profile,
                              'client_profile_test.java.erb',
                              'test/java/iris/rose/client/test/util/profile/Abstract#{test_profile.java_name}Test.java',
                              :guard => client_guard)
    template_set.erb_template(:test_profile,
                              'client_profile_default_injector.java.erb',
                              'test/java/iris/rose/client/test/util/profile/#{test_profile.java_name}TestInjector.java',
                              :guard => client_guard)
    template_set.erb_template(:test_profile,
                              'client_profile_entity_test.java.erb',
                              'test/java/iris/rose/client/test/util/profile/#{test_profile.java_name}EntityTest.java',
                              :guard => client_guard)
    template_set.erb_template(:test_profile,
                              'client_profile_locator.java.erb',
                              'test/java/iris/rose/client/test/util/profile/#{test_profile.java_name}LocatorFragment.java',
                              :guard => client_guard)
    template_set.erb_template(:test_profile,
                              'client_profile_schema.java.erb',
                              'test/java/iris/rose/client/test/util/profile/#{test_profile.java_name}SystemSchemaFragment.java',
                              :guard => client_guard)
    template_set.erb_template(:test_profile,
                              'client_profile_fragment.java.erb',
                              'test/java/iris/rose/client/test/util/profile/#{test_profile.java_name}Fragment.java',
                              :guard => client_guard)
    template_set.erb_template(:repository,
                              'client_profiles.bzl.erb',
                              'test/java/iris/rose/client/test/util/client_profiles.bzl')
    template_set.erb_template(:repository,
                              'client_profile_registry.bzl.erb',
                              'test/java/iris/rose/client/test/util/client_profile_registry.bzl')
  end


  g.template_set(:test_profile_persistence_server) do |template_set|
    persistence_guard = 'test_profile.persistence?'
    database_guard = 'test_profile.database_backed?'
    server_guard = 'test_profile.server?'
    module_guard = 'data_module.jpa? && data_module.repository.test_profile_registry.module_config(data_module).supported_realms.include?(:persistence)'
    template_set.erb_template(:data_module,
                              'persistence_repository_module.java.erb',
                              'test/java/iris/rose/server/test/util/profile/#{data_module.name}PersistenceRepositoryModule.java',
                              :guard => module_guard)
    template_set.erb_template(:data_module,
                              'persistence_factory_module.java.erb',
                              'test/java/iris/rose/server/test/util/profile/#{data_module.name}PersistenceFactoryModule.java',
                              :guard => "#{module_guard} && data_module.jpa.generate_test_factory?")
    template_set.erb_template(:test_profile,
                              'persistence.xml.erb',
                              'test/resources/test_profiles/#{test_profile.path_name}/META-INF/persistence.xml',
                              :guard => database_guard)
    template_set.erb_template(:test_profile,
                              'orm.xml.erb',
                              'test/resources/test_profiles/#{test_profile.path_name}/META-INF/orm.xml',
                              :guard => database_guard)
    template_set.erb_template(:test_profile,
                              'persistence_test_module.java.erb',
                              'test/java/iris/rose/server/test/util/profile/#{test_profile.java_name}TestModule.java',
                              :guard => database_guard)
    template_set.erb_template(:test_profile,
                              'persistence_profile_module.java.erb',
                              'test/java/iris/rose/server/test/util/profile/#{test_profile.java_name}ProfileModule.java',
                              :guard => 'test_profile.persistence? || test_profile.server?')
    template_set.erb_template(:test_profile,
                              'abstract_persistence_test.java.erb',
                              'test/java/iris/rose/server/test/util/profile/Abstract#{test_profile.java_name}Test.java',
                              :guard => persistence_guard)
    template_set.erb_template(:data_module,
                              'server_service_module.java.erb',
                              'test/java/iris/rose/server/test/util/profile/#{data_module.name}ServerServiceModule.java',
                              :guard => 'data_module.ejb? && data_module.repository.test_profile_registry.module_config(data_module).supported_realms.include?(:server)')
    template_set.erb_template(:test_profile,
                              'abstract_server_test.java.erb',
                              'test/java/iris/rose/server/test/util/profile/Abstract#{test_profile.java_name}ProfileTestSupport.java',
                              :guard => "#{server_guard} && test_profile.server_support_profile?")
    template_set.erb_template(:test_profile,
                              'server_profile_test.java.erb',
                              'test/java/iris/rose/server/test/util/profile/Abstract#{test_profile.java_name}Test.java',
                              :guard => server_guard)
    template_set.erb_template(:test_profile,
                              'profile.json.erb',
                              'test/resources/test_profiles/#{test_profile.path_name}/profile.json',
                              :guard => database_guard)
    template_set.erb_template(:repository,
                              'buildr_persistence.xml.erb',
                              'test/resources/buildr/META-INF/persistence.xml')
    template_set.erb_template(:repository,
                              '../../jpa/templates/application_orm.xml.erb',
                              'test/resources/buildr/META-INF/orm.xml')
    template_set.erb_template(:repository,
                              'persistence_server_profiles.bzl.erb',
                              'test/java/iris/rose/server/test/util/persistence_profiles.bzl')
    template_set.erb_template(:repository,
                              'server_profile_runtimes.bzl.erb',
                              'test/java/iris/rose/server/test/util/server_profile_runtimes.bzl')
    template_set.erb_template(:repository,
                              'persistence_resource_profiles.bzl.erb',
                              'test/resources/persistence_profiles.bzl')
    template_set.erb_template(:repository,
                              'profile_registry.bzl.erb',
                              'test/resources/profile_registry.bzl')
  end

  g.template_set(:test_profile_persistence_database) do |template_set|
    persistence_guard = 'test_profile.database_backed?'
    template_set.erb_template(:data_module,
                              '../../action/templates/action_type_populator.sql.erb',
                              'test-profile-modules/#{Domgen::Naming.underscore(data_module.name)}/post/action_types.sql',
                              :guard => 'data_module.services.any?(&:action?)',
                              :extra_data => { :database_prefix => '', :module_action_fragment => true })
    template_set.erb_template(:data_module,
                              'corruption_checks.sql.erb',
                              'test-profile-modules/#{Domgen::Naming.underscore(data_module.name)}/integrity/corruption_checks.sql',
                              :guard => 'data_module.repository.sql_analysis.corruption_check_owner?(data_module)')
    template_set.erb_template(:test_profile,
                              'jdbt.yml.erb',
                              'test-profiles/#{test_profile.path_name}/jdbt.yml',
                              :guard => persistence_guard)
    template_set.erb_template(:test_profile,
                              'repository.yml.erb',
                              'test-profiles/#{test_profile.path_name}/repository.yml',
                              :guard => persistence_guard)
    template_set.erb_template(:test_profile,
                              'profile_integrity.sql.erb',
                              'test-profiles/#{test_profile.path_name}/setup/profile.sql',
                              :guard => persistence_guard)
    template_set.erb_template(:test_profile,
                              'profile_integrity_finalizer.sql.erb',
                              'test-profiles/#{test_profile.path_name}/verify/integrity.sql',
                              :guard => persistence_guard)
    template_set.erb_template(:test_profile,
                              'action_type_finalizer.sql.erb',
                              'test-profiles/#{test_profile.path_name}/post/action_types.sql',
                              :guard => "#{persistence_guard} && test_profile.data_modules(:persistence).any? { |data_module| :Action == data_module.name }",
                              :extra_data => { :database_prefix => '' })
    template_set.erb_template(:test_profile,
                              'common_data_analysis.sql.erb',
                              'test-profiles/#{test_profile.path_name}/post/common_data_analysis.sql',
                              :guard => "#{persistence_guard} && 'CommonDataAnalysisServer' == test_profile.name")
    template_set.erb_template(:test_profile,
                              'owned_post_hooks.sql.erb',
                              'test-profiles/#{test_profile.path_name}/post/owned_post_hooks.sql',
                              :guard => "#{persistence_guard} && test_profile.server? && %w(Delwp Tas).include?(test_profile.root.to_s)")
    template_set.erb_template(:repository,
                              'persistence_database_profiles.bzl.erb',
                              'persistence_profiles.bzl')
    template_set.erb_template(:repository,
                              'persistence_profiles_manifest.json.erb',
                              'test-profiles/manifest.json')
    template_set.erb_template(:repository,
                              'persistence_resources.bazelrc.erb',
                              'test_profiles.bazelrc')
  end
end
