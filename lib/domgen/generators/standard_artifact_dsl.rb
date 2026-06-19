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

    # This module is typically included into the facet extension objects. It
    # simplifies the definition of templates from the facet extension objects.
    #
    # Note: The framework needs to supply a method template_set_container
    #
    # The module assumes that facets are defined using a specific convention.
    # Namely that by convention facets are defined in a file named `.../<myfacet>/model.rb`
    # and templates are defined in a file named `.../<myfacet>/templates/<templatekey>.<output_extension>.<template_extension>`
    # When attempting to derive default values for configuration it will be derived using these conventions.
    #
    module ArtifactDSL

      #
      # Define a java artifact. This is a wrapper around the artifact() method
      # that makes additional assumptions for java based artifacts. This method
      # assumes a maven-style file system layout (i.e. java is stored in main/java or test/java).
      # It also assumes that the facet has the fully qualified name of the artifact in a method
      # named with the convention "qualified_<artifact_key>_name"
      #
      # The options supported include those supplied to the artifact method plus:
      # * :artifact_category - The option must be one of :main or :test and determines which source hierarchy the code is added to.
      #
      def java_artifact(template_set_suffix, artifact_key, options = {})
        options = options.dup
        artifact_category = options.delete(:artifact_category) || :main
        Domgen.error("artifact_category '#{artifact_category}' is not a known type") unless [:main, :test].include?(artifact_category)
        filename_pattern = "#{artifact_category}/java/\#{#{self.target_key}.#{self.facet_key}.qualified_#{artifact_key}_name.gsub(\".\",\"/\")}.java"
        file_artifact(template_set_suffix, artifact_key, filename_pattern, options)
      end

      #
      # Define an artifact and attach it to template_set.
      # This assumes that the the template is named with the convention "<facet_templates_directory>/<artifact_key>.<file_extension>"
      # with the file extension derived from the supplied filename pattern.
      #
      # The template set is prefixed with the name of the facet from which this is extended.
      #
      # The options supported include:
      # * :facets - additional facets that must be enabled for the facet to be generated.
      # * :helpers - additional helpers that are added to the default helpers.
      # * :guard - The :guard option passed to the template.
      #
      def file_artifact(template_set_suffix, artifact_key, filename_pattern, options = {})
        Domgen::Options.check(options, [:output_filter, :facets, :guard, :helpers], Domgen, 'define artifact')

        file_extension = File.extname(filename_pattern)[1...9999]

        params = options.merge(:file_type => file_extension)
        artifact(template_set_suffix, params) do |template_set, facets, helpers, template_options|
          base_template_filename = "#{facet_templates_directory}/#{artifact_key}.#{file_extension}"
          template_extension =
            File.exist?("#{base_template_filename}.erb") ?
              'erb' :
              File.exist?("#{base_template_filename}.rb") ? 'rb' : nil
          template_filename = "#{base_template_filename}.#{template_extension}"
          if 'erb' == template_extension
            template_set.erb_template(facets, self.target_key, template_filename, filename_pattern, helpers, template_options)
          else
            template_set.ruby_template(facets, self.target_key, template_filename, filename_pattern, helpers, template_options)
          end
        end
      end

      #
      # Define an arbitrary artifact and attach it to template_set.
      # This delegates the work of creating the template to the supplied block which is passed the template pattern.
      #
      # The template set is prefixed with the name of the facet from which this is extended if any.
      #
      # The following options are supported. Additional options are passed to helper methods and may be used.
      # * :facets - additional facets that must be enabled for the facet to be generated.
      # * :helpers - additional helpers that are added to the default helpers.
      # * :guard - The :guard option passed to the template.
      #
      def artifact(template_set_suffix, options = {}, &block)
        block.call(template_set_with_suffix(template_set_suffix),
                   template_set_facets(options),
                   template_set_helpers(options),
                   :guard => options[:guard])
      end

      def template_set_facets(options = {})
        (self.default_facets + (options[:facets].nil? ? [] : options[:facets])).compact
      end

      def template_set_helpers(options = {})
        template_set_container.
          derive_default_helpers(options.merge(:artifact_type => self.target_key, :facet_key => self.facet_key)) +
          (options[:helpers].nil? ? [] : options[:helpers])
      end

      def template_set_with_suffix(suffix)
        template_set_key = [self.facet_key, suffix].compact.join('_').to_sym

        template_set_container.template_set_by_name?(template_set_key) ?
          template_set_container.template_set_by_name(template_set_key) :
          template_set_container.template_set(template_set_key)
      end

      def default_facets
        [self.facet_key]
      end

      def facet_templates_directory
        @facet_templates_directory ||= "#{facet_directory}/templates"
      end

      def facet_directory
        @facet_directory ||= nil
        if @facet_directory.nil?
          locations = respond_to?(:caller_locations) ?
            caller_locations.collect { |c| c.absolute_path } :
            caller.collect { |s| s.split(':')[0] }
          locations.each do |location|
            if !self.facet_key.nil? && location =~ /.*\/#{self.facet_key}\/model\.rb$/
              @facet_directory = File.dirname(location)
              break
            end
          end
          Domgen.error("Unable to locate facet_directory for facet '#{self.facet_key}'. Caller trace: #{locations.inspect}") if @facet_directory.nil?
        end
        @facet_directory
      end
    end
  end
end
