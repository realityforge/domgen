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

Domgen::Generator.define([:arez],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper, Domgen::Arez::Helper]) do |g|
  g.template_set(:arez_entity) do |template_set|
    template_set.erb_template(:entity,
                              'entity.java.erb',
                              'main/java/#{entity.arez.qualified_name.gsub(".","/")}.java')
    template_set.erb_template(:dao,
                              'domgen_repository_extension.java.erb',
                              'main/java/#{dao.arez.qualified_domgen_repository_extension_name.gsub(".","/")}.java',
                              :guard => '!dao.entity.abstract? && dao.queries.any?{|q|q.arez?}')
    template_set.erb_template(:repository,
                              'locator_factory.java.erb',
                              'main/java/#{repository.arez.qualified_locator_factory_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'locator_dagger_module.java.erb',
                              'main/java/#{repository.arez.qualified_locator_dagger_module_name.gsub(".","/")}.java',
                              :guard => 'repository.gwt.enable_dagger?')
  end

  %w(main test).each do |type|
    g.template_set(:"arez_#{type}_qa_external") do |template_set|
      template_set.erb_template(:data_module,
                                'abstract_test_factory.java.erb',
                                type + '/java/#{data_module.arez.qualified_abstract_test_factory_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'test_factory_module.java.erb',
                                type + '/java/#{repository.arez.qualified_test_factory_module_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'no_action_annotation.java.erb',
                                type + '/java/#{repository.arez.qualified_no_action_annotation_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'dao_test_module.java.erb',
                                type + '/java/#{repository.arez.qualified_dao_test_module_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'entity_complete_module.java.erb',
                                type + '/java/#{repository.arez.qualified_entity_complete_module_name.gsub(".","/")}.java')
    end
  end
end
