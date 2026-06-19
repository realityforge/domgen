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

module Domgen #nodoc
  module Generators #nodoc

    # A module where all ruby templates are defined
    module RubyTemplates
    end

    class RubyTemplate < Domgen::Generators::SingleFileOutputTemplate
      def initialize(template_set, facets, target, template_key, output_filename_pattern, helpers, options = {})
        super(template_set, facets, target, template_key, output_filename_pattern, helpers, options)
        @template = nil
      end

      def template_filename
        template_key
      end

      protected

      def template_extension
        'rb'
      end

      def render_to_string(context_binding)
        context_binding.eval("#{ruby_instance.name}.generate(#{target.to_s.gsub(/^.*\./, '')})")
      end

      def ruby_instance
        unless @template
          Domgen.error("Unable to locate file #{template_filename} for template #{name}") unless File.exist?(template_filename)

          template_name = Domgen::Naming.pascal_case(template_filename.gsub(/.*\/([^\/]+)\/templates\/(.+)\.rb$/, '\1_\2').gsub('.', '_').gsub('/', '_'))

          Generators::RubyTemplates.class_eval "module #{template_name}\n end"
          template = Generators::RubyTemplates.const_get(template_name)
          template.class_eval <<-CODE
            class << self
              #{IO.read(template_filename)}
            end
          CODE

          @template = template
        end
        @template
      end
    end
  end
end
