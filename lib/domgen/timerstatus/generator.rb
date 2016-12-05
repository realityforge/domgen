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

Domgen::Generator.define([:timerstatus],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper]) do |g|
  g.template_set(:timerstatus_integration_test) do |template_set|
    template_set.erb_template(:repository,
                              'integration_test.java.erb',
                              'test/java/#{repository.timerstatus.qualified_integration_test_name.gsub(".","/")}.java',
                              :additional_facets => [:jaxrs],
                              :guard => 'repository.application.code_deployable?')
  end

  g.template_set(:timerstatus_filter) do |template_set|
    template_set.erb_template(:repository,
                              'blocking_filter.java.erb',
                              'main/java/#{repository.timerstatus.qualified_blocking_filter_name.gsub(".","/")}.java',
                              :additional_facets => [:jaxrs])
  end

  g.template_set(:timerstatus => [:timerstatus_filter, :timerstatus_integration_test])
end
