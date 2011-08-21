module Domgen
  module Generator
    class Template
      attr_reader :template_filename
      attr_reader :output_filename_pattern
      attr_reader :guard
      attr_reader :helpers
      attr_reader :scope
      attr_reader :facets
      attr_accessor :generator_key

      def initialize(facets, scope, template_filename, output_filename_pattern, helpers = [], guard = nil)
        Domgen.error("Unexpected facets") unless facets.is_a?(Array) && facets.all? {|a| a.is_a?(Symbol)}
        Domgen.error("Unknown scope for template #{scope}") unless valid_scopes.include?(scope)
        @facets = facets
        @scope = scope
        @template_filename = template_filename
        @output_filename_pattern = output_filename_pattern
        @helpers = helpers
        @guard = guard
      end

      def applicable?(faceted_object)
        self.facets.all? {|facet_key| faceted_object.facet_enabled?(facet_key) }
      end

      def render_to_string(context_binding)
        erb_instance.result(context_binding)
      end

      def template_name
        File.basename(template_filename, '.erb')
      end

      protected

      def valid_scopes
        [:method, :service, :object_type, :data_module, :repository]
      end

      def erb_instance
        unless @template
          @template = ERB.new(IO.read(template_filename), nil, '-')
        end
        @template
      end
    end

    class XmlTemplate < Template
      def initialize(scope, render_class, output_filename_pattern, helpers = [], guard = nil)
        super(scope, render_class.name, output_filename_pattern, helpers + [render_class], guard)
      end

      def render_to_string(context_binding)
        context_binding.eval('generate')
      end
    end
  end
end
