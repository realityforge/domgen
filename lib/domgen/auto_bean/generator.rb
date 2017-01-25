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

Domgen::Generator.define([:auto_bean],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper]) do |g|
  g.template_set(:auto_bean_struct) do |template_set|
    template_set.erb_template(:struct,
                              'struct.java.erb',
                              'main/java/#{struct.auto_bean.qualified_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'factory.java.erb',
                              'main/java/#{repository.auto_bean.qualified_factory_name.gsub(".","/")}.java')
  end

  g.template_set(:auto_bean => [:auto_bean_struct])
end
