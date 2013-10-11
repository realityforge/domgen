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
      template_set = Domgen::Generator::TemplateSet.new(name, options, &block)
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

      def initialize(name, options = {}, &block)
        @name = name
        @required_template_sets = []
        super(options, &block)
      end

      def templates
        template_map.values
      end

      def template(facets, scope, template_filename, output_filename_pattern, helpers = [], guard = nil, options = {})
        template = Template.new(self, facets, scope, template_filename, output_filename_pattern, helpers, guard, options)
        template_map[template.name] = template
      end

      def xml_template(facets, scope, template_filename, output_filename_pattern, helpers = [], guard = nil, options = {})
        template = XmlTemplate.new(self, facets, scope, template_filename, output_filename_pattern, helpers, guard, options)
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
      attr_reader :template_filename
      attr_reader :output_filename_pattern
      attr_reader :guard
      attr_reader :helpers
      attr_reader :scope
      attr_reader :facets

      def initialize(template_set, facets, scope, template_filename, output_filename_pattern, helpers, guard, options = {})
        Domgen.error("Unexpected facets") unless facets.is_a?(Array) && facets.all? {|a| a.is_a?(Symbol)}
        Domgen.error("Unknown scope for template #{scope}") unless valid_scopes.include?(scope)
        @template_set = template_set
        @facets = facets
        @scope = scope
        @template_filename = template_filename
        @output_filename_pattern = output_filename_pattern
        @helpers = helpers
        @guard = guard
        @name = options[:name] if options[:name]
      end

      def to_s
        name
      end

      def applicable?(faceted_object)
        self.facets.all? {|facet_key| faceted_object.facet_enabled?(facet_key) }
      end

      def render_to_string(context_binding)
        erb_instance.result(context_binding)
      end

      def name
        @name ||= "#{template_set.name}:#{File.basename(template_filename, '.erb')}"
      end

      protected

      def valid_scopes
        [:enumeration, :message, :exception, :method, :service, :struct, :entity, :data_module, :repository]
      end

      def erb_instance
        unless @template
          @template = ERB.new(IO.read(template_filename), nil, '-')
          @template.filename = template_filename
        end
        @template
      end
    end

    class XmlTemplate < Template
      def initialize(template_set, facets, scope, render_class, output_filename_pattern, helpers, guard, options = {})
        super(template_set, facets, scope, render_class.name, output_filename_pattern, helpers + [render_class], guard, options)
      end

      def render_to_string(context_binding)
        context_binding.eval('generate')
      end
    end
  end
end
