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

    # A hook to control whether certain paths in model should
    # be follow when collecting generation targets
    def handle_subelement?(object, sub_feature_key)
      Domgen::FacetManager.handle_sub_feature?(object, sub_feature_key)
    end

    protected

    def new_template_set(name, options, &block)
      Domgen::Generator::TemplateSet.new(self, name.to_s, options, &block)
    end
  end

  Reality::Facets.copy_targets_to_generator_target_manager(Domgen, Domgen::FacetManager)

  module Generator
    class << self
      def current_facets
        facets_stack.last
      end

      def current_facets?
        !facets_stack.empty?
      end

      def current_template_directory
        template_directory_stack.last
      end

      def current_template_directory?
        !template_directory_stack.empty?
      end

      def current_helpers
        helpers_stack.last
      end

      def current_helpers?
        !helpers_stack.empty?
      end

      def facets_stack
        @facets_stack ||= []
      end

      def template_directory_stack
        @template_directory_stack ||= []
      end

      def helpers_stack
        @helpers_stack ||= []
      end

      def define(facets, template_directory, helpers)
        facets_stack.push(facets)
        template_directory_stack.push(template_directory)
        helpers_stack.push(helpers)
        begin
          yield Domgen if block_given?
        ensure
          facets_stack.pop
          helpers_stack.pop
          template_directory_stack.pop
        end
      end
    end

    class TemplateSet < Reality::Generators::TemplateSet
      def erb_template(target, template_filename, output_filename_pattern, options = {})
        options = options.dup
        facets = get_facets(options)
        helpers = get_helpers(options)
        template_filename = get_template_filename(template_filename)
        options[:output_filter] = Proc.new do |content|
          unless content.include?("DO NOT EDIT: File is auto-generated")
            Domgen.error("Generator for template #{template_filename} failed to generate content containing text 'DO NOT EDIT: File is auto-generated'")
          end
          content
        end
        Reality::Generators::ErbTemplate.new(self, facets, target.to_sym, template_filename, output_filename_pattern, helpers, options)
      end

      def ruby_template(target, template_filename, output_filename_pattern, options = {})
        options = options.dup
        facets = get_facets(options)
        helpers = get_helpers(options)
        template_filename = get_template_filename(template_filename)

        Reality::Generators::RubyTemplate.new(self, facets, target.to_sym, template_filename, output_filename_pattern, helpers, options)
      end

      private

      def get_template_filename(template_filename)
        Domgen::Generator.current_template_directory? ?
          "#{Domgen::Generator.current_template_directory}/#{template_filename}" :
          template_filename
      end

      def get_helpers(options)
        helpers = options.delete(:helpers)
        if helpers.nil? && Domgen::Generator.current_helpers?
          additional_helpers = options.delete(:additional_helpers) || []
          helpers = Domgen::Generator.current_helpers + additional_helpers
        end
        raise 'No helpers configured' if helpers.nil?
        helpers
      end

      def get_facets(options)
        facets = options.delete(:facets)
        if facets.nil? && Domgen::Generator.current_facets?
          additional_facets = options.delete(:additional_facets) || []
          facets = Domgen::Generator.current_facets + additional_facets
        end
        raise 'No facets configured' if facets.nil?
        facets
      end
    end
  end
end
