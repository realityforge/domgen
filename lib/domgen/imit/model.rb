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
  module Imit
    class DefaultValues < Domgen.ParentedElement(:entity)
      def initialize(entity, defaults, options = {}, &block)
        raise "Attempted to define test_default on abstract entity #{entity.qualified_name}" if entity.abstract?
        raise "Attempted to define test_default on #{entity.qualified_name} with no values" if defaults.empty?
        defaults.keys.each do |key|
          raise "Attempted to define test_default on #{entity.qualified_name} with key '#{key}' that is not an attribute value" unless entity.attribute_by_name?(key)
          a = entity.attribute_by_name(key)
          raise "Attempted to define test_default on #{entity.qualified_name} for attribute '#{key}' when attribute has no imit facet defined. Defaults = #{defaults.inspect}" unless a.imit?
        end
        values = {}
        defaults.each_pair do |k, v|
          values[k.to_s] = v
        end
        @values = values

        super(entity, options, &block)
      end

      def has_attribute?(name)
        @values.keys.include?(name.to_s)
      end

      def value_for(name)
        @values[name.to_s]
      end

      def values
        @values.dup
      end
    end

    class ReplicationGraph < Domgen.ParentedElement(:application)
      def initialize(application, code, name, options, &block)
        @name = name
        @code = code
        @type_roots = []
        @required_type_graphs = []
        @dependent_type_graphs = []
        @instance_root = nil
        @outward_graph_links = {}
        @inward_graph_links = {}
        @routing_keys = {}
        @visibility = :universal
        application.send :register_graph, name, self
        super(application, options, &block)
      end

      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :react4j_subscription_component, :component, :client, :imit, '#{name}GraphSubscription'
      java_artifact :react4j_simple_subscription_component, :component, :client, :imit, '#{name}SimpleGraphSubscription'
      java_artifact :subscription_util, :comm, :client, :imit, '#{name}SubscriptionUtil'

      Domgen.target_manager.target(:graph, :repository, :facet_key => :imit, :access_method => :graphs)

      attr_reader :application

      attr_reader :name

      def qualified_name
        "#{application.repository.qualified_name}.Graphs.#{name}"
      end

      attr_reader :code

      attr_writer :generate_react4j_subscription_component

      def generate_react4j_subscription_component?
        external_visibility? && (@generate_react4j_subscription_component.nil? ? false : !!@generate_react4j_subscription_component)
      end

      attr_writer :generate_react4j_simple_subscription_component

      def generate_react4j_simple_subscription_component?
        external_visibility? && (@generate_react4j_simple_subscription_component.nil? ? true : !!@generate_react4j_simple_subscription_component)
      end

      def to_s
        "ReplicationGraph[#{qualified_name}]"
      end

      def cacheable?
        !!@cacheable
      end

      attr_writer :cacheable

      def secure?
        @secure.nil? ? true : !!@secure
      end

      attr_writer :secure

      def bulk_load?
        @bulk_load.nil? ? true : !!@bulk_load
      end

      attr_writer :bulk_load

      def visibility=(visibility)
        valid_values = [:external, :internal, :universal]
        Domgen.error("Invalid visibility set on #{qualified_name}. Value: #{visibility}. Valid_values: #{valid_values}") unless valid_values.include?(visibility)
        @visibility = visibility
      end

      def visibility
        @visibility
      end

      def external_visibility?
        self.visibility == :external || self.universal_visibility?
      end

      def internal_visibility?
        self.visibility == :internal || self.universal_visibility?
      end

      # Default visibility is both internal and externally visible
      # So a user can both subscribe to graph explicitly and a graph can graph_link to this graph
      def universal_visibility?
        self.visibility == :universal
      end

      def external_data_load?
        @external_data_load.nil? ? false : !!@external_data_load
      end

      def external_data_load=(external_data_load)
        @external_data_load = external_data_load
      end

      def instance_root?
        !@instance_root.nil?
      end

      def type_graph?
        !instance_root?
      end

      def type_roots
        Domgen.error("type_roots invoked for graph #{name} when instance based") if instance_root?
        @type_roots
      end

      def type_graph_transitively_include_entity?(qualified_entity_name)
        self.required_type_graphs.any? { |g| g.type_roots.include?(qualified_entity_name) || g.type_graph_transitively_include_entity?(qualified_entity_name) }
      end

      def type_roots=(type_roots)
        Domgen.error("Attempted to assign type_roots #{type_roots.inspect} for graph #{name} when instance based on #{@instance_root.inspect}") if instance_root?
        @type_roots = type_roots
      end

      def instance_root
        Domgen.error("instance_root invoked for graph #{name} when not instance based") if 0 != @type_roots.size
        @instance_root
      end

      def instance_root=(instance_root)
        Domgen.error("Attempted to assign instance_root to #{instance_root.inspect} for graph #{name} when not instance based (type_roots=#{@type_roots.inspect})") if 0 != @type_roots.size
        @instance_root = instance_root
      end

      def outward_graph_links
        @outward_graph_links.values
      end

      # GraphLinks from this graph to graphs that have filters and are auto linked.
      # It is assumed that if this graph links to another graph multiple times,
      # then all these links will have the same filter
      def filtered_outward_auto_graph_links
        processed = []
        result = []
        self.outward_graph_links.select{|graph_link| graph_link.auto?}.each do |graph_link|
           target_graph = self.application.graph_by_name(graph_link.target_graph)
           next unless target_graph.filtered?
           key = "#{graph_link.source_graph}=>#{graph_link.target_graph}"
           next if processed.include?(key)
           processed << key
           result << graph_link
        end
        result
      end


      def inward_graph_links
        Domgen.error("inward_graph_links invoked for graph #{name} when not instance based") if 0 != @type_roots.size
        @inward_graph_links.values
      end

      def routing_keys
        Domgen.error("routing_keys invoked for graph #{name} when not filtered") if unfiltered?
        @routing_keys.values
      end

      # Return the list of entities reachable in instance graph
      def reachable_entities
        Domgen.error("reachable_entities invoked for graph #{name} when not instance based") if 0 != @type_roots.size
        @reachable_entities ||= []
      end

      def leaf_list
        Domgen.error("leaf_list invoked for graph #{name} when not instance based") if 0 != @type_roots.size
        @leaf_list ||= []
      end

      def included_entities
        instance_root? ? reachable_entities : type_roots
      end

      def filter(filter_type, options = {}, &block)
        Domgen.error("Attempting to redefine filter on graph #{self.name}") if @filter
        @filter ||= FilterParameter.new(self, filter_type, options, &block)
      end

      def filter_parameter?
        !@filter.nil?
      end

      def filter_parameter
        @filter
      end

      def filtered?
        (@filtered.nil? ? false : !!@filtered) || filter_parameter?
      end

      attr_writer :filtered

      def dynamic_filter?
        filtered? && (filter_parameter? ? !filter_parameter.immutable? : (@dynamic_filter.nil? ? false : !!@dynamic_filter))
      end

      # This can be set to true for an INTERNAL filter that can not be dynamically interpreted and must be
      # filtered on the client as well after an update
      attr_writer :dynamic_filter

      def unfiltered?
        !filtered?
      end

      def dependent_type_graphs
        @dependent_type_graphs.dup
      end

      def required_type_graphs
        @required_type_graphs.dup
      end

      def require_type_graphs=(require_type_graphs)
        require_type_graphs.each do |graph_key|
          require_type_graph(graph_key)
        end
      end

      def require_type_graph(graph_key)
        graph = application.repository.imit.graph_by_name(graph_key)
        Domgen.error("Graph '#{self.name}' requires type graph #{graph_key} but required graph is not a type graph.") if graph.instance_root?
        Domgen.error("Graph '#{self.name}' requires self which is invalid.") if self.name.to_s == graph_key.to_s
        Domgen.error("Graph '#{self.name}' requires type graph #{graph_key} multiple times.") if @required_type_graphs.include?(graph)
        @required_type_graphs << graph
        graph.send(:add_dependent_type_graph, self)
      end

      def post_verify
        if cacheable? && (filter_parameter || instance_root?)
          Domgen.error("Graph #{self.name} can not be marked as cacheable as cacheable graphs are not supported for instance based or filterable graphs")
        end
        if cacheable? && bulk_load?
          Domgen.error("Graph #{self.name} is marked as bulk load and cacheable but replicant library has not implemented scenario")
        end
        if self.instance_root?
          instance_root = self.application.repository.entity_by_name(self.instance_root)
          unless instance_root.primary_key.integer?
            Domgen.error("Graph #{self.name} has an instance root #{self.instance_root} that has a primary key that is not an integer")
          end
        end

        if self.internal_visibility? && self.instance_root? && self.inward_graph_links.empty?
          Domgen.error("Graph '#{self.name}' is marked with internal visibility but has no inward graph links.")
        end

        if self.internal_visibility? && !self.instance_root? && self.dependent_type_graphs.empty?
          Domgen.error("Graph '#{self.name}' is a type graph marked with internal visibility but has no dependent type graphs.")
        end

        if cacheable?
          self.required_type_graphs.each do |other|
            unless other.cacheable?
              # This scenario is not supported as if the client has cached the type-graph then we will send a "use-cache"
              # message for the graph. This will be queued immediately. But if we have a non-cacheable required type
              # graph then it will be gathered and queued on ReplicantSession._pendingSubscriptionPackets ... but this
              # will be sent to the client after the use-graph message which will mean that the required type graph is
              # not present when use-cache arrives which will cause errors. The fix is to queue 'use-graph' onto same
              # queue but this requires some changes to the underlying library.
              Domgen.error("Graph '#{self.name}' is a cacheable graph but is dependent on a non-cacheable type graph '#{other.name}'.")
            end
          end
        end

        entities = self.included_entities

        if entities.empty?
          Domgen.error("Graph '#{self.name}' contains no entities to replicate.")
        end

        entities.each do |entity_name|
          entity = application.repository.entity_by_name(entity_name)
          entity.attributes.select { |a| a.reference? && a.imit? }.each do |a|
            referenced_entity = a.referenced_entity

            agls = a.imit.auto_graph_links

            next if agls.any? { |graph_link| graph_link.source_graph.to_s == self.name.to_s }

            # Unclear on how to handle this next scenario. Assume a subtype is visible?
            next if referenced_entity.abstract?

            # If linked entity is part of current graph then all is ok.
            next if entities.any? { |e| e == referenced_entity.qualified_name }

            # If entity is part of required type graphs then all is ok
            next if self.type_graph_transitively_include_entity?(referenced_entity.qualified_name)

            next if self.instance_root? &&
              !self.inward_graph_links.empty? &&
              self.inward_graph_links.all? do |graph_link|
                application.repository.imit.graph_by_name(graph_link.source_graph).included_entities.any? { |e| e == referenced_entity.qualified_name }
              end

            next if a.imit.skip_link_checks.include?(self.name)

            Domgen.error("Graph '#{self.name}' has a link from '#{a.qualified_name}' to entity '#{referenced_entity.qualified_name}' that is not a instance level graph-link and is not transitively part of any of the dependent type graphs. Immediate graph dependencies include: #{self.required_type_graphs.collect { |e| e.name }.inspect} and not in current graph [#{entities.join(', ')}].")
          end
        end
      end

      protected

      def add_dependent_type_graph(graph)
        @dependent_type_graphs << graph
      end

      def register_routing_key(routing_key)
        key = routing_key.name.to_s
        Domgen.error("Attempted to register duplicate routing key link on attribute '#{routing_key.imit_attribute.attribute.qualified_name}' on graph '#{self.name}'") if @routing_keys[key]
        @routing_keys[key] = routing_key
      end

      def register_outward_graph_link(graph_link)
        to_graph = graph_link.target_graph
        key = "#{to_graph}-#{graph_link.imit_attribute.attribute.qualified_name.to_s}"
        Domgen.error("Attempted to register duplicate outward graph link on attribute '#{graph_link.imit_attribute.attribute.qualified_name}' on graph '#{self.name}'") if @outward_graph_links[key]
        @outward_graph_links[key] = graph_link
      end

      def register_inward_graph_link(graph_link)
        from_graph = graph_link.source_graph
        key = "#{from_graph}-#{graph_link.imit_attribute.attribute.qualified_name.to_s}"
        Domgen.error("Attempted to register duplicate inward graph link on attribute '#{graph_link.imit_attribute.attribute.qualified_name}' on graph '#{self.name}' from graph '#{from_graph}'") if @inward_graph_links[key]
        @inward_graph_links[key] = graph_link
      end
    end

    class GraphLink < Domgen.ParentedElement(:imit_attribute)
      def initialize(imit_attribute, name, source_graph, target_graph, options, &block)
        repository = imit_attribute.attribute.entity.data_module.repository
        unless repository.imit.graph_by_name?(source_graph)
          Domgen.error("Source graph '#{source_graph}' specified for link on #{imit_attribute.attribute.name} does not exist")
        end
        unless repository.imit.graph_by_name?(target_graph)
          Domgen.error("Target graph '#{target_graph}' specified for link on #{imit_attribute.attribute.name} does not exist")
        end
        unless imit_attribute.attribute.reference? || imit_attribute.attribute.primary_key?
          Domgen.error("Attempted to define a graph link on non-reference, non-primary key attribute '#{imit_attribute.attribute.qualified_name}'")
        end
        @name = name
        @source_graph = source_graph
        @target_graph = target_graph
        @auto = true
        @exclude_target = nil
        super(imit_attribute, options, &block)
        repository.imit.graph_by_name(source_graph).send(:register_outward_graph_link, self)
        repository.imit.graph_by_name(target_graph).send(:register_inward_graph_link, self)
        configred_exclude_target = options[:exclude_target] || options['exclude_target']
        if configred_exclude_target && !imit_attribute.attribute.entity.data_module.repository.imit.graph_by_name(target_graph).instance_root?
          Domgen.error("Graph link from '#{self.source_graph}' to '#{self.target_graph}' via '#{self.imit_attribute.attribute.qualified_name}' marked as exclude_target=true but the target graph is a type graph.")
        end
        configured_auto = options[:auto] || options['auto']
        if configured_auto
          Domgen.error("GraphLink on #{imit_attribute.attribute.qualified_name} from #{source_graph} to #{target_graph} specified auto=true property but this is now the default")
        end
        if repository.imit.graph_by_name(target_graph).instance_root? && self.exclude_target? && !self.imit_attribute.attribute.primary_key?
          if self.imit_attribute.attribute.inverse.imit.exclude_edges.include?(target_graph)
            Domgen.error("#{imit_attribute.attribute.qualified_name} explicitly excludes graph #{target_graph} but also has a graph link named #{name} that references target that implicitly adds exclude. Remove explicit exclude as it is not needed.")
          else
            self.imit_attribute.attribute.inverse.imit.implicit_exclude_edges << target_graph
          end
        end
      end

      attr_reader :name
      attr_reader :source_graph
      attr_reader :target_graph

      attr_accessor :path

      attr_writer :auto

      def auto?
        !!@auto
      end

      # Set this to true if this link may link to a different instance of a graph already linked to
      # the current graph. Current Event/1 instance graph link may graph_link to Event/2. Another example is
      # Event/1 is linked to from OrgUnit/1 and wants to graph_link to OrgUnit/2. Setting this parameter forces
      # collection of routing data and allows a later stage to filter already present links
      attr_writer :always_follow

      def always_follow?
        @always_follow.nil? ? false : !!@always_follow
      end

      attr_writer :exclude_target

      # Should we exclude the target entity from source graph? Typically done for automatically
      # traversing graphs but sometimes you may wish to override this.
      def exclude_target?
        Domgen.error("Invoked exclude_target? on #{self} which is not an instance graph") unless self.imit_attribute.attribute.entity.data_module.repository.imit.graph_by_name(target_graph).instance_root?
        @exclude_target.nil? ? self.auto? : !!@exclude_target
      end

      def to_s
        "GraphLink[#{source_graph} => #{target_graph}](auto=#{auto?}, exclude_target=#{@exclude_target.nil? ? self.auto? : !!@exclude_target}, path=#{path.inspect}, name=#{name})"
      end

      def post_verify
        entity = self.imit_attribute.attribute.primary_key? ? self.imit_attribute.attribute.entity : self.imit_attribute.attribute.referenced_entity

        # Need to make sure that the path is valid
        if self.path
          prefix = "Graph link from '#{self.source_graph}' to '#{self.target_graph}' via '#{self.imit_attribute.attribute.name}' with path element"
          self.path.to_s.split.each_with_index do |attribute_name_path_element, i|
            other = entity.attribute_by_name(attribute_name_path_element)
            Domgen.error("#{prefix} #{attribute_name_path_element} is nullable") if other.nullable? && i != 0
            Domgen.error("#{prefix} #{attribute_name_path_element} is not immutable") unless other.immutable?
            Domgen.error("#{prefix} #{attribute_name_path_element} is not a reference") unless other.reference?
            entity = other.referenced_entity
          end
          Domgen.error("GraphLink from '#{self.source_graph}' to '#{self.target_graph}' via '#{self.imit_attribute.attribute.name}' with path element does not identify the root of the target graph") if entity.qualified_name != entity.data_module.repository.imit.graph_by_name(self.target_graph).instance_root
        end

        repository = imit_attribute.attribute.entity.data_module.repository
        source_graph = repository.imit.graph_by_name(self.source_graph)
        target_graph = repository.imit.graph_by_name(self.target_graph)

        # Need to make sure both graphs are instance graphs
        prefix = "Graph link from '#{self.source_graph}' to '#{self.target_graph}' via '#{self.imit_attribute.attribute.name}'"
        Domgen.error("#{prefix} must have an instance graph on the LHS if target graph has filter as we assume filter is propagated") unless source_graph.instance_root? || target_graph.unfiltered?
        Domgen.error("#{prefix} must have an instance graph on the RHS") unless target_graph.instance_root?

        # Need to make sure that the other side is the root of the graph
        unless target_graph.instance_root != entity.name
          Domgen.error("Graph link from '#{self.source_graph}' to '#{self.target_graph}' via '#{self.imit_attribute.attribute.qualified_name}' links to entity that is not the root of the graph")
        end

        elements = (source_graph.instance_root? ? source_graph.reachable_entities.sort : source_graph.type_roots)
        unless elements.include?(self.imit_attribute.attribute.entity.qualified_name)
          Domgen.error("Graph link from '#{self.source_graph}' to '#{self.target_graph}' via '#{self.imit_attribute.attribute.qualified_name}' attempts to link to a graph when the source entity is not part of the source graph - #{elements.inspect}")
        end

        elements = (target_graph.instance_root? ? target_graph.reachable_entities.sort : target_graph.type_roots)
        unless elements.include?(entity.qualified_name)
          Domgen.error("Graph link from '#{self.source_graph}' to '#{self.target_graph}' via '#{self.imit_attribute.attribute.qualified_name}' attempts to link to a graph when the target entity is not part of the target graph - #{elements.inspect}")
        end
      end
    end

    class RoutingKey < Domgen.ParentedElement(:imit_attribute)
      def initialize(imit_attribute, name, graph, options, &block)
        repository = imit_attribute.attribute.entity.data_module.repository
        unless repository.imit.graph_by_name?(graph)
          Domgen.error("Graph '#{graph}' specified for routing key #{name} on #{imit_attribute.attribute.name} does not exist")
        end
        @name = name
        @graph = repository.imit.graph_by_name(graph)
        super(imit_attribute, options, &block)
        repository.imit.graph_by_name(graph).send :register_routing_key, self
      end

      # A unique name for routing key within the graph
      attr_reader :name

      # The graph that routing key is used by
      attr_reader :graph

      # The path is the chain of references along which routing key walks
      # Each link in chain must be a reference. Must be empty if initial
      # attribute is not a reference. A null in the path means nokey is
      # selected
      def path
        @path || []
      end

      def path=(path)
        Domgen.error("Path parameter '#{path.inspect}' specified for routing key #{name} on #{imit_attribute.attribute.name} is not an array") unless path.is_a?(Array)
        path.each do |path_key|
          self.multivalued = true if is_inverse_path_element?(path_key) || is_path_element_recursive?(path_key)
        end
        @path = path
      end

      def is_path_element_recursive?(path_element)
        path_element.to_s =~ /^\*.*/
      end

      def is_inverse_path_element?(path_element)
        path_element.to_s =~ /^<.*/
      end

      def get_attribute_name_from_path_element?(path_element)
        is_inverse_path_element?(path_element) || is_path_element_recursive?(path_element) ? path_element[1, path_element.length] : path_element
      end

      # The name of the attribute that is used in referenced entity. This
      # will raise an exception if the initial attribute is not a reference, otherwise
      # it must match a name in the target entity
      def attribute_name
        Domgen.error("attribute_name invoked for routing key #{name} on #{imit_attribute.attribute.name} when attribute is not a reference or inverse reference") unless reference? || inverse_start?
        return @attribute_name unless @attribute_name.nil?
        referenced_entity.primary_key.name
      end

      def attribute_name=(attribute_name)
        @attribute_name = attribute_name
      end

      def attribute_name?
        !@attribute_name.nil?
      end

      def reference?
        self.path.size > 0 || self.imit_attribute.attribute.reference?
      end

      def referenced_attribute
        reference? || inverse_start? ? self.referenced_entity.attribute_by_name(self.attribute_name) : imit_attribute.attribute
      end

      def referenced_entity
        Domgen.error("referenced_entity invoked on routing key #{name} on #{imit_attribute.attribute.name} when attribute is not a reference or inverse reference") unless reference? || inverse_start?
        a = imit_attribute.attribute
        e = self.imit_attribute.attribute.reference? ? self.imit_attribute.attribute.referenced_entity : a.entity
        path.each do |path_element|
          attr_name = get_attribute_name_from_path_element?(path_element)
          if is_inverse_path_element?(path_element)
            a = e.arez.referencing_client_side_attributes.select { |attr| attr.inverse.name.to_s == attr_name.to_s }[0]
            e = a.entity
          else
            a = e.attribute_by_name(attr_name)
            e = a.referenced_entity
          end
        end
        e
      end

      def inverse_start?
        self.imit_attribute.attribute.primary_key? && self.path.size > 0
      end

      def target_attribute
        ((!self.inverse_start? && self.reference?) || self.attribute_name?) ? self.referenced_entity.attribute_by_name(self.attribute_name) : self.imit_attribute.attribute
      end

      attr_writer :multivalued

      def multivalued?
        @multivalued.nil? ? false : !!@multivalued
      end

      def target_nullsafe?
        return true unless self.reference?
        return false if self.inverse_start?
        return self.imit_attribute.attribute.reference? if self.path.size == 0

        a = imit_attribute.attribute
        self.path.each do |path_element|
          return false if is_path_element_recursive?(path_element)
          return false if is_inverse_path_element?(path_element)
          a = a.referenced_entity.attribute_by_name(get_attribute_name_from_path_element?(path_element))
          return false if a.nullable?
        end
        return !a.nullable?
      end

      def post_verify
        # The next check could be removed if we were willing to update the client-side session context to walk down and unlink
        # child entities when an intermediate entity is delinked. In which case the graph would not need to worry about leaf nodes
        # at all anymore
        Domgen.error("Routing key '#{self.name}' on #{self.imit_attribute.attribute.name} is not immutable and is not on a leaf entity within a instance graph") unless self.graph.type_graph? || self.imit_attribute.attribute.immutable? || self.graph.leaf_list.include?(self.imit_attribute.attribute.entity.qualified_name.to_s)
        Domgen.error("Routing key #{self.name} on #{self.imit_attribute.attribute.qualified_name} specifies graph '#{self.graph.name}' that is not filtered.") unless self.graph.filtered?
        Domgen.error("Routing key #{self.name} on #{self.imit_attribute.attribute.qualified_name} specifies graph '#{self.graph.name}' that entity is not currently part of.") unless self.graph.included_entities.include?(self.imit_attribute.attribute.entity.qualified_name)

        if attribute_name?
          Domgen.error("Routing key #{self.name} on #{self.imit_attribute.attribute.qualified_name} specifies attribute_name '#{attribute_name}' when attribute is not a reference or inverse reference") unless reference? || inverse_start?

          Domgen.error("Routing key #{self.name} on #{self.imit_attribute.attribute.qualified_name} specifies attribute_name '#{attribute_name}' when the attribute is not immutable") if !self.referenced_attribute.immutable? && !self.referenced_attribute.set_once?
        end

        if self.path.size > 0
          a = self.imit_attribute.attribute
          e = self.imit_attribute.attribute.reference? ? self.imit_attribute.attribute.referenced_entity : a.entity
          path.each do |path_key|
            is_inverse = is_inverse_path_element?(path_key)
            path_element = get_attribute_name_from_path_element?(path_key)

            if is_inverse
              candidates = e.arez.referencing_client_side_attributes.select { |attr| attr.inverse.name.to_s == path_element.to_s }
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{imit_attribute.attribute.name} does not reference a client side attribute") if candidates.empty?
              a = candidates[0]
              e = a.entity
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{imit_attribute.attribute.name} inverse reference is not immutable #{a.qualified_name}") unless a.immutable?
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{imit_attribute.attribute.name} inverse reference is not multiplicity :many. This has not been implemented yet") unless a.inverse.multiplicity == :many
            else
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{imit_attribute.attribute.name} does not refer to a valid attribute of #{e.qualified_name}") unless e.attribute_by_name?(path_element)
              a = e.attribute_by_name(path_element)
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{imit_attribute.attribute.name} references an attribute that is not a reference #{a.qualified_name}") unless a.reference?
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{imit_attribute.attribute.name} references an attribute that is not immutable #{a.qualified_name}") unless a.immutable?
              e = a.referenced_entity
            end
          end
        end
      end
    end

    class FilterParameter < Domgen.ParentedElement(:graph)
      attr_reader :filter_type

      include Characteristic

      def initialize(graph, filter_type, options, &block)
        @filter_type = filter_type
        super(graph, options, &block)
      end

      def name
        'FilterParameter'
      end

      def qualified_name
        "#{graph.qualified_name}$#{name}"
      end

      def immutable?
        @immutable.nil? ? false : @immutable
      end

      def immutable=(immutable)
        @immutable = immutable
      end

      def equiv?(other_filter_parameter)
        return false if other_filter_parameter.filter_type != self.filter_type
        return false if other_filter_parameter.collection_type != self.collection_type
        return false if other_filter_parameter.struct? && other_filter_parameter.referenced_struct.name != self.referenced_struct.name
        return false if other_filter_parameter.reference? && other_filter_parameter.referenced_entity.name != self.referenced_entity.name
        return true
      end

      def to_s
        "FilterParameter[#{self.qualified_name}]"
      end

      def characteristic_type_key
        filter_type
      end

      def characteristic_container
        graph
      end

      def struct_by_name(name)
        self.graph.application.repository.struct_by_name(name)
      end

      def entity_by_name(name)
        self.graph.application.repository.entity_by_name(name)
      end
    end
  end

  FacetManager.facet(:imit => [:ce, :arez, :gwt_rpc]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      attr_writer :schema_id

      def schema_id
        @schema_id || 1
      end

      def secured?
        @secured.nil? ? repository.keycloak? : !!@secured
      end

      attr_writer :secured

      def generate_standard_endpoint?
        @generate_standard_endpoint.nil? ? true : !!@generate_standard_endpoint
      end

      attr_writer :generate_standard_endpoint

      def keycloak_client
        repository.keycloak.client_by_key(repository.gwt_rpc.keycloak_client)
      end

      attr_writer :client_component_package

      def client_component_package
        @client_component_package || "#{client_package}.components"
      end

      def client_ioc_package
        repository.gwt.client_ioc_package
      end

      attr_writer :server_comm_package

      def server_comm_package
        @server_comm_package || "#{server_package}.net"
      end

      attr_writer :client_comm_package

      def client_comm_package
        @client_comm_package || "#{client_package}.net"
      end

      def shared_comm_package
        @shared_comm_package || "#{shared_package}.net"
      end

      attr_writer :shared_comm_package

      def modules_package
        repository.gwt.modules_package
      end

      attr_writer :server_web_package

      def server_web_package
        @server_web_package || "#{server_package}.web"
      end

      java_artifact :endpoint, :web, :server, :imit, '#{repository.name}ReplicantEndpoint'
      java_artifact :abstract_endpoint, :web, :server, :imit, 'Abstract#{repository.name}ReplicantEndpoint'
      java_artifact :gwt_client_session_context, :comm, :client, :imit, '#{repository.name}GwtSessionContext'
      java_artifact :gwt_client_session_context_impl, :comm, :client, :imit, '#{gwt_client_session_context_name}Impl'
      java_artifact :client_router, :comm, :client, :imit, '#{repository.name}ClientRouter'
      java_artifact :system_constants, :comm, :shared, :imit, '#{repository.name}SchemaConstants'
      java_artifact :subscription_constants, :comm, :shared, :imit, '#{repository.name}SubscriptionConstants'
      java_artifact :entity_type_constants, :comm, :shared, :imit, '#{repository.name}EntityTypeConstants'
      java_artifact :schema_sting_fragment, :comm, :client, :imit, '#{repository.name}SystemSchemaFragment'
      java_artifact :schema_filter_tools, :comm, :client, :imit, '#{repository.name}FilterTools'
      java_artifact :system_metadata, :comm, :server, :imit, '#{repository.name}MetaData'
      java_artifact :session_manager, :comm, :server, :imit, '#{repository.name}SessionManagerImpl'
      java_artifact :message_broker_impl, :comm, :server, :imit, '#{repository.name}ReplicantMessageBrokerImpl'
      java_artifact :session_rest_service, :rest, :server, :imit, '#{repository.name}SessionRestService'
      java_artifact :server_router, :comm, :server, :imit, '#{repository.name}Router'
      java_artifact :jpa_encoder, :comm, :server, :imit, '#{repository.name}JpaEncoder'
      java_artifact :message_generator, :comm, :server, :imit, '#{repository.name}EntityMessageGenerator'
      java_artifact :change_recorder, :comm, :server, :imit, '#{repository.name}ChangeRecorder'
      java_artifact :change_recorder_impl, :comm, :server, :imit, '#{change_recorder_name}Impl'
      java_artifact :change_listener, :comm, :server, :imit, '#{repository.name}EntityChangeListener'
      java_artifact :replication_interceptor, :comm, :server, :imit, '#{repository.name}ReplicationInterceptor'
      java_artifact :graph_encoder, :comm, :server, :imit, '#{repository.name}GraphEncoder'
      java_artifact :graph_encoder_impl, :comm, :server, :imit, '#{graph_encoder_name}Impl'
      java_artifact :abstract_schema_test, :comm, :client, :imit, 'Abstract#{repository.name}SchemaTest'
      java_artifact :schema_test, :comm, :client, :imit, 'Simple#{repository.name}SchemaTest'
      java_artifact :server_net_module, :test, :server, :imit, '#{repository.name}ImitNetModule', :sub_package => 'util'
      java_artifact :integration_module, :test, :server, :imit, '#{repository.name}IntegrationModule', :sub_package => 'util'

      attr_writer :include_standard_integration_test_module

      def include_standard_integration_test_module?
        @include_standard_integration_test_module.nil? ? true : !!@include_standard_integration_test_module
      end

      def abstract_session_context_impl_name
        qualified_abstract_session_context_impl_name.gsub(/^.*\.([^.]+)$/, '\1')
      end

      def qualified_abstract_session_context_impl_name
        "#{repository.service_by_name(self.session_context_service).ejb.qualified_service_name.gsub(/^(.*)\.([^.]+$)/, '\1.Abstract\2Impl')}"
      end

      def auto_register_change_listener=(auto_register_change_listener)
        @auto_register_change_listener = !!auto_register_change_listener
      end

      def auto_register_change_listener?
        @auto_register_change_listener.nil? ? true : @auto_register_change_listener
      end

      def graphs
        graph_map.values
      end

      def graph(name, options = {}, &block)
        Domgen::Imit::ReplicationGraph.new(self, graph_map.size, name, options, &block)
      end

      def graph_by_name(name)
        graph = graph_map[name.to_s]
        Domgen.error("Unable to locate graph #{name}") unless graph
        graph
      end

      def graph_by_name?(name)
        !!graph_map[name.to_s]
      end

      def subscription_manager=(subscription_manager)
        Domgen.error('subscription_manager invalid. Expected to be in format DataModule.ServiceName') if self.subscription_manager.to_s.split('.').length != 2
        @subscription_manager = subscription_manager
      end

      def subscription_manager
        @subscription_manager || "#{self.imit_control_data_module}.#{repository.name}SubscriptionService"
      end

      def message_broker=(message_broker)
        Domgen.error('message_broker invalid. Expected to be in format DataModule.ServiceName') if self.message_broker.to_s.split('.').length != 2
        @message_broker = message_broker
      end

      def message_broker
        @message_broker || "#{self.imit_control_data_module}.#{repository.name}ReplicantMessageBroker"
      end

      def session_context_service=(session_context_service)
        Domgen.error('session_context_service invalid. Expected to be in format DataModule.SessionContext') if session_context_service.to_s.split('.').length != 2
        @session_context_service = session_context_service
      end

      def session_context_service
        @session_context_service || "#{self.imit_control_data_module}.#{repository.name}SessionContext"
      end

      def client_converger_service=(client_converger_service)
        Domgen.error('client_converger_service invalid. Expected to be in format DataModule.SessionContext') if client_converger_service.to_s.split('.').length != 2
        @client_converger_service = client_converger_service
      end

      def client_converger_service
        @client_converger_service || "#{self.imit_control_data_module}.#{repository.name}ContextConvergerService"
      end

      def imit_control_data_module=(imit_control_data_module)
        @imit_control_data_module = imit_control_data_module
      end

      def imit_control_data_module
        @imit_control_data_module || (self.repository.data_module_by_name?(self.repository.name) ? self.repository.name : Domgen.error('imit_control_data_module unspecified and unable to derive default.'))
      end

      def requires_programmatic_graph_shaping?
        graphs.any? do |graph|
          graph.external_data_load? ||
            graph.bulk_load? ||
            graph.filtered? ||
            (graph.instance_root? && graph.inward_graph_links.any? { |graph_link| graph_link.auto? && repository.imit.graph_by_name(graph_link.target_graph).filtered? })
        end
      end

      def pre_complete
        unless repository.application.user_experience? || 1 != repository.imit.schema_id
          Domgen.error('repository.imit.schema_id must be explicitly set to a value other than 1 as the application expects to be used as a library.')
        end
        if repository.jaxrs?
          repository.jaxrs.extensions << self.qualified_session_rest_service_name
        end
        if repository.ee?
          repository.ee.cdi_scan_excludes << 'replicant.**'
          repository.ee.cdi_scan_excludes << 'org.realityforge.replicant.**'
        end
        toprocess = []
        self.graphs.each do |graph|
          if graph.filter_parameter?
            if graph.filter_parameter.enumeration?
              graph.filter_parameter.enumeration.part_of_filter = true
            elsif graph.filter_parameter.struct?
              struct = graph.filter_parameter.referenced_struct
              toprocess << struct unless toprocess.include?(struct)
            end
          end
        end

        process_filter_structs([], toprocess)
      end

      def process_filter_structs(processed, toprocess)
        until toprocess.empty?
          struct = toprocess.pop
          process_filter_struct(processed, toprocess, struct)
        end
      end

      def process_filter_struct(processed, toprocess, struct)
        return if processed.include?(struct)
        struct.imit.part_of_filter = true
        struct.fields.select { |field| field.imit? }.each do |field|
          if field.enumeration?
            field.enumeration.imit.part_of_filter = true
          elsif field.struct?
            struct = field.referenced_struct
            toprocess << struct unless toprocess.include?(struct)
          end
        end
      end

      def pre_verify
        if repository.gwt_rpc?
          exists = repository.keycloak.client_by_key?(repository.gwt_rpc.keycloak_client)
          client =
            exists ?
              repository.keycloak.client_by_key(repository.gwt_rpc.keycloak_client) :
              repository.keycloak.client(repository.gwt_rpc.keycloak_client)
          unless exists
            client.bearer_only = true
            client.redirect_uris.clear
            client.web_origins.clear
          end
          prefix = repository.jaxrs? ? "/#{repository.jaxrs.path}" : '/api'
          client.protected_url_patterns << prefix + '/session/*'
        end
        if repository.gwt?
          repository.gwt.sting_includes << qualified_schema_sting_fragment_name
          repository.gwt.sting_includes << qualified_gwt_client_session_context_impl_name
        end

        repository.ejb.add_test_module(self.server_net_module_name, self.qualified_server_net_module_name) if repository.ejb?
        if self.graphs.size == 0
          Domgen.error('imit facet enabled but no graphs defined')
        end

        self.repository.service(self.session_context_service) unless self.repository.service_by_name?(self.session_context_service)
        self.repository.service_by_name(self.session_context_service).tap do |s|
          s.disable_facets_not_in(:ejb)
          s.ejb.generate_boundary = false
          s.method(:PreSubscribe) do |m|
            m.parameter(:Session, 'org.realityforge.replicant.server.transport.ReplicantSession')
            m.parameter(:Address, 'org.realityforge.replicant.server.ChannelAddress')
            m.parameter(:Filter, 'java.lang.Object', :nullable => true)
          end
          repository.imit.graphs.select { |graph| graph.filtered? }.each do |graph|
            s.method("FilterMessageOfInterestIn#{graph.name}Graph") do |m|
              m.ejb.generate_base_test = false
              m.parameter(:Message, 'org.realityforge.replicant.server.EntityMessage')
              m.parameter(:Session, 'org.realityforge.replicant.server.transport.ReplicantSession')
              if graph.instance_root?
                entity = repository.entity_by_name(graph.instance_root)
                m.parameter("#{entity.name}#{entity.primary_key.name}", entity.primary_key.jpa.non_primitive_java_type)
              end
              m.parameter(:Filter, graph.filter_parameter.filter_type, filter_options(graph)) if graph.filter_parameter?

              if graph.filtered?
                graph.routing_keys.each do |routing_key|
                  options =
                    {
                      :collection_type => routing_key.multivalued? ? :sequence : :none,
                      :nullable => !graph.instance_root? || !(routing_key.imit_attribute.attribute.entity.qualified_name == graph.instance_root)
                    }
                  target_attribute = routing_key.target_attribute
                  options[:referenced_entity] = target_attribute.referenced_entity if target_attribute.reference?
                  options[:referenced_struct] = target_attribute.referenced_struct if target_attribute.struct?
                  m.parameter(routing_key.name.to_s.gsub('_', ''), target_attribute.attribute_type, options)
                end
              end

              m.returns('org.realityforge.replicant.server.EntityMessage', :nullable => true)
            end
          end

          repository.imit.graphs.each do |graph|
            if graph.bulk_load?
              s.method("BulkCollectFor#{graph.name}") do |m|
                m.ejb.generate_base_test = false
                m.parameter(:Session, 'org.realityforge.replicant.server.transport.ReplicantSession')
                m.parameter(:ChangeSet, 'org.realityforge.replicant.server.ChangeSet')
                m.parameter(:Address, 'org.realityforge.replicant.server.ChannelAddress', :collection_type => :sequence) if graph.instance_root?
                m.parameter(:Filter, graph.filter_parameter.filter_type, filter_options(graph)) if graph.filter_parameter?
                m.boolean(:ExplicitSubscribe)
              end
              if graph.filter_parameter? && !graph.filter_parameter.immutable?
                s.method("BulkCollectFor#{graph.name}FilterChange") do |m|
                  m.ejb.generate_base_test = false
                  m.parameter(:Session, 'org.realityforge.replicant.server.transport.ReplicantSession')
                  m.parameter(:ChangeSet, 'org.realityforge.replicant.server.ChangeSet')
                  m.parameter(:Address, 'org.realityforge.replicant.server.ChannelAddress', :collection_type => :sequence) if graph.instance_root?
                  m.parameter(:OriginalFilter, graph.filter_parameter.filter_type, filter_options(graph))
                  m.parameter(:CurrentFilter, graph.filter_parameter.filter_type, filter_options(graph))
                end
              end
            else
              if graph.external_data_load?
                # We only need this
                s.method("Collect#{graph.name}") do |m|
                  m.parameter(:Address, 'org.realityforge.replicant.server.ChannelAddress')
                  m.parameter(:ChangeSet, 'org.realityforge.replicant.server.ChangeSet')
                  m.parameter(:Filter, graph.filter_parameter.filter_type, filter_options(graph)) if graph.filter_parameter?
                end
              end
              if graph.filter_parameter? && !graph.filter_parameter.immutable?
                s.method("CollectForFilterChange#{graph.name}") do |m|
                  m.parameter(:Session, 'org.realityforge.replicant.server.transport.ReplicantSession')
                  m.parameter(:ChangeSet, 'org.realityforge.replicant.server.ChangeSet') if graph.instance_root?
                  m.parameter(:Address, 'org.realityforge.replicant.server.ChannelAddress')
                  m.reference(graph.instance_root, :name => :Entity) if graph.instance_root?
                  m.parameter(:OriginalFilter, graph.filter_parameter.filter_type, filter_options(graph))
                  m.parameter(:CurrentFilter, graph.filter_parameter.filter_type, filter_options(graph))
                end
              end
            end
            if graph.instance_root?
              if !graph.bulk_load? && graph.filtered?
                graph.reachable_entities.collect { |n| repository.entity_by_name(n) }.select { |entity| entity.imit? && entity.concrete? }.each do |entity|
                  outgoing_links = entity.referencing_attributes.select { |a| a.arez? && a.inverse.imit.traversable? && a.inverse.imit.replication_edges.include?(graph.name) }
                  outgoing_links.each do |a|
                    if a.inverse.multiplicity == :many
                      s.method("Get#{a.inverse.attribute.qualified_name.gsub('.', '')}In#{graph.name}Graph") do |m|
                        m.ejb.generate_base_test = false
                        m.reference(a.referenced_entity.qualified_name, :name => :Entity)
                        m.parameter(:Filter, graph.filter_parameter.filter_type, filter_options(graph)) if graph.filter_parameter?
                        m.returns(:reference, :referenced_entity => a.entity.qualified_name, :collection_type => :sequence)
                      end
                    elsif a.inverse.multiplicity == :one || a.inverse.multiplicity == :zero_or_one
                      s.method("Get#{a.inverse.attribute.qualified_name.gsub('.', '')}In#{graph.name}Graph") do |m|
                        m.ejb.generate_base_test = false
                        m.reference(a.referenced_entity.qualified_name, :name => :Entity)
                        m.parameter(:Filter, graph.filter_parameter.filter_type, filter_options(graph)) if graph.filter_parameter?
                        m.returns(:reference, :referenced_entity => a.entity.qualified_name, :nullable => (a.inverse.multiplicity == :zero_or_one))
                      end
                    end
                  end
                end
              end
            end
          end

          processed = []
          repository.imit.graphs.select { |g| g.instance_root? }.collect { |g| g.inward_graph_links.select { |graph_link| graph_link.auto? } }.flatten.each do |graph_link|
            source_graph = repository.imit.graph_by_name(graph_link.source_graph)
            target_graph = repository.imit.graph_by_name(graph_link.target_graph)
            next unless target_graph.filtered?
            key = "#{graph_link.source_graph}=>#{graph_link.target_graph}"
            next if processed.include?(key)
            processed << key
            source_graph_instance_root = repository.entity_by_name(source_graph.instance_root)
            target_graph_instance_root = repository.entity_by_name(target_graph.instance_root)

            if target_graph.filter_parameter?
              s.method(:"ShouldFollowLinkFrom#{graph_link.source_graph}To#{target_graph.name}") do |m|
                m.reference(target_graph_instance_root.qualified_name, :name => "#{target_graph.name}InstanceRoot") if target_graph.instance_root?
                m.parameter("#{source_graph.name}Filter", source_graph.filter_parameter.filter_type, filter_options(source_graph)) if source_graph.filter_parameter?
                m.returns(:boolean)
              end

              s.method(:"DeriveFilterToPropagateFrom#{graph_link.source_graph}To#{target_graph.name}") do |m|
                m.reference(source_graph_instance_root.qualified_name, :name => "#{source_graph.name}InstanceRoot") if source_graph.instance_root?
                m.parameter("#{source_graph.name}Filter", source_graph.filter_parameter.filter_type, filter_options(source_graph)) if source_graph.filter_parameter?
                m.returns(target_graph.filter_parameter.filter_type, filter_options(target_graph))
              end

              s.method(:"GetLinksToUpdateFor#{graph_link.source_graph}To#{target_graph.name}") do |m|
                m.reference(repository.entity_by_name(source_graph.instance_root).qualified_name, :name => "#{source_graph.name}InstanceRoot") if source_graph.instance_root?
                m.parameter("#{source_graph.name}Filter", source_graph.filter_parameter.filter_type, filter_options(source_graph)) if source_graph.filter_parameter?
                m.returns(:Integer, :collection_type => :sequence)
              end
            end
          end
        end

        self.repository.service(self.subscription_manager) unless self.repository.service_by_name?(self.subscription_manager)
        self.repository.service_by_name(self.subscription_manager).tap do |s|
          s.disable_facets_not_in(:ejb)
          s.ejb.bind_in_tests = false
          s.ejb.generate_base_test = false

          s.method(:RemoveClosedSessions, 'ejb.schedule.hour' => '*', 'ejb.schedule.minute' => '*', 'ejb.schedule.second' => '30')
          s.method(:RemoveAllSessions)
          s.method(:PingSessions, 'ejb.schedule.hour' => '*', 'ejb.schedule.minute' => '*', 'ejb.schedule.second' => '15,45')
        end

        self.repository.service(self.message_broker) unless self.repository.service_by_name?(self.message_broker)
        self.repository.service_by_name(self.message_broker).tap do |s|
          s.disable_facets_not_in(:ejb)
          s.ejb.bind_in_tests = false
          s.ejb.generate_base_test = false

          s.method(:ProcessPendingSessions, 'ejb.schedule.hour' => '*', 'ejb.schedule.minute' => '*', 'ejb.schedule.second' => '*')
        end

        repository.data_modules.select { |data_module| data_module.ejb? }.each do |data_module|
          data_module.services.select { |service| service.ejb? && service.ejb.generate_boundary? }.each do |service|
            service.methods.each do |method|
              if method.service.ejb? && method.service.ejb.generate_boundary?
                method.ejb.boundary_annotations << 'org.realityforge.replicant.server.ee.Replicate'
              end
            end
          end
        end
      end

      def post_complete
        index = 0
        repository.data_modules.select { |data_module| data_module.imit? }.each do |data_module|
          data_module.entities.each do |entity|
            if entity.imit? && entity.concrete?
              entity.imit.transport_id = index
              index += 1
            end
          end
        end
        repository.imit.graphs.select(&:instance_root?).each do |graph|
          root = repository.entity_by_name(graph.instance_root)
          entity_list = [root]
          graph.leaf_list << root.qualified_name.to_s
          while entity_list.size > 0
            entity = entity_list.pop
            unless graph.reachable_entities.include?(entity.qualified_name.to_s)
              graph.reachable_entities << entity.qualified_name.to_s
              entity.referencing_attributes.each do |a|
                if a.imit?
                  if a.inverse.imit.all_exclude_edges.include?(graph.name)
                    # Record the set of edges excluded so that we can later check that the only excluded
                    # edges configured are those that are necessary
                    a.inverse.imit.edges_excluded << graph.name
                  elsif a.inverse.imit.traversable?
                    graph.leaf_list.delete(entity.qualified_name.to_s)
                    a.inverse.imit.replication_edges = a.inverse.imit.replication_edges + [graph.name]
                    Domgen.error("#{a.qualified_name} is not immutable but is on path in graph #{graph.name}") unless a.immutable?
                    unless graph.reachable_entities.include?(a.entity.qualified_name.to_s)
                      entity_list << a.entity
                      graph.leaf_list << a.entity.qualified_name.to_s
                    end
                  end
                end
              end
            end
          end
        end
        repository.imit.graphs.each(&:post_verify)

        repository.data_modules.select { |dm| dm.imit? }.each do |data_module|
          data_module.entities.select { |e| e.imit? }.each do |entity|
            entity.referencing_attributes.select { |a| a.imit? }.each do |a|
              a.inverse.imit.exclude_edges.each do |edge|
                unless a.inverse.imit.edges_excluded.include?(edge)
                  Domgen.error("#{a.qualified_name} defined a 'inverse.imit.exclude_edges' property that includes graph #{edge} that was not used during traversal")
                end
              end
            end
          end
        end

        imitations = []
        repository.data_modules.select { |data_module| data_module.arez? }.each do |data_module|
          data_module.entities.select { |entity| entity.arez? && entity.concrete? }.each do |entity|
            imitations << entity.qualified_name
          end
        end
        repository.imit.graphs.each do |graph|
          graph.included_entities.each do |included_entity|
            imitations.delete(included_entity.to_s)
          end
        end
        unless imitations.empty?
          Domgen.error("Several entities have the arez facet enabled but are not part of any imit replication graph. Entities:\n#{imitations.join("\n")}")
        end
      end

      private

      def filter_options(graph)
        filter_options = {}
        if graph.filter_parameter?
          filter_options =
            {
              :collection_type => graph.filter_parameter.collection_type,
              :nullable => graph.filter_parameter.nullable?
            }
          filter_options[:referenced_entity] = graph.filter_parameter.referenced_entity if graph.filter_parameter.reference?
          filter_options[:referenced_struct] = graph.filter_parameter.referenced_struct if graph.filter_parameter.struct?
        end
        filter_options
      end

      def register_graph(name, graph)
        graph_map[name.to_s] = graph
      end

      def graph_map
        @graphs ||= {}
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::ImitJavaPackage

      java_artifact :mapper, :entity, :client, :imit, '#{data_module.name}Mapper'
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator
    end

    facet.enhance(Parameter) do
      include Domgen::Java::ImitJavaCharacteristic

      def environmental?
        parameter.gwt_rpc? && parameter.gwt_rpc.environmental?
      end

      protected

      def characteristic
        parameter
      end
    end

    facet.enhance(Result) do
      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    facet.enhance(Exception) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :name, :service, :client, :imit, '#{exception.name}Exception'
    end

    facet.enhance(Entity) do
      include Domgen::Java::BaseJavaGenerator

      def transport_id
        Domgen.error('Attempted to invoke transport_id on abstract entity') if entity.abstract?
        @transport_id
      end

      def transport_id=(transport_id)
        Domgen.error('Attempted to assign transport_id on abstract entity') if entity.abstract?
        @transport_id = transport_id
      end

      def interfaces
        @interfaces ||= []
      end

      def replication_root?
        entity.data_module.repository.imit.graphs.any? { |g| g.instance_root? && g.instance_root.to_s == entity.qualified_name.to_s }
      end

      def associated_instance_root_graphs
        entity.data_module.repository.imit.graphs.select { |g| g.instance_root? && g.instance_root.to_s == entity.qualified_name.to_s }
      end

      def associated_type_graphs
        entity.data_module.repository.imit.graphs.select { |g| !g.instance_root? && g.type_roots.include?(entity.qualified_name.to_s) }
      end

      def replicate(graph, replication_type)
        Domgen.error("#{replication_type.inspect} is not of a known type") unless [:instance, :type].include?(replication_type)
        graph = entity.data_module.repository.imit.graph_by_name(graph)
        k = entity.qualified_name
        Domgen.error("Attempting to override instance graph root '#{graph.instance_root}' with '#{k}' is not allowed.") if :instance == replication_type && graph.instance_root?
        graph.instance_root = k if :instance == replication_type
        graph.type_roots.concat([k.to_s]) if :type == replication_type
      end

      def test_create_default(defaults)
        (@test_create_defaults ||= []) << Domgen::Imit::DefaultValues.new(entity, defaults)
      end

      def test_create_defaults
        @test_create_defaults.nil? ? [] : @test_create_defaults.dup
      end

      #
      # subgraph_roots are parts of the graph that are exposed by encoder
      # Useful when collecting entities when a filter is present
      #
      def subgraph_roots
        @subgraph_roots || []
      end

      def subgraph_roots=(subgraph_roots)
        Domgen.error('subgraph_roots expected to be an array') unless subgraph_roots.is_a?(Array)
        subgraph_roots.each do |subgraph_root|
          graph = entity.data_module.repository.imit.graph_by_name(subgraph_root)
          Domgen.error("subgraph_roots specifies a non graph #{subgraph_root}") unless graph
          Domgen.error("subgraph_roots specifies a non-instance graph #{subgraph_root}") unless graph.instance_root?
          Domgen.error("subgraph_roots specifies a non-filtered graph #{subgraph_root}") unless graph.filtered?
        end
        @subgraph_roots = subgraph_roots
      end

      def replication_graphs
        entity.data_module.repository.imit.graphs.select do |graph|
          (graph.instance_root? && graph.reachable_entities.include?(entity.qualified_name.to_s)) ||
            (!graph.instance_root? && graph.type_roots.include?(entity.qualified_name.to_s)) ||
            entity.attributes.any? { |a| a.imit? && a.imit.routing_keys.any? { |routing_key| routing_key.graph.name.to_s == graph.name.to_s } }
        end
      end

      def pre_verify
        if entity.data_module.repository.imit.auto_register_change_listener? && entity.jpa?
          entity.jpa.entity_listeners << entity.data_module.repository.imit.qualified_change_listener_name
        end
      end
    end

    facet.enhance(Attribute) do

      def skip_link_checks
        @skip_link_checks ||= []
      end

      attr_writer :skip_link_checks

      def eager?
        !lazy?
      end

      def lazy=(lazy)
        Domgen.error("Attempted to make non-reference #{attribute.qualified_name} lazy") if lazy && !attribute.reference?
        @lazy = lazy
      end

      def lazy?
        attribute.reference? && (@lazy.nil? ? false : @lazy)
      end

      def filter_in_graphs=(filter_in_graphs)
        Domgen.error('filter_in_graphs should be an array of symbols') unless filter_in_graphs.is_a?(Array) && filter_in_graphs.all? { |m| m.is_a?(Symbol) }
        Domgen.error('filter_in_graphs should only contain valid graphs') unless filter_in_graphs.all? { |m| attribute.entity.data_module.repository.imit.graph_by_name(m) }
        filter_in_graphs.each do |graph|
          routing_key(graph)
        end
      end

      def routing_keys_map
        @routing_keys ||= {}
      end

      def routing_keys
        routing_keys_map.values
      end

      def routing_key(graph, options = {})
        params = options.dup
        name = params.delete(:name) || attribute.qualified_name.gsub('.', '_')
        routing_keys_map["#{graph}#{name}"] = Domgen::Imit::RoutingKey.new(self, name, graph, params)
      end

      def auto_graph_links
        graph_links_map.values.select { |graph_link| graph_link.auto? }
      end

      def graph_links
        graph_links_map.values
      end

      def graph_link(source_graph, target_graph, options = {}, &block)
        key = "#{source_graph}->#{target_graph}"
        Domgen.error("Graph link already defined between #{source_graph} and #{target_graph} on attribute '#{attribute.qualified_name}'") if graph_links_map[key]
        graph_links_map[key] = Domgen::Imit::GraphLink.new(self, "#{key}:#{attribute.qualified_name}", source_graph, target_graph, options, &block)
      end

      include Domgen::Java::ImitJavaCharacteristic

      def post_verify
        self.graph_links.each do |graph_link|
          graph_link.post_verify
        end
        self.routing_keys.each do |routing_key|
          routing_key.post_verify
        end
        if self.attribute.reference?
          referenced_entity = self.attribute.referenced_entity
          Domgen.error("#{self.attribute.qualified_name} has specified an inverse.imit.exclude_edges values but the referenced entity has no imit facet enabled") if !self.attribute.inverse.imit.exclude_edges.empty? && !referenced_entity.imit?
          self.attribute.inverse.imit.exclude_edges.each do |graph_name|
            a = self.attribute
            repository_imit_facet = a.entity.data_module.repository.imit
            Domgen.error("#{a.qualified_name} has specified an inverse.imit.exclude_edges value for graph named '#{graph_name}' but no such graph exists") unless repository_imit_facet.graph_by_name?(graph_name)
            graph = repository_imit_facet.graph_by_name(graph_name)
            Domgen.error("#{a.qualified_name} has specified an inverse.imit.exclude_edges value for graph named '#{graph_name}' but graph is not an instance graph") unless graph.instance_root?
            Domgen.error("#{a.qualified_name} has specified an inverse.imit.exclude_edges value for graph named '#{graph_name}' but referenced entity #{referenced_entity.qualified_name} is not part of the specified graph") unless graph.included_entities.include?(referenced_entity.qualified_name)
          end
        end
      end

      protected

      def graph_links_map
        @graph_links ||= {}
      end

      def characteristic
        attribute
      end
    end

    facet.enhance(InverseElement) do
      def traversable=(traversable)
        Domgen.error("traversable #{traversable} is invalid") unless inverse.class.inverse_traversable_types.include?(traversable)
        @traversable = traversable
      end

      def traversable?
        @traversable.nil? ? (self.inverse.traversable? && self.inverse.attribute.referenced_entity.imit?) : @traversable
      end

      def all_exclude_edges
        self.implicit_exclude_edges + self.exclude_edges
      end

      def edges_excluded
        @edges_excluded ||= []
      end

      def implicit_exclude_edges
        @implicit_exclude_edges ||= []
      end

      def exclude_edges
        @exclude_edges ||= []
      end

      def exclude_edges=(exclude_edges)
        @exclude_edges = exclude_edges
      end

      # Replication edges represent graphs that must be subscribed to when the containing entity is subscribed
      def replication_edges=(replication_edges)
        Domgen.error('replication_edges should be an array of symbols') unless replication_edges.is_a?(Array) && replication_edges.all? { |m| m.is_a?(Symbol) }
        Domgen.error('replication_edges should only be set when traversable?') unless inverse.traversable?
        Domgen.error('replication_edges should only contain valid graphs') unless replication_edges.all? { |m| inverse.attribute.entity.data_module.repository.imit.graph_by_name(m) }
        @replication_edges = replication_edges
      end

      def replication_edges
        @replication_edges || []
      end

      def pre_complete
        if self.inverse.traversable? && !self.inverse.attribute.referenced_entity.imit?
          self.inverse.disable_facet(:imit)
        end
      end
    end

    facet.enhance(EnumerationSet) do
      def part_of_filter?
        !!@part_of_filter
      end

      attr_writer :part_of_filter
    end

    facet.enhance(Struct) do
      def part_of_filter?
        !!@part_of_filter
      end

      attr_writer :part_of_filter

      def filter_for_graph(graph_key, options = {})
        struct.data_module.repository.imit.graph_by_name(graph_key).filter(:struct, options.merge(:referenced_struct => struct.qualified_name))
      end
    end
  end
end
