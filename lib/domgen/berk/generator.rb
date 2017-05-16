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

Domgen::Generator.define([:berk],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper]) do |g|
  g.template_set(:berk_service_impl) do |template_set|
    template_set.erb_template(:repository,
                              'abstract_environment_service.java.erb',
                              'main/java/#{repository.berk.qualified_abstract_environment_service_name.gsub(".","/")}.java',
                              :additional_facets => [:ejb])
    template_set.erb_template(:repository,
                              'standard_environment_service.java.erb',
                              'main/java/#{repository.berk.qualified_standard_environment_service_name.gsub(".","/")}.java',
                              :additional_facets => [:ejb],
                              :guard => '!repository.berk.custom_environment_service?')
  end

  g.template_set(:berk_qa_support) do |template_set|
    template_set.erb_template(:repository,
                              'test_module.java.erb',
                              'test/java/#{repository.berk.qualified_test_module_name.gsub(".","/")}.java',
                              :additional_facets => [:ejb])
  end
end
