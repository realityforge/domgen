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

Domgen::Generator.define([:restygwt],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper, Domgen::JaxRS::Helper, Domgen::RestGWT::Helper]) do |g|
  g.template_set(:restygwt_client_service) do |template_set|
    template_set.erb_template(:exception,
                              'exception.java.erb',
                              'main/java/#{exception.restygwt.qualified_name.gsub(".","/")}.java')
    template_set.erb_template(:service,
                              'service.java.erb',
                              'main/java/#{service.restygwt.qualified_service_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'services_module.java.erb',
                              'main/java/#{repository.restygwt.qualified_services_module_name.gsub(".","/")}.java')
    template_set.erb_template(:service,
                              'facade_service.java.erb',
                              'main/java/#{service.restygwt.qualified_facade_service_name.gsub(".","/")}.java')
  end

  g.template_set(:restygwt => [:restygwt_client_service])
end
