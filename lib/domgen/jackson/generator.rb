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
    module Jackson
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jackson]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end

Domgen.template_set(:jackson_date_util) do |template_set|
  template_set.template(Domgen::Generator::Jackson::FACETS,
                        :repository,
                        "#{Domgen::Generator::Jackson::TEMPLATE_DIRECTORY}/date_util.java.erb",
                        'main/java/#{repository.jackson.qualified_date_util_name.gsub(".","/")}.java',
                        Domgen::Generator::Jackson::HELPERS)
end

Domgen.template_set(:jackson_marshalling_tests) do |template_set|
  template_set.template(Domgen::Generator::Jackson::FACETS,
                        :repository,
                        "#{Domgen::Generator::Jackson::TEMPLATE_DIRECTORY}/marshalling_test.java.erb",
                        'test/java/#{repository.jackson.qualified_marshalling_test_name.gsub(".","/")}.java',
                        Domgen::Generator::Jackson::HELPERS)
end

Domgen.template_set(:jackson => [:jackson_date_util, :jackson_marshalling_tests])
