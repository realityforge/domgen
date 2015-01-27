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
    module JPA
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jpa, :sql]
      HELPERS = [Domgen::JPA::Helper, Domgen::Java::Helper, Domgen::JAXB::Helper]
    end
  end
end
Domgen.template_set(:jpa_model) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :repository,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/unit_descriptor.java.erb",
                        'main/java/#{repository.jpa.qualified_unit_descriptor_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :entity,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/entity.java.erb",
                        'main/java/#{entity.jpa.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :entity,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/metamodel.java.erb",
                        'main/java/#{entity.jpa.qualified_metamodel_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :data_module,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/entity_package_info.java.erb",
                        'main/java/#{data_module.jpa.server_entity_package.gsub(".","/")}/package-info.java',
                        Domgen::Generator::JPA::HELPERS,
                        :guard => 'data_module.entities.any?{|e|e.jpa?}')
end

%w(main test).each do |type|
  Domgen.template_set(:"jpa_#{type}_qa_external") do |template_set|
    template_set.template(Domgen::Generator::JPA::FACETS,
                          :repository,
                          "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/persistent_test_module.java.erb",
                          type + '/java/#{repository.jpa.qualified_persistent_test_module_name.gsub(".","/")}.java',
                          Domgen::Generator::JPA::HELPERS)
    template_set.template(Domgen::Generator::JPA::FACETS,
                          :repository,
                          "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/dao_module.java.erb",
                          type + '/java/#{repository.jpa.qualified_dao_module_name.gsub(".","/")}.java',
                          Domgen::Generator::JPA::HELPERS)
    template_set.template(Domgen::Generator::JPA::FACETS,
                          :repository,
                          "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/test_factory_set.java.erb",
                          type + '/java/#{repository.jpa.qualified_test_factory_set_name.gsub(".","/")}.java',
                          Domgen::Generator::JPA::HELPERS)
    template_set.template(Domgen::Generator::JPA::FACETS,
                          :data_module,
                          "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/abstract_test_factory.java.erb",
                          type + '/java/#{data_module.jpa.qualified_abstract_test_factory_name.gsub(".","/")}.java',
                          Domgen::Generator::JPA::HELPERS)
  end
  Domgen.template_set(:"jpa_#{type}_qa") do |template_set|
    template_set.template(Domgen::Generator::JPA::FACETS,
                          :repository,
                          "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/abstract_entity_test.java.erb",
                          type + '/java/#{repository.jpa.qualified_abstract_entity_test_name.gsub(".","/")}.java',
                          Domgen::Generator::JPA::HELPERS)
  end
  Domgen.template_set(:"jpa_#{type}_qa_aggregate") do |template_set|
    template_set.template(Domgen::Generator::JPA::FACETS,
                          :repository,
                          "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/aggregate_entity_test.java.erb",
                          type + '/java/#{repository.jpa.qualified_aggregate_entity_test_name.gsub(".","/")}.java',
                          Domgen::Generator::JPA::HELPERS)
  end
end

Domgen.template_set(:jpa_dao_test) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :dao,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/dao_test.java.erb",
                        'test/java/#{dao.jpa.qualified_dao_test_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS,
                        :guard => 'dao.queries.any?{|q|!q.jpa.standard_query?}')
end

Domgen.template_set(:jpa_ejb_dao) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :dao,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/dao.java.erb",
                        'main/java/#{dao.jpa.qualified_dao_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS,
                        :guard => '!dao.repository? || dao.entity.jpa?')
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :dao,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/dao_service.java.erb",
                        'main/java/#{dao.jpa.qualified_dao_service_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS,
                        :guard => '!dao.repository? || dao.entity.jpa?')
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :data_module,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/dao_package_info.java.erb",
                        'main/java/#{data_module.jpa.server_dao_entity_package.gsub(".","/")}/package-info.java',
                        Domgen::Generator::JPA::HELPERS,
                        :guard => 'data_module.entities.any?{|e|e.jpa?}')
end

Domgen.template_set(:jpa_persistence_xml) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :repository,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/persistence.xml.erb",
                        'main/resources/META-INF/persistence.xml')
end

Domgen.template_set(:jpa_orm_xml) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :repository,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/orm.xml.erb",
                        'main/resources/META-INF/orm.xml')
end

Domgen.template_set(:jpa_test_persistence_xml) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :repository,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/persistence.xml.erb",
                        'test/resources/META-INF/persistence.xml')
end

Domgen.template_set(:jpa => [:jpa_orm_xml, :jpa_persistence_xml, :jpa_model])
