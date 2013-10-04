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
    module AutoBean
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:auto_bean]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end

Domgen.template_set(:auto_bean_enumeration) do |template_set|
  template_set.template(Domgen::Generator::AutoBean::FACETS,
                        :enumeration,
                        "#{Domgen::Generator::AutoBean::TEMPLATE_DIRECTORY}/enumeration.java.erb",
                        'main/java/#{enumeration.auto_bean.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::AutoBean::HELPERS)
end

Domgen.template_set(:auto_bean_struct) do |template_set|
  template_set.template(Domgen::Generator::AutoBean::FACETS,
                        :struct,
                        "#{Domgen::Generator::AutoBean::TEMPLATE_DIRECTORY}/struct.java.erb",
                        'main/java/#{struct.auto_bean.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::AutoBean::HELPERS)
  template_set.template(Domgen::Generator::AutoBean::FACETS,
                        :repository,
                        "#{Domgen::Generator::AutoBean::TEMPLATE_DIRECTORY}/factory.java.erb",
                        'main/java/#{repository.auto_bean.qualified_factory_name.gsub(".","/")}.java',
                        Domgen::Generator::AutoBean::HELPERS)
end

Domgen.template_set(:auto_bean => [:auto_bean_enumeration, :auto_bean_struct])
