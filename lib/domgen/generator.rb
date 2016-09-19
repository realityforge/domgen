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
            template.generate(directory, template.target, element, unprocessed_files)
          end
        end if elements
      end
      Logger.info 'Generator completed'
    end

    class GeneratorError < StandardError
      attr_reader :cause

      def initialize(message, cause = nil)
        super(message)
        @cause = cause
      end
    end
  end
end
