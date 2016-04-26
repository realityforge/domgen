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
    module Appconfig
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:appconfig]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end

Domgen.template_set(:appconfig_integration_test) do |template_set|
  template_set.template(Domgen::Generator::Appconfig::FACETS + [:jaxrs],
                        :repository,
                        "#{Domgen::Generator::Appconfig::TEMPLATE_DIRECTORY}/integration_test.java.erb",
                        'test/java/#{repository.appconfig.qualified_integration_test_name.gsub(".","/")}.java',
                        Domgen::Generator::Appconfig::HELPERS)
end

Domgen.template_set(:appconfig => [:appconfig_integration_test])
