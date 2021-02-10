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

Domgen::Generator.define([:jms],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper, Domgen::JAXB::Helper]) do |g|
  g.template_set(:jms_model) do |template_set|
    template_set.erb_template(:repository,
                              'constants_container.java.erb',
                              'main/java/#{repository.jms.qualified_constants_container_name.gsub(".","/")}.java')
  end

  g.template_set(:jms_services) do |template_set|
    template_set.erb_template(:method,
                              'mdb.java.erb',
                              'main/java/#{method.jms.qualified_mdb_name.gsub(".","/")}.java',
                              :guard => 'method.jms.mdb?')
    template_set.erb_template(:service,
                              'abstract_router.java.erb',
                              'main/java/#{service.jms.qualified_abstract_router_name.gsub(".","/")}.java',
                              :guard => 'service.jms.router?')
  end

  g.template_set(:jms_qa_support) do |template_set|
    template_set.erb_template(:repository,
                              'test_module.java.erb',
                              'test/java/#{repository.jms.qualified_test_module_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'abstract_test_broker.java.erb',
                              'test/java/#{repository.jms.qualified_abstract_test_broker_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'test_broker_factory.java.erb',
                              'test/java/#{repository.jms.qualified_test_broker_factory_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'test_broker.java.erb',
                              'test/java/#{repository.jms.qualified_test_broker_name.gsub(".","/")}.java',
                              :guard => '!repository.jms.custom_test_broker?')
  end
  g.template_set(:jms => [:jms_services, :jms_model])
end
