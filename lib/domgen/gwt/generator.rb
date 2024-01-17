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
                         [Domgen::Java::Helper, Domgen::Gwt::Helper]) do |g|

  g.template_set(:gwt_client_jso) do |template_set|
    template_set.erb_template(:repository,
                              'rdate.java.erb',
                              'main/java/#{repository.gwt.qualified_rdate_name.gsub(".","/")}.java')
    template_set.erb_template(:struct,
                              'struct.java.erb',
                              'main/java/#{struct.gwt.qualified_name.gsub(".","/")}.java',
                              :additional_facets => [:json])
  end

  %w(main test).each do |type|
    g.template_set(:"gwt_client_#{type}_jso_qa_support") do |template_set|
      template_set.erb_template(:repository,
                                'callback_success_answer.java.erb',
                                type + '/java/#{repository.gwt.qualified_callback_success_answer_name.gsub(".","/")}.java',
                                :guard => 'repository.gwt.generate_sync_callbacks?')
      template_set.erb_template(:repository,
                                'callback_failure_answer.java.erb',
                                type + '/java/#{repository.gwt.qualified_callback_failure_answer_name.gsub(".","/")}.java',
                                :guard => 'repository.gwt.generate_sync_callbacks?')
      template_set.erb_template(:repository,
                                'client_test.java.erb',
                                type + '/java/#{repository.gwt.qualified_client_test_name.gsub(".","/")}.java',
                                :guard => '!repository.gwt.custom_base_client_test?')
      template_set.erb_template(:repository,
                                'abstract_client_test.java.erb',
                                type + '/java/#{repository.gwt.qualified_abstract_client_test_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'abstract_test_sting_injector.java.erb',
                                type + '/java/#{repository.gwt.qualified_abstract_test_sting_injector_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'test_fragment.java.erb',
                                type + '/java/#{repository.gwt.qualified_test_fragment_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'value_util.java.erb',
                                type + '/java/#{repository.gwt.qualified_value_util_name.gsub(".","/")}.java')
      template_set.erb_template(:repository,
                                'default_test_injector.java.erb',
                                type + '/java/#{repository.gwt.qualified_default_test_injector_name.gsub(".","/")}.java',
                                :guard => '!repository.gwt.custom_default_test_injector?')
    end
  end

  g.template_set(:gwt_client_callback) do |template_set|
    template_set.erb_template(:repository,
                              'async_callback.java.erb',
                              'main/java/#{repository.gwt.qualified_async_callback_name.gsub(".","/")}.java',
                              :guard => 'repository.gwt.generate_sync_callbacks?')
    template_set.erb_template(:repository,
                              'async_error_callback.java.erb',
                              'main/java/#{repository.gwt.qualified_async_error_callback_name.gsub(".","/")}.java',
                              :guard => 'repository.gwt.generate_sync_callbacks?')
  end

  g.template_set(:gwt_client_module) do |template_set|
    template_set.erb_template(:repository,
                              'aggregate_sting_fragment.java.erb',
                              'main/java/#{repository.gwt.qualified_aggregate_sting_fragment_name.gsub(".","/")}.java',
                              :guard => '!repository.gwt.sting_includes.empty?')
    template_set.erb_template(:repository,
                              'abstract_sting_injector.java.erb',
                              'main/java/#{repository.gwt.qualified_abstract_sting_injector_name.gsub(".","/")}.java',
                              :guard => 'repository.gwt.enable_sting_injectors?')
  end

  g.template_set(:gwt_client_gwt_model_module) do |template_set|
    template_set.erb_template(:repository,
                              'model_module.xml.erb',
                              'main/java/#{repository.gwt.qualified_model_module_name.gsub(".","/")}.gwt.xml')
  end

  g.template_set(:gwt_client_gwt_modules) do |template_set|
    template_set.erb_template(:repository,
                              'app_module.xml.erb',
                              'main/java/#{repository.gwt.qualified_app_module_name.gsub(".","/")}.gwt.xml')
    template_set.erb_template(:repository,
                              'dev_module.xml.erb',
                              'main/java/#{repository.gwt.qualified_dev_module_name.gsub(".","/")}.gwt.xml')
    template_set.erb_template(:repository,
                              'prod_module.xml.erb',
                              'main/java/#{repository.gwt.qualified_prod_module_name.gsub(".","/")}.gwt.xml')
    template_set.erb_template('gwt.entrypoint',
                              'entrypoint_module.xml.erb',
                              'main/java/#{entrypoint.qualified_gwt_module_name.gsub(".","/")}.gwt.xml',
                              :guard => 'entrypoint.gwt_repository.repository.gwt.enable_entrypoints?')
  end

  g.template_set(:gwt_client_app) do |template_set|
    template_set.erb_template(:repository,
                              'abstract_application.java.erb',
                              'main/java/#{repository.gwt.qualified_abstract_application_name.gsub(".","/")}.java',
                              :guard => 'repository.gwt.enable_entrypoints?')
    template_set.erb_template('gwt.entrypoint',
                              'entrypoint.java.erb',
                              'main/java/#{entrypoint.qualified_entrypoint_name.gsub(".","/")}.java',
                              :guard => 'entrypoint.gwt_repository.repository.gwt.enable_entrypoints?')
  end

  g.template_set(:gwt_client => [:gwt_client_jso, :gwt_client_callback])
  g.template_set(:gwt => [:gwt_client])
end
