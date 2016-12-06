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

Domgen::Generator.define([:xml],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Xml::Helper]) do |g|
  g.template_set(:xml_xsd_assets) do |template_set|
    template_set.erb_template(:data_module,
                              'schema.xsd.erb',
                              'main/webapp/WEB-INF/xsd/#{data_module.xml.xsd_name}',
                              :name => 'WEB-INF/schema.xsd')
  end

  g.template_set(:xml_xsd_resources) do |template_set|
    template_set.erb_template(:data_module,
                              'schema.xsd.erb',
                              'main/resources/#{data_module.xml.resource_xsd_name}',
                              :name => 'META-INF/schema.xsd')
  end

  g.template_set(:xml_public_xsd_webapp) do |template_set|
    template_set.erb_template(:data_module,
                              'schema.xsd.erb',
                              'main/webapp/formats/#{data_module.repository.name}/#{data_module.xml.xsd_name}',
                              :name => 'formats/schema.xsd')
  end

  g.template_set(:xml_doc) do |template_set|
    template_set.ruby_template(:repository,
                               'xmldoc.rb',
                               'main/etc/#{repository.name}.doc.xml')
  end
end
