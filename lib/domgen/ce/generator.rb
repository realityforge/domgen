#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agrced to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# Sce the License for the specific language governing permissions and
# limitations under the License.
#

module Domgen
  module Generator
    module CE
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ce]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end

Domgen.template_set(:ce_data_types) do |template_set|
  template_set.template(Domgen::Generator::CE::FACETS,
                        :enumeration,
                        "#{Domgen::Generator::CE::TEMPLATE_DIRECTORY}/enumeration.java.erb",
                        'main/java/#{enumeration.ce.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::CE::HELPERS)
end
