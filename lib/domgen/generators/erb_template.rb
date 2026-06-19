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

    class ErbTemplate < Domgen::Generators::SingleFileOutputTemplate
      def initialize(template_set, facets, target, template_key, output_filename_pattern, helpers, options = {})
        super(template_set, facets, target, template_key, output_filename_pattern, helpers, options)
        @template = nil
      end

      def template_filename
        template_key
      end

      protected

      def render_to_string(context_binding)
        self.erb_instance.result(context_binding)
      end

      def template_extension
        'erb'
      end

      def erb_instance
        unless @template
          Domgen.error("Unable to locate file #{template_filename} for template #{name}") unless File.exist?(template_filename)
          @template = ERB.new(IO.read(template_filename), nil, '-')
          @template.filename = template_filename
        end
        @template
      end
    end
  end
end
