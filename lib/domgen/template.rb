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
    def template_sets
      template_set_map.values
    end

    def template_set(name, options = {}, &block)
      if name.is_a?(Hash) && name.size == 1
        req = name.values[0]
        options = options.dup
        options[:required_template_sets] = req.is_a?(Array) ? req : [req]
        name = name.keys[0]
      end
      raise "Attempting to redefine template_set #{name}" if template_set_map[name.to_s]
      template_set = Domgen::Generator::TemplateSet.new(name.to_s, options, &block)
      template_set_map[name.to_s] = template_set
      template_set
    end

    def template_set_by_name(name)
      template_set = template_set_map[name.to_s]
      Domgen.error("Unable to locate template_set #{name}") unless template_set
      template_set
    end

    private

    def template_set_map
      @template_sets ||= Domgen::OrderedHash.new
    end
  end

  module Generator
    class TemplateSet < BaseElement
      attr_reader :name
      attr_accessor :required_template_sets
      attr_accessor :description

      def initialize(name, options = {}, &block)
        @name = name
        @required_template_sets = []
        super(options, &block)
      end

      def templates
        template_map.values
      end

      def template(facets, scope, template_filename, output_filename_pattern, helpers = [], options = {})
        template = ErbTemplate.new(self, facets, scope, template_filename, output_filename_pattern, helpers, options)
        register_template(template)
      end

      def xml_template(facets, scope, template_filename, output_filename_pattern, helpers = [], options = {})
        template = XmlTemplate.new(self, facets, scope, template_filename, output_filename_pattern, helpers, options)
        register_template(template)
      end

      def register_template(template)
        Domgen.error("Template already exists with specified name #{template.name}") if template_map[template.name]
        template_map[template.name] = template
      end

      def template_by_name(name)
        template = template_map[name.to_s]
        Domgen.error("Unable to locate template #{name}") unless template
        template
      end

      private

      def template_map
        @templates ||= Domgen::OrderedHash.new
      end
    end

    class Template < BaseElement
      attr_reader :template_set
      attr_reader :template_key
      attr_reader :guard
      attr_reader :helpers
      attr_reader :scope
      attr_reader :facets
      attr_reader :extra_data

      def initialize(template_set, facets, scope, template_key, helpers, options = {})
        Domgen.error('Unexpected facets') unless facets.is_a?(Array) && facets.all? {|a| a.is_a?(Symbol)}
        Domgen.error("Unknown scope for template #{scope}") unless valid_scopes.include?(scope)
        @template_set = template_set
        @facets = facets
        @scope = scope
        @template_key = template_key
        @helpers = helpers
        @guard = options[:guard]
        @name = options[:name] if options[:name]
        @extra_data = options[:extra_data] || {}
      end

      def to_s
        name
      end

      def applicable?(faceted_object)
        self.facets.all? {|facet_key| faceted_object.facet_enabled?(facet_key) }
      end

      def output_path
        Domgen.error('output_path unimplemented')
      end

      def generate(target_basedir, element_type, element, unprocessed_files)
        Logger.debug "Generating #{self.name} for #{element_type} #{name_for_element(element)}"
        return nil unless guard_allows?(element_type, element)

        generate!(target_basedir, element_type, element, unprocessed_files)
      end

      def guard_allows?(element_type, element)
        return true if self.guard.nil?
        render_context = create_context(element_type, element)
        context_binding = render_context.context_binding
        return eval(self.guard, context_binding, "#{self.template_key}#Guard")
      end

      def name
        @name ||= "#{self.template_set.name}:#{self.template_key.gsub(/.*\/templates\/(.*)\.erb/,'\1')}"
      end

      protected

      def generate!(target_basedir, element_type, element, unprocessed_files)
        Domgen.error('generate not implemented')
      end

      def name_for_element(element)
        element.respond_to?(:qualified_name) ? element.qualified_name : element.name
      end

      def create_context(key, value)
        context = RenderContext.new
        context.set_local_variable(key, value)
        self.extra_data.each_pair do |k, v|
          context.set_local_variable(k, v)
        end
        self.helpers.each do |helper|
          context.add_helper(helper)
        end
        context
      end

      def valid_scopes
        [:enumeration, :message, :exception, :method, :service, :struct, :entity, :dao, :data_module, :repository]
      end
    end

    class SingleFileOutputTemplate < Template
      attr_reader :output_filename_pattern

      def initialize(template_set, facets, scope, template_key, output_filename_pattern, helpers, options = {})
        super(template_set, facets, scope, template_key, helpers, options)
        @output_filename_pattern = output_filename_pattern
      end

      def output_path
        output_filename_pattern
      end

      protected

      def generate!(target_basedir, element_type, element, unprocessed_files)
        object_name = name_for_element(element)
        render_context = create_context(element_type, element)
        context_binding = render_context.context_binding
        begin
          output_filename = eval("\"#{self.output_filename_pattern}\"", context_binding, "#{self.template_key}#Filename")
          output_filename = File.join(target_basedir, output_filename)
          unprocessed_files.delete(output_filename)
          result = self.render_to_string(context_binding)
          FileUtils.mkdir_p File.dirname(output_filename) unless File.directory?(File.dirname(output_filename))
          if File.exist?(output_filename) && IO.read(output_filename) == result
            Logger.debug "Skipped generation of #{self.name} for #{element_type} #{object_name} to #{output_filename} due to no changes"
          else
            File.open(output_filename, 'w') { |f| f.write(result) }
            Logger.debug "Generated #{self.name} for #{element_type} #{object_name} to #{output_filename}"
          end
        rescue => e
          raise GeneratorError.new("Error generating #{self.name} for #{element_type} #{object_name}", e)
        end
      end

      def render_to_string(context_binding)
        Domgen.error('render_to_string not implemented')
      end
    end

    class ErbTemplate < SingleFileOutputTemplate
      def template_filename
        template_key
      end

      protected

      def render_to_string(context_binding)
        self.erb_instance.result(context_binding)
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

    class XmlTemplate < SingleFileOutputTemplate
      def initialize(template_set, facets, scope, render_class, output_filename_pattern, helpers, options = {})
        super(template_set, facets, scope, render_class.name, output_filename_pattern, helpers + [render_class], options)
      end

      def render_to_string(context_binding)
        context_binding.eval('generate')
      end
    end
  end
end
