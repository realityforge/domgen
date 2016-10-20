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
    module EE
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ee]
      HELPERS = [Domgen::JPA::Helper, Domgen::Java::Helper, Domgen::JAXB::Helper, Domgen::Jackson::Helper]
    end
  end
end

Domgen.template_set(:ee_data_types) do |template_set|
  template_set.template(Domgen::Generator::EE::FACETS,
                        :enumeration,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/enumeration.java.erb",
                        'main/java/#{enumeration.ee.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS)
  template_set.template(Domgen::Generator::EE::FACETS,
                        :struct,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/struct.java.erb",
                        'main/java/#{struct.ee.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS)
end

Domgen.template_set(:ee_messages) do |template_set|
  template_set.template(Domgen::Generator::EE::FACETS,
                        :message,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/message.java.erb",
                        'main/java/#{message.ee.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS)
end

Domgen.template_set(:ee_exceptions) do |template_set|
  template_set.template(Domgen::Generator::EE::FACETS,
                        :exception,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/exception.java.erb",
                        'main/java/#{exception.ee.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS)
end

Domgen.template_set(:ee_redfish) do |template_set|
  template_set.ruby_template(Domgen::Generator::EE::FACETS,
                             :repository,
                             "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/redfish.rb",
                             'main/etc/#{repository.name}.redfish.fragment.json',
                             Domgen::Generator::EE::HELPERS,
                             :guard => 'repository.application.code_deployable?')
end

Domgen.template_set(:ee_web_xml) do |template_set|
  template_set.template(Domgen::Generator::EE::FACETS,
                        :repository,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/web.xml.erb",
                        'main/webapp/WEB-INF/web.xml',
                        Domgen::Generator::EE::HELPERS)
end

Domgen.template_set(:ee_beans_xml) do |template_set|
  template_set.template(Domgen::Generator::EE::FACETS,
                        :repository,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/beans.xml.erb",
                        'main/webapp/WEB-INF/beans.xml',
                        Domgen::Generator::EE::HELPERS)
end

Domgen.template_set(:ee_filter) do |template_set|
  template_set.template(Domgen::Generator::EE::FACETS,
                        :repository,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/abstract_filter.java.erb",
                        'main/java/#{repository.ee.qualified_abstract_filter_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS)
end

Domgen.template_set(:ee_integration) do |template_set|
  template_set.template(Domgen::Generator::EE::FACETS,
                        :repository,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/abstract_app_server.java.erb",
                        'main/java/#{repository.ee.qualified_abstract_app_server_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS,
                        :guard => 'repository.application.code_deployable?')
  template_set.template(Domgen::Generator::EE::FACETS,
                        :repository,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/app_server_factory.java.erb",
                        'main/java/#{repository.ee.qualified_app_server_factory_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS,
                        :guard => 'repository.application.code_deployable?')
  template_set.template(Domgen::Generator::EE::FACETS,
                        :repository,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/abstract_integration_test.java.erb",
                        'main/java/#{repository.ee.qualified_abstract_integration_test_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS,
                        :guard => 'repository.application.code_deployable?')
end

Domgen.template_set(:ee_integration_test) do |template_set|
  template_set.template(Domgen::Generator::EE::FACETS,
                        :repository,
                        "#{Domgen::Generator::EE::TEMPLATE_DIRECTORY}/deploy_test.java.erb",
                        'test/java/#{repository.ee.qualified_deploy_test_name.gsub(".","/")}.java',
                        Domgen::Generator::EE::HELPERS,
                        :guard => 'repository.application.code_deployable?')
end

Domgen.template_set(:ee => [:jaxrs, :jpa, :ejb, :jmx, :jws, :jms, :ee_exceptions, :ee_data_types, :ee_messages])
