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
    module Appcache
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:appcache]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end

Domgen.template_set(:appcache_manifest_servlet) do |template_set|
  template_set.template(Domgen::Generator::Appcache::FACETS,
                        :repository,
                        "#{Domgen::Generator::Appcache::TEMPLATE_DIRECTORY}/manifest_servlet.java.erb",
                        'main/java/#{repository.appcache.qualified_manifest_servlet_name.gsub(".","/")}.java',
                        Domgen::Generator::Appcache::HELPERS)
end

Domgen.template_set(:appcache => [:appcache_manifest_servlet])
