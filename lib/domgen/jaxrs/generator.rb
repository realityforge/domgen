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
    module JaxRS
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jaxrs]
      HELPERS = [Domgen::Java::Helper, Domgen::JaxRS::Helper]
    end
  end
end
Domgen.template_set(:jaxrs) do |template_set|
  template_set.template(Domgen::Generator::JaxRS::FACETS,
                        :repository,
                        "#{Domgen::Generator::JaxRS::TEMPLATE_DIRECTORY}/abstract_application.java.erb",
                        'main/java/#{repository.jaxrs.qualified_abstract_application_name.gsub(".","/")}.java',
                        Domgen::Generator::JaxRS::HELPERS)
  template_set.template(Domgen::Generator::JaxRS::FACETS,
                        :service,
                        "#{Domgen::Generator::JaxRS::TEMPLATE_DIRECTORY}/service.java.erb",
                        'main/java/#{service.jaxrs.qualified_service_name.gsub(".","/")}.java',
                        Domgen::Generator::JaxRS::HELPERS)
  template_set.template(Domgen::Generator::JaxRS::FACETS,
                        :service,
                        "#{Domgen::Generator::JaxRS::TEMPLATE_DIRECTORY}/boundary.java.erb",
                        'main/java/#{service.jaxrs.qualified_boundary_name.gsub(".","/")}.java',
                        Domgen::Generator::JaxRS::HELPERS)
end
