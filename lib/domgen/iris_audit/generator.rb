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

Domgen::Generator.define([:iris_audit],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper]) do |g|
  g.template_set(:iris_audit_server) do |template_set|
    template_set.erb_template(:repository,
                              'audit_resources.java.erb',
                              'main/java/#{repository.iris_audit.qualified_audit_resources_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'audit_context_impl.java.erb',
                              'main/java/#{repository.iris_audit.qualified_audit_context_impl_name.gsub(".","/")}.java')
    template_set.erb_template(:service,
                              'interceptor_impl.java.erb',
                              'main/java/#{service.iris_audit.qualified_interceptor_impl_name.gsub(".","/")}.java',
                              :guard => 'service.ejb? && service.ejb.generate_boundary?')
  end
end
