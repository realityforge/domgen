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
                         [Domgen::JPA::Helper, Domgen::Java::Helper, Domgen::Jackson::Helper]) do |g|


  g.template_set(:ee_data_types) do |template_set|
    template_set.erb_template(:enumeration,
                              'enumeration.java.erb',
                              'main/java/#{enumeration.ee.qualified_name.gsub(".","/")}.java')
    template_set.erb_template(:struct,
                              'struct.java.erb',
                              'main/java/#{struct.ee.qualified_name.gsub(".","/")}.java')
  end

  g.template_set(:ee_constants) do |template_set|
    template_set.erb_template(:repository,
                              'jndi_resource_constants.java.erb',
                              'main/java/#{repository.ee.qualified_jndi_resource_constants_name.gsub(".","/")}.java',
                              :guard => 'repository.ee.custom_jndi_resources?')
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

  %w(main test).each do |type|
    g.template_set(:"ee_#{type}_qa") do |template_set|
      template_set.erb_template(:enumeration,
                                'abstract_enumeration_test.java.erb',
                                'test/java/#{enumeration.ee.qualified_abstract_enumeration_test_name.gsub(".","/")}.java',
                                :guard => '!enumeration.ee.interfaces.empty?')
    end
    g.template_set(:"ee_#{type}_qa_aggregate") do |template_set|
      template_set.erb_template(:repository,
                                'aggregate_data_type_test.java.erb',
                                type + '/java/#{repository.ee.qualified_aggregate_data_type_test_name.gsub(".","/")}.java')
    end
  end

  g.template_set(:ee => [:jaxrs, :jpa, :ejb, :jms, :ee_exceptions, :ee_data_types, :ee_messages])
end
