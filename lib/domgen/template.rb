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
  class << self
    include Reality::Generators::TemplateSetContainer

    protected

    def new_template_set(name, options, &block)
      Domgen::Generator::TemplateSet.new(self, name.to_s, options, &block)
    end
  end

  Domgen.target_manager.target(:repository)
  Domgen.target_manager.target(:data_module, :repository)
  Domgen.target_manager.target(:dao, :data_module)
  Domgen.target_manager.target(:entity, :data_module)
  Domgen.target_manager.target(:struct, :data_module)
  Domgen.target_manager.target(:service, :data_module)
  Domgen.target_manager.target(:method, :service)
  Domgen.target_manager.target(:exception, :data_module)
  Domgen.target_manager.target(:message, :data_module)
  Domgen.target_manager.target(:enumeration, :data_module)

  module Generator
    def self.generate(repository, directory, templates, filter, unprocessed_files)

      Logger.debug "Templates to process: #{templates.collect { |t| t.name }.inspect}"

      targets = {}
      repository.collect_generation_targets(targets)

      templates.each do |template|
        Logger.debug "Evaluating template: #{template.name}"
        elements = targets[template.target]

        elements.each do |element_pair|
          element = element_pair[1]
          if template.applicable?(element_pair[0]) && (filter.nil? || filter.call(template.target, element))
            template.generate(directory, element, unprocessed_files)
          end
        end if elements
      end
      Logger.info 'Generator completed'
    end

    class TemplateSet < Reality::Generators::TemplateSet
      def erb_template(facets, target, template_filename, output_filename_pattern, helpers = [], options = {})
        Reality::Generators::ErbTemplate.new(self, facets, target.to_sym, template_filename, output_filename_pattern, helpers, options)
      end

      def ruby_template(facets, target, template_filename, output_filename_pattern, helpers = [], options = {})
        Reality::Generators::RubyTemplate.new(self, facets, target.to_sym, template_filename, output_filename_pattern, helpers, options)
      end

      def xml_template(facets, target, template_class, output_filename_pattern, helpers = [], options = {})
        XmlTemplate.new(self, facets, target.to_sym, template_class, output_filename_pattern, helpers, options)
      end
    end

    class XmlTemplate < Reality::Generators::SingleFileOutputTemplate
      def initialize(template_set, facets, target, render_class, output_filename_pattern, helpers, options = {})
        super(template_set, facets, target, render_class.name, output_filename_pattern, helpers + [render_class], options)
      end

      def render_to_string(context_binding)
        context_binding.eval('generate')
      end
    end
  end
end
