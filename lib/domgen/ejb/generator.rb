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
    module EJB
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ejb]
      HELPERS = [Domgen::Java::Helper, Domgen::JAXB::Helper]
    end
  end
end
Domgen.template_set(:ejb_services) do |template_set|
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/service.java.erb",
                        'main/java/#{service.ejb.qualified_service_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS)
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :data_module,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/service_package_info.java.erb",
                        'main/java/#{data_module.ejb.server_service_package.gsub(".","/")}/package-info.java',
                        [],
                        :guard => 'data_module.services.any?{|e|e.ejb?}')
end
Domgen.template_set(:ejb_service_facades => [:ejb_services]) do |template_set|
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/boundary_service.java.erb",
                        'main/java/#{service.ejb.qualified_boundary_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        :guard => 'service.ejb.generate_boundary?')
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/remote_service.java.erb",
                        'main/java/#{service.ejb.qualified_remote_service_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        :guard => 'service.ejb.generate_boundary? && service.ejb.remote?')
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/boundary_implementation.java.erb",
                        'main/java/#{service.ejb.qualified_boundary_implementation_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        :guard => 'service.ejb.generate_boundary?')
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :method,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/scheduler.java.erb",
                        'main/java/#{method.ejb.qualified_scheduler_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        :guard => 'method.ejb.schedule?')
end
Domgen.template_set(:ejb_glassfish_config_assets) do |template_set|
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :repository,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/glassfish_ejb.xml.erb",
                        'main/webapp/WEB-INF/glassfish-ejb-jar.xml',
                        Domgen::Generator::EJB::HELPERS,
                        :name => 'WEB-INF/glassfish-ejb-jar.xml')
end
Domgen.template_set(:ejb_glassfish_config_resources) do |template_set|
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :repository,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/glassfish_ejb.xml.erb",
                        'main/resources/META-INF/glassfish-ejb-jar.xml',
                        Domgen::Generator::EJB::HELPERS,
                        :name => 'META-INF/glassfish-ejb-jar.xml')
end

%w(main test).each do |type|
  Domgen.template_set("ejb_#{type}_qa_external") do |template_set|
    template_set.description = 'Quality Assurance/Test classes shared outside the project'
    template_set.template(Domgen::Generator::EJB::FACETS,
                          :repository,
                          "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/services_module.java.erb",
                          type + '/java/#{repository.ejb.qualified_services_module_name.gsub(".","/")}.java',
                          Domgen::Generator::EJB::HELPERS)
    template_set.template(Domgen::Generator::EJB::FACETS,
                          :repository,
                          "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/complete_module.java.erb",
                          type + '/java/#{repository.ejb.qualified_complete_module_name.gsub(".","/")}.java',
                          Domgen::Generator::EJB::HELPERS)
  end
  Domgen.template_set("ejb_#{type}_qa") do |template_set|
    template_set.description = 'Quality Assurance/Test classes shared within the project'
    template_set.template(Domgen::Generator::EJB::FACETS,
                          :repository,
                          "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/abstract_service_test.java.erb",
                          type + '/java/#{repository.ejb.qualified_abstract_service_test_name.gsub(".","/")}.java',
                          Domgen::Generator::EJB::HELPERS)
    template_set.template(Domgen::Generator::EJB::FACETS,
                          :repository,
                          "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/cdi_types_test.java.erb",
                          type + '/java/#{repository.ejb.qualified_cdi_types_test_name.gsub(".","/")}.java',
                          Domgen::Generator::EJB::HELPERS,
                          :guard => 'repository.ee.use_cdi?')
  end
  Domgen.template_set(:"ejb_#{type}_qa_aggregate") do |template_set|
    template_set.template(Domgen::Generator::EJB::FACETS,
                          :repository,
                          "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/aggregate_service_test.java.erb",
                          type + '/java/#{repository.ejb.qualified_aggregate_service_test_name.gsub(".","/")}.java',
                          Domgen::Generator::EJB::HELPERS)
  end
end

Domgen.template_set(:ejb_test_service_test) do |template_set|
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/service_test.java.erb",
                        'test/java/#{service.ejb.qualified_service_test_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        :guard => 'service.ejb.generate_base_test?')
end

Domgen.template_set(:ejb => [:ejb_service_facades, :jpa_ejb_dao])
