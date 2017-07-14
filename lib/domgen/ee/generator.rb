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

Domgen::Generator.define([:ee],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::JPA::Helper, Domgen::Java::Helper, Domgen::JAXB::Helper, Domgen::Jackson::Helper]) do |g|


  g.template_set(:ee_cdi_qualifier) do |template_set|
    template_set.erb_template(:repository,
                              'cdi_qualifier.java.erb',
                              'main/java/#{repository.ee.qualified_cdi_qualifier_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'cdi_qualifier_literal.java.erb',
                              'main/java/#{repository.ee.qualified_cdi_qualifier_literal_name.gsub(".","/")}.java')
  end

  g.template_set(:ee_data_types) do |template_set|
    template_set.erb_template(:enumeration,
                              'enumeration.java.erb',
                              'main/java/#{enumeration.ee.qualified_name.gsub(".","/")}.java')
    template_set.erb_template(:struct,
                              'struct.java.erb',
                              'main/java/#{struct.ee.qualified_name.gsub(".","/")}.java')
  end

  g.template_set(:ee_messages) do |template_set|
    template_set.erb_template(:message,
                              'message.java.erb',
                              'main/java/#{message.ee.qualified_name.gsub(".","/")}.java')
  end

  g.template_set(:ee_messages_qa) do |template_set|
    template_set.erb_template(:repository,
                              'message_module.java.erb',
                              'test/java/#{repository.ee.qualified_message_module_name.gsub(".","/")}.java')
    template_set.erb_template(:message,
                              'message_literal.java.erb',
                              'test/java/#{message.ee.qualified_message_literal_name.gsub(".","/")}.java',
                              :guard => 'message.ee.generate_test_literal?')
  end

  g.template_set(:ee_exceptions) do |template_set|
    template_set.erb_template(:exception,
                              'exception.java.erb',
                              'main/java/#{exception.ee.qualified_name.gsub(".","/")}.java')
  end

  g.template_set(:ee_web_xml) do |template_set|
    template_set.erb_template(:repository, 'web.xml.erb', 'main/webapp/WEB-INF/web.xml')
  end

  g.template_set(:ee_beans_xml) do |template_set|
    template_set.erb_template(:repository, 'beans.xml.erb', 'main/webapp/WEB-INF/beans.xml')
  end

  g.template_set(:ee_model_beans_xml) do |template_set|
    template_set.erb_template(:repository, 'model_beans.xml.erb', 'main/resources/beans.xml')
  end

  g.template_set(:ee_filter) do |template_set|
    template_set.erb_template(:repository,
                              'abstract_filter.java.erb',
                              'main/java/#{repository.ee.qualified_abstract_filter_name.gsub(".","/")}.java')
  end

  g.template_set(:ee_integration) do |template_set|
    template_set.erb_template(:repository,
                              'abstract_app_server.java.erb',
                              'main/java/#{repository.ee.qualified_abstract_app_server_name.gsub(".","/")}.java',
                              :guard => 'repository.application.code_deployable?')
    template_set.erb_template(:repository,
                              'app_server_factory.java.erb',
                              'main/java/#{repository.ee.qualified_app_server_factory_name.gsub(".","/")}.java',
                              :guard => 'repository.application.code_deployable?')
    template_set.erb_template(:repository,
                              'abstract_integration_test.java.erb',
                              'main/java/#{repository.ee.qualified_abstract_integration_test_name.gsub(".","/")}.java',
                              :guard => 'repository.application.code_deployable?')
    template_set.erb_template(:repository,
                              'base_integration_test.java.erb',
                              'main/java/#{repository.ee.qualified_base_integration_test_name.gsub(".","/")}.java',
                              :guard => 'repository.application.code_deployable? && !repository.ee.custom_base_integration_test?')
  end

  g.template_set(:ee_aggregate_integration_test) do |template_set|
    template_set.erb_template(:repository,
                              'aggregate_integration_test.java.erb',
                              'test/java/#{repository.ee.qualified_aggregate_integration_test_name.gsub(".","/")}.java')
  end

  g.template_set(:ee_integration_test) do |template_set|
    template_set.erb_template(:repository,
                              'deploy_test.java.erb',
                              'test/java/#{repository.ee.qualified_deploy_test_name.gsub(".","/")}.java',
                              :guard => 'repository.application.code_deployable?')
  end

  g.template_set(:ee => [:jaxrs, :jpa, :ejb, :jmx, :jws, :jms, :ee_exceptions, :ee_data_types, :ee_messages])
end
