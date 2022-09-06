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

Domgen::Generator.define([:jpa],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::JPA::Helper, Domgen::Java::Helper, Domgen::JAXB::Helper]) do |g|
  g.template_set(:jpa_model) do |template_set|
    template_set.erb_template(:repository,
                              'unit_descriptor.java.erb',
                              'main/java/#{repository.jpa.qualified_unit_descriptor_name.gsub(".","/")}.java',
                              :guard => 'repository.jpa.include_default_unit? || repository.jpa.standalone_persistence_units?')
    template_set.erb_template(:entity,
                              'entity.java.erb',
                              'main/java/#{entity.jpa.qualified_name.gsub(".","/")}.java')
    template_set.erb_template(:entity,
                              'metamodel.java.erb',
                              'main/java/#{entity.jpa.qualified_metamodel_name.gsub(".","/")}.java')
    template_set.erb_template(:data_module,
                              'entity_package_info.java.erb',
                              'main/java/#{data_module.jpa.server_entity_package.gsub(".","/")}/package-info.java',
                              :guard => 'data_module.entities.any?{|e|e.jpa?}')
  end

  %w(main test).each do |type|
    g.template_set(:"jpa_#{type}_qa_external") do |template_set|
      template_set.erb_template(:repository,
                                'persistent_test_module.java.erb',
                                type + '/java/#{repository.jpa.qualified_persistent_test_module_name.gsub(".","/")}.java',
                                :guard => 'repository.jpa.include_default_unit?')
      template_set.erb_template('jpa.persistence_unit',
                                'raw_test_module.java.erb',
                                type + '/java/#{persistence_unit.qualified_raw_test_module_name.gsub(".","/")}.java',
                                :guard => 'persistence_unit.raw_test_mode?')
      template_set.erb_template('jpa.persistence_unit',
                                'persistence_unit_test_util.java.erb',
                                type + '/java/#{persistence_unit.qualified_persistence_unit_test_util_name.gsub(".","/")}.java',
                                :guard => 'persistence_unit.generate_test_util?')
      template_set.erb_template('jpa.persistence_unit',
                                'persistence_unit_module.java.erb',
                                type + '/java/#{persistence_unit.qualified_persistence_unit_module_name.gsub(".","/")}.java',
                                :guard => 'persistence_unit.generate_test_util?')
      template_set.erb_template(:repository,
                                'dao_module.java.erb',
                                type + '/java/#{repository.jpa.qualified_dao_module_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'test_factory_module.java.erb',
                                type + '/java/#{repository.jpa.qualified_test_factory_module_name.gsub(".","/")}.java')
      template_set.erb_template(:data_module,
                                'abstract_test_factory.java.erb',
                                type + '/java/#{data_module.jpa.qualified_abstract_test_factory_name.gsub(".","/")}.java',
                                :guard => 'data_module.jpa.generate_test_factory?')
    end
    g.template_set(:"jpa_#{type}_qa") do |template_set|
      template_set.erb_template(:repository,
                                'abstract_entity_test.java.erb',
                                type + '/java/#{repository.jpa.qualified_abstract_entity_test_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'base_entity_test.java.erb',
                                type + '/java/#{repository.jpa.qualified_base_entity_test_name.gsub(".","/")}.java',
                                :guard => '!repository.jpa.custom_base_entity_test?')
      template_set.erb_template(:repository,
                                'standalone_entity_test.java.erb',
                                type + '/java/#{repository.jpa.qualified_standalone_entity_test_name.gsub(".","/")}.java')
    end
    g.template_set(:"jpa_#{type}_qa_aggregate") do |template_set|
      template_set.erb_template(:repository,
                                'aggregate_entity_test.java.erb',
                                type + '/java/#{repository.jpa.qualified_aggregate_entity_test_name.gsub(".","/")}.java')
    end
  end

  g.template_set(:jpa_dao_test) do |template_set|
    template_set.erb_template(:entity,
                              'abstract_model_test.java.erb',
                              'test/java/#{entity.jpa.qualified_abstract_model_test_name.gsub(".","/")}.java',
                              :guard => 'entity.jpa.non_standard_model_constraints? || !entity.jpa.interfaces.empty?')
    template_set.erb_template(:dao,
                              'dao_test.java.erb',
                              'test/java/#{dao.jpa.qualified_dao_test_name.gsub(".","/")}.java',
                              :guard => '!dao.jpa.extensions.empty? || dao.queries.any?{|q|q.jpa? && !q.jpa.standard_query?}')
  end

  g.template_set(:jpa_ejb_dao) do |template_set|
    template_set.erb_template(:dao,
                              'dao.java.erb',
                              'main/java/#{dao.jpa.qualified_dao_name.gsub(".","/")}.java',
                              :guard => '!dao.repository? || dao.entity.jpa?')
    template_set.erb_template(:dao,
                              'dao_service.java.erb',
                              'main/java/#{dao.jpa.qualified_dao_service_name.gsub(".","/")}.java',
                              :guard => '!dao.repository? || dao.entity.jpa?')
    template_set.erb_template(:data_module,
                              'dao_package_info.java.erb',
                              'main/java/#{data_module.jpa.server_dao_entity_package.gsub(".","/")}/package-info.java',
                              :guard => 'data_module.entities.any?{|e|e.jpa?}')
  end

  g.template_set(:jpa_application_persistence_xml) do |template_set|
    template_set.erb_template(:repository,
                              'application_persistence.xml.erb',
                              'main/resources/META-INF/persistence.xml',
                              :guard => 'repository.jpa.application_xmls?')
  end

  g.template_set(:jpa_application_orm_xml) do |template_set|
    template_set.erb_template(:repository,
                              'application_orm.xml.erb',
                              'main/resources/META-INF/orm.xml',
                              :guard => 'repository.jpa.application_xmls?')
  end

  g.template_set(:jpa_model_persistence_xml) do |template_set|
    template_set.erb_template(:repository,
                              'application_persistence.xml.erb',
                              'main/resources/META-INF/persistence.xml',
                              :guard => 'repository.jpa.model_xmls?',
                              :name => 'model/META-INF/persistence.xml')
  end

  g.template_set(:jpa_model_orm_xml) do |template_set|
    template_set.erb_template(:repository,
                              'application_orm.xml.erb',
                              'main/resources/META-INF/orm.xml',
                              :guard => 'repository.jpa.model_xmls?',
                              :name => 'model/META-INF/orm.xml')
  end

  g.template_set(:jpa_template_persistence_xml) do |template_set|
    template_set.erb_template(:repository,
                              'template_persistence.xml.erb',
                              'main/resources/META-INF/domgen/templates/persistence.xml',
                              :guard => 'repository.jpa.template_xmls?')
  end

  g.template_set(:jpa_template_orm_xml) do |template_set|
    template_set.erb_template(:repository,
                              'template_orm.xml.erb',
                              'main/resources/META-INF/domgen/templates/orm.xml',
                              :guard => 'repository.jpa.template_xmls?')
  end

  g.template_set(:jpa_test_persistence_xml) do |template_set|
    template_set.erb_template(:repository,
                              'test_persistence.xml.erb',
                              'test/resources/META-INF/persistence.xml',
                              :guard => 'repository.jpa.test_xmls?')
  end

  g.template_set(:jpa_test_orm_xml) do |template_set|
    template_set.erb_template(:repository,
                              'test_orm.xml.erb',
                              'test/resources/META-INF/orm.xml',
                              :guard => 'repository.jpa.test_xmls?')
  end

  g.template_set(:jpa => [:jpa_application_orm_xml, :jpa_application_persistence_xml, :jpa_model])
end
