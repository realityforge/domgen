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
    module Timerstatus
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:timerstatus]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end

Domgen.template_set(:timerstatus_integration_test) do |template_set|
  template_set.template(Domgen::Generator::Timerstatus::FACETS + [:jaxrs],
                        :repository,
                        "#{Domgen::Generator::Timerstatus::TEMPLATE_DIRECTORY}/integration_test.java.erb",
                        'test/java/#{repository.timerstatus.qualified_integration_test_name.gsub(".","/")}.java',
                        Domgen::Generator::Timerstatus::HELPERS,
                        :guard => 'repository.application.code_deployable?')
end

Domgen.template_set(:timerstatus_filter) do |template_set|
  template_set.template(Domgen::Generator::Timerstatus::FACETS + [:jaxrs],
                        :repository,
                        "#{Domgen::Generator::Timerstatus::TEMPLATE_DIRECTORY}/blocking_filter.java.erb",
                        'main/java/#{repository.timerstatus.qualified_blocking_filter_name.gsub(".","/")}.java',
                        Domgen::Generator::Timerstatus::HELPERS)
end

Domgen.template_set(:timerstatus => [:timerstatus_filter, :timerstatus_integration_test])
