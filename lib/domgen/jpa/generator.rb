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

Domgen.template_set(:jpa_test_module) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :repository,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/ejb_module.java.erb",
                        'test/java/#{repository.jpa.qualified_ejb_module_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
end

# This is the same as the test module but it appears in the main tree.
# Sometimes you use guice for more than just testing...
Domgen.template_set(:jpa_module) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :repository,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/ejb_module.java.erb",
                        'main/java/#{repository.jpa.qualified_ejb_module_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
end

Domgen.template_set(:jpa_ejb_dao) do |template_set|
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :entity,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/ejb.java.erb",
                        'main/java/#{entity.jpa.qualified_dao_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :entity,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/ejb_interface.java.erb",
                        'main/java/#{entity.jpa.qualified_dao_service_name.gsub(".","/")}.java',
                        Domgen::Generator::JPA::HELPERS)
  template_set.template(Domgen::Generator::JPA::FACETS,
                        :data_module,
                        "#{Domgen::Generator::JPA::TEMPLATE_DIRECTORY}/ejb_package_info.java.erb",
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

Domgen.template_set(:jpa => [:jpa_persistence_xml, :jpa_model])
