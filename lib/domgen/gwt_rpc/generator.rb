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

Domgen::Generator.define([:gwt_rpc],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper]) do |g|

  g.template_set(:gwt_rpc_client_service) do |template_set|
    template_set.erb_template(:service,
                              'service.java.erb',
                              'main/java/#{service.gwt_rpc.qualified_service_name.gsub(".","/")}.java')
  end

end
