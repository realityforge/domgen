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

    # A standard template set that simple methods for creating templates using included template types
    class StandardTemplateSet < TemplateSet
      def erb_template(facets, target, template_filename, output_filename_pattern, helpers = [], options = {})
        Domgen::Generators::ErbTemplate.new(self, facets, target.to_sym, template_filename, output_filename_pattern, helpers, options)
      end

      def ruby_template(facets, target, template_filename, output_filename_pattern, helpers = [], options = {})
        Domgen::Generators::RubyTemplate.new(self, facets, target.to_sym, template_filename, output_filename_pattern, helpers, options)
      end
    end
  end
end
