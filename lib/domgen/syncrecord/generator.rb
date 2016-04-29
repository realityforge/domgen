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
    module Syncrecord
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:syncrecord]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end

Domgen.template_set(:syncrecord_abstract_service) do |template_set|
  template_set.template(Domgen::Generator::Syncrecord::FACETS,
                        :service,
                        "#{Domgen::Generator::Syncrecord::TEMPLATE_DIRECTORY}/abstract_service.java.erb",
                        'main/java/#{service.syncrecord.qualified_abstract_service_name.gsub(".","/")}.java',
                        Domgen::Generator::Syncrecord::HELPERS,
                        :guard => 'service.syncrecord.sync_methods?')
  template_set.template(Domgen::Generator::Syncrecord::FACETS,
                        :repository,
                        "#{Domgen::Generator::Syncrecord::TEMPLATE_DIRECTORY}/sync_record_locks.java.erb",
                        'main/java/#{repository.syncrecord.qualified_sync_record_locks_name.gsub(".","/")}.java',
                        Domgen::Generator::Syncrecord::HELPERS,
                        :guard => 'repository.syncrecord.sync_methods?')
  template_set.template(Domgen::Generator::Syncrecord::FACETS,
                        :repository,
                        "#{Domgen::Generator::Syncrecord::TEMPLATE_DIRECTORY}/test_module.java.erb",
                        'test/java/#{repository.syncrecord.qualified_test_module_name.gsub(".","/")}.java',
                        Domgen::Generator::Syncrecord::HELPERS,
                        :guard => 'repository.syncrecord.sync_methods?')
end

Domgen.template_set(:syncrecord_control_rest_service) do |template_set|
  template_set.template(Domgen::Generator::Syncrecord::FACETS + [:jaxrs],
                        :repository,
                        "#{Domgen::Generator::Syncrecord::TEMPLATE_DIRECTORY}/control_rest_service.java.erb",
                        'main/java/#{repository.syncrecord.qualified_control_rest_service_name.gsub(".","/")}.java',
                        Domgen::Generator::Syncrecord::HELPERS,
                        :guard => 'repository.syncrecord.sync_methods?')
end

Domgen.template_set(:syncrecord_datasources) do |template_set|
  template_set.template(Domgen::Generator::Syncrecord::FACETS,
                        :repository,
                        "#{Domgen::Generator::Syncrecord::TEMPLATE_DIRECTORY}/datasources.java.erb",
                        'main/java/#{repository.syncrecord.qualified_datasources_name.gsub(".","/")}.java',
                        Domgen::Generator::Syncrecord::HELPERS,
                        :guard => 'repository.syncrecord.data_sources?')
end

Domgen.template_set(:syncrecord_integration_test) do |template_set|
  template_set.template(Domgen::Generator::Syncrecord::FACETS + [:jaxrs],
                        :repository,
                        "#{Domgen::Generator::Syncrecord::TEMPLATE_DIRECTORY}/status_integration_test.java.erb",
                        'test/java/#{repository.syncrecord.qualified_status_integration_test_name.gsub(".","/")}.java',
                        Domgen::Generator::Syncrecord::HELPERS)
end

Domgen.template_set(:syncrecord => [:syncrecord_datasources, :syncrecord_control_rest_service, :syncrecord_abstract_service])
