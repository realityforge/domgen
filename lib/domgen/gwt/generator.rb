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

Domgen::Generator.define([:gwt],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper]) do |g|
  g.template_set(:gwt_client_event) do |template_set|
    template_set.erb_template(:message,
                              'event.java.erb',
                              'main/java/#{message.gwt.qualified_event_name.gsub(".","/")}.java')
  end

  g.template_set(:gwt_client_config) do |template_set|
    template_set.erb_template(:repository,
                              'debug_config.java.erb',
                              'main/java/#{repository.gwt.qualified_debug_config_name.gsub(".","/")}.java')
  end

  g.template_set(:gwt_client_jso) do |template_set|
    template_set.erb_template(:struct,
                              'struct.java.erb',
                              'main/java/#{struct.gwt.qualified_interface_name.gsub(".","/")}.java',
                              :additional_facets => [:json],
                              :guard => 'struct.gwt.generate_overlay?')
    template_set.erb_template(:struct,
                              'struct_factory.java.erb',
                              'main/java/#{struct.gwt.qualified_factory_name.gsub(".","/")}.java',
                              :additional_facets => [:json],
                              :guard => 'struct.gwt.generate_overlay?')
    template_set.erb_template(:struct,
                              'jso_struct.java.erb',
                              'main/java/#{struct.gwt.qualified_jso_name.gsub(".","/")}.java',
                              :additional_facets => [:json],
                              :guard => 'struct.gwt.generate_overlay?')
    template_set.erb_template(:struct,
                              'java_struct.java.erb',
                              'main/java/#{struct.gwt.qualified_java_name.gsub(".","/")}.java',
                              :additional_facets => [:json],
                              :guard => 'struct.gwt.generate_overlay?')
  end

  %w(main test).each do |type|
    g.template_set(:"gwt_client_#{type}_jso_qa_support") do |template_set|
      template_set.erb_template(:repository,
                                'callback_success_answer.java.erb',
                                type + '/java/#{repository.gwt.qualified_callback_success_answer_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'callback_failure_answer.java.erb',
                                type + '/java/#{repository.gwt.qualified_callback_failure_answer_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'client_test.java.erb',
                                type + '/java/#{repository.gwt.qualified_client_test_name.gsub(".","/")}.java',
                                :guard => '!repository.gwt.custom_base_client_test?')
      template_set.erb_template(:repository,
                                'abstract_client_test.java.erb',
                                type + '/java/#{repository.gwt.qualified_abstract_client_test_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'support_test_module.java.erb',
                                type + '/java/#{repository.gwt.qualified_support_test_module_name.gsub(".","/")}.java')
      template_set.erb_template(:data_module,
                                'abstract_struct_test_factory.java.erb',
                                'main/java/#{data_module.gwt.qualified_abstract_struct_test_factory_name.gsub(".","/")}.java',
                                :guard => 'data_module.gwt.generate_struct_factory?')
    end
  end

  %w(main test).each do |type|
    g.template_set(:"gwt_client_#{type}_ux_qa_support") do |template_set|
      template_set.erb_template(:repository,
                                'client_ux_test.java.erb',
                                type + '/java/#{repository.gwt.qualified_client_ux_test_name.gsub(".","/")}.java',
                                :guard => '!repository.gwt.custom_base_ux_client_test?')
      template_set.erb_template(:repository,
                                'abstract_client_ux_test.java.erb',
                                type + '/java/#{repository.gwt.qualified_abstract_client_ux_test_name.gsub(".","/")}.java')
    end
  end

  g.template_set(:gwt_client_callback) do |template_set|
    template_set.erb_template(:repository,
                              'async_callback.java.erb',
                              'main/java/#{repository.gwt.qualified_async_callback_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'async_error_callback.java.erb',
                              'main/java/#{repository.gwt.qualified_async_error_callback_name.gsub(".","/")}.java')
  end

  g.template_set(:gwt_client_module) do |template_set|
    template_set.erb_template(:repository,
                              'aggregate_module.java.erb',
                              'main/java/#{repository.gwt.qualified_aggregate_module_name.gsub(".","/")}.java')
  end

  g.template_set(:gwt_client_gwt_model_module) do |template_set|
    template_set.erb_template(:repository,
                              'model_module.xml.erb',
                              'main/resources/#{repository.gwt.qualified_model_module_name.gsub(".","/")}.gwt.xml')
  end

  g.template_set(:gwt_client_gwt_modules) do |template_set|
    template_set.erb_template(:repository,
                              'app_module.xml.erb',
                              'main/resources/#{repository.gwt.qualified_app_module_name.gsub(".","/")}.gwt.xml')
    template_set.erb_template(:repository,
                              'dev_module.xml.erb',
                              'main/resources/#{repository.gwt.qualified_dev_module_name.gsub(".","/")}.gwt.xml')
    template_set.erb_template(:repository,
                              'prod_module.xml.erb',
                              'main/resources/#{repository.gwt.qualified_prod_module_name.gsub(".","/")}.gwt.xml')
    template_set.erb_template('gwt.entrypoint',
                              'entrypoint_module.xml.erb',
                              'main/resources/#{entrypoint.qualified_gwt_module_name.gsub(".","/")}.gwt.xml',
                              :guard => 'entrypoint.gwt_repository.repository.gwt.enable_entrypoints?')
  end

  g.template_set(:gwt_client_app) do |template_set|
    template_set.erb_template(:repository,
                              'abstract_ginjector.java.erb',
                              'main/java/#{repository.gwt.qualified_abstract_ginjector_name.gsub(".","/")}.java',
                              :guard => 'repository.gwt.enable_entrypoints?')
    template_set.erb_template(:repository,
                              'abstract_application.java.erb',
                              'main/java/#{repository.gwt.qualified_abstract_application_name.gsub(".","/")}.java',
                              :guard => 'repository.gwt.enable_entrypoints?')
    template_set.erb_template('gwt.entrypoint',
                              'entrypoint.java.erb',
                              'main/java/#{entrypoint.qualified_entrypoint_name.gsub(".","/")}.java',
                              :guard => 'entrypoint.gwt_repository.repository.gwt.enable_entrypoints?')
    template_set.erb_template('gwt.entrypoint',
                              'entrypoint_module.java.erb',
                              'main/java/#{entrypoint.qualified_entrypoint_module_name.gsub(".","/")}.java',
                              :guard => 'entrypoint.gwt_repository.repository.gwt.enable_entrypoints?')
  end

  g.template_set(:gwt_client => [:gwt_client_event, :gwt_client_jso, :gwt_client_callback])
  g.template_set(:gwt => [:gwt_client])
end
