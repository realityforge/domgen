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
    module JMS
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jms]
      HELPERS = [Domgen::Java::Helper, Domgen::JAXB::Helper]
    end
  end
end
Domgen.template_set(:jms) do |template_set|
  template_set.template(Domgen::Generator::JMS::FACETS,
                        :method,
                        "#{Domgen::Generator::JMS::TEMPLATE_DIRECTORY}/mdb.java.erb",
                        'main/java/#{method.jms.qualified_mdb_name.gsub(".","/")}.java',
                        Domgen::Generator::JMS::HELPERS,
                        :guard => 'method.jms.mdb?')
  template_set.template(Domgen::Generator::JMS::FACETS,
                        :service,
                        "#{Domgen::Generator::JMS::TEMPLATE_DIRECTORY}/abstract_router.java.erb",
                        'main/java/#{service.jms.qualified_abstract_router_name.gsub(".","/")}.java',
                        Domgen::Generator::JMS::HELPERS,
                        :guard => 'service.jms.router?')
end
