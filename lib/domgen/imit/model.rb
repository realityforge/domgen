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
          raise "Attempted to define test_default on #{entity.qualified_name} for attribute '#{key}' when attribute when not client side. Defaults = #{defaults.inspect}" unless a.imit.client_side?
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
      def initialize(application, name, options, &block)
        @name = name
        @type_roots = []
        @required_type_graphs = []
        @dependent_type_graphs = []
        @instance_root = nil
        @outward_graph_links = Domgen::OrderedHash.new
        @inward_graph_links = Domgen::OrderedHash.new
        @routing_keys = Domgen::OrderedHash.new
        application.send :register_graph, name, self
        super(application, options, &block)
      end

      attr_reader :application

      attr_reader :name

      def qualified_name
        "#{application.repository.qualified_name}.Graphs.#{name}"
      end

      def cacheable?
        !!@cacheable
      end

      def cacheable=(cacheable)
        @cacheable = cacheable
      end

      def external_data_load?
        filtered? || (@external_data_load.nil? ? false : !!@external_data_load)
      end

      def external_data_load=(external_data_load)
        @external_data_load = external_data_load
      end

      def external_cache_management?
        Domgen.error("external_cache_management? invoked on #{qualified_name} when not cacheable") unless cacheable?
        @external_cache_management.nil? ? false : !!@external_cache_management
      end

      def external_cache_management=(external_cache_management)
        @external_cache_management = external_cache_management
      end

      def instance_root?
        !@instance_root.nil?
      end

      def type_roots
        Domgen.error("type_roots invoked for graph #{name} when instance based") if instance_root?
        @type_roots
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
        Domgen.error("outward_graph_links invoked for graph #{name} when not instance based") if 0 != @type_roots.size
        @outward_graph_links.values
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
        !unfiltered?
      end

      def unfiltered?
        @filter.nil?
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
        self.outward_graph_links.each do |graph_link|
          target_graph = application.repository.imit.graph_by_name(graph_link.target_graph)
          if target_graph.filtered? && self.unfiltered?
            Domgen.error("Graph '#{self.name}' is an unfiltered graph but has an outward link from '#{graph_link.imit_attribute.attribute.qualified_name}' to a filtered graph '#{target_graph.name}'. This is not supported.")
          elsif target_graph.filtered? && self.filtered? && !target_graph.filter_parameter.equiv?(self.filter_parameter)
            Domgen.error("Graph '#{self.name}' has an outward link from '#{graph_link.imit_attribute.attribute.qualified_name}' to a filtered graph '#{target_graph.name}' but has a different filter. This is not supported.")
          end
        end if self.instance_root?

        rtgs = self.required_type_graphs

        entities = self.included_entities

        entities.each do |entity_name|
          entity = application.repository.entity_by_name(entity_name)
          entity.attributes.select { |a| a.reference? && a.imit? && a.imit.client_side? && a.imit.graph_links.empty? }.each do |a|
            referenced_entity = a.referenced_entity

            # Unclear on how to handle this next scenario. Assume a subtype is visible?
            next if referenced_entity.abstract?

            # If linked entity is part of current graph then all is ok.
            next if entities.any? { |e| e == referenced_entity.qualified_name }

            # If entity is part of required type graphs then all is ok
            next if rtgs.any? { |g| g.type_roots.include?(referenced_entity.qualified_name) }

            next if self.instance_root? && self.inward_graph_links.all? do |graph_link|
              application.repository.imit.graph_by_name(graph_link.target_graph).included_entities.any? { |e| e == referenced_entity.qualified_name }
            end

            Domgen.error("Graph '#{self.name}' has a link from '#{a.qualified_name}' to entity '#{referenced_entity.qualified_name}' that is not a instance level graph-link and is not part of any of the dependent type graphs: #{rtgs.collect { |e| e.name }.inspect} and not in current graph #{entities.inspect}.")
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
        key = graph_link.imit_attribute.attribute.qualified_name.to_s
        Domgen.error("Attempted to register duplicate outward graph link on attribute '#{graph_link.imit_attribute.attribute.qualified_name}' on graph '#{self.name}'") if @outward_graph_links[key]
        @outward_graph_links[key] = graph_link
      end

      def register_inward_graph_link(graph_link, from_graph)
        key = "#{from_graph}-#{graph_link.imit_attribute.attribute.qualified_name.to_s}"
        Domgen.error("Attempted to register duplicate inward graph link on attribute '#{graph_link.imit_attribute.attribute.qualified_name}' on graph '#{self.name}' from graph '#{from_graph}'") if @inward_graph_links[key]
        @inward_graph_links[key] = graph_link
      end
    end

    class GraphLink < Domgen.ParentedElement(:imit_attribute)
      def initialize(imit_attribute, source_graph, target_graph, options, &block)
        repository = imit_attribute.attribute.entity.data_module.repository
        unless repository.imit.graph_by_name?(source_graph)
          Domgen.error("Source graph '#{source_graph}' specified for link on #{imit_attribute.attribute.name} does not exist")
        end
        unless repository.imit.graph_by_name?(target_graph)
          Domgen.error("Target graph '#{target_graph}' specified for link on #{imit_attribute.attribute.name} does not exist")
        end
        unless imit_attribute.attribute.reference?
          Domgen.error("Attempted to define a graph link on non-reference attribute '#{imit_attribute.attribute.qualified_name}'")
        end
        @source_graph = source_graph
        @target_graph = target_graph
        super(imit_attribute, options, &block)
        repository.imit.graph_by_name(source_graph).send :register_outward_graph_link, self
        repository.imit.graph_by_name(target_graph).send :register_inward_graph_link, self, source_graph
        self.imit_attribute.attribute.inverse.imit.exclude_edges << target_graph
      end

      attr_reader :source_graph
      attr_reader :target_graph

      attr_reader :path

      def path=(path)
        @path = path
      end

      def post_verify
        entity = self.imit_attribute.attribute.referenced_entity

        # Need to make sure that the path is valid
        if self.path
          prefix = "Graph link from '#{self.source_graph}' to '#{self.target_graph}' via '#{self.imit_attribute.attribute.name}' with path element"
          self.path.to_s.split.each_with_index do |attribute_name_path_element, i|
            other = entity.attribute_by_name(attribute_name_path_element)
            Domgen.error("#{prefix} #{attribute_name_path_element} is nullable") if other.nullable? && i != 0
            Domgen.error("#{prefix} #{attribute_name_path_element} is not immutable") if !other.immutable?
            Domgen.error("#{prefix} #{attribute_name_path_element} is not a reference") if !other.reference?
            entity = other.referenced_entity
          end
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
      # attribtue is not a reference. A null in the path means nokey is
      # selected
      def path
        @path || []
      end

      def path=(path)
        Domgen.error("Path parameter '#{path.inspect}' specified for routing key #{name} on #{imit_attribute.attribute.name} is not an array") unless path.is_a?(Array)
        a = imit_attribute.attribute
        if path.size > 0
          Domgen.error("Path parameter '#{path.inspect}' specified for routing key #{name} on #{imit_attribute.attribute.name} when initial attribute is not a reference") unless a.reference?
          path.each do |path_key|
            self.multivalued = true if is_path_element_recursive?(path_key)
            path_element = get_attribute_name_from_path_element?(path_key)
            Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{imit_attribute.attribute.name} does not refer to a valid attribtue of #{a.referenced_entity.qualified_name}") unless a.referenced_entity.attribute_by_name?(path_element)
            a = a.referenced_entity.attribute_by_name(path_element)
            Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{imit_attribute.attribute.name} references an attribute that is not a reference #{a.qualified_name}") unless a.reference?
          end
        end
        @path = path
      end

      def is_path_element_recursive?(path_element)
        path_element =~ /^\*.*/
      end

      def get_attribute_name_from_path_element?(path_element)
        is_path_element_recursive?(path_element) ? path_element[1, path_element.length] : path_element
      end

      # The name of the attribute that is used in referenced entity. This
      # must be null if the initial attribute is not a reference, otherwise
      # it must match a name in the target entity
      def attribute_name
        Domgen.error("attribute_name invoked for routing key #{name} on #{imit_attribute.attribute.name} when attribute is not a reference") unless reference?
        return @attribute_name unless @attribute_name.nil?
        referenced_entity.primary_key.name
      end

      def attribute_name=(attribute_name)
        unless attribute_name.nil?
          Domgen.error("attribute_name parameter '#{attribute_name.inspect}' specified for routing key #{name} on #{imit_attribute.attribute.name} used when attribute is not a reference") unless reference?
        end
        @attribute_name = attribute_name
      end

      def reference?
        self.path.size > 0 || self.imit_attribute.attribute.reference?
      end

      def referenced_entity
        Domgen.error("referenced_entity invoked on routing key #{name} on #{imit_attribute.attribute.name} when attribute is not a reference") unless reference?
        return self.imit_attribute.attribute.referenced_entity if self.imit_attribute.attribute.reference?
        a = imit_attribute.attribute
        path.each do |path_element|
          a = a.referenced_entity.attribute_by_name(get_attribute_name_from_path_element?(path_element))
        end
        a.referenced_entity
      end

      def target_attribute
        self.reference? ? self.referenced_entity.attribute_by_name(self.attribute_name) : self.imit_attribute.attribute
      end

      attr_writer :multivalued

      def multivalued?
        @multivalued.nil? ? false : !!@multivalued
      end

      def target_nullsafe?
        return true unless self.reference?
        return self.imit_attribute.attribute.reference? if self.path.size == 0

        a = imit_attribute.attribute
        path.each do |path_element|
          return false if is_path_element_recursive?(path_element)
          a = a.referenced_entity.attribute_by_name(get_attribute_name_from_path_element?(path_element))
          return false if a.nullable?
        end
        return !a.nullable?
      end

      def post_verify
        Domgen.error("Routing key #{self.name} on #{self.imit_attribute.attribute.qualified_name} specifies graph '#{self.graph.name}' that is not filtered.") unless self.graph.filtered?
        Domgen.error("Routing key #{self.name} on #{self.imit_attribute.attribute.qualified_name} specifies graph '#{self.graph.name}' that entity is not currently part of.") unless self.graph.included_entities.include?(self.imit_attribute.attribute.entity.qualified_name)
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
        @immutable.nil? ? true : @immutable
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

  FacetManager.facet(:imit => [:gwt_rpc]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      def client_ioc_package
        repository.gwt_rpc.client_ioc_package
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

      # TODO: Consider moving this to gwt?
      attr_writer :model_module

      def model_module
        @model_module || "#{repository.java.base_package}.#{repository.name}Model"
      end

      java_artifact :repository_debugger, :comm, :client, :imit, '#{repository.name}RepositoryDebugger'
      java_artifact :change_mapper, :comm, :client, :imit, '#{repository.name}ChangeMapperImpl'
      java_artifact :data_loader_service, :comm, :client, :imit, '#{repository.name}DataLoaderServiceImpl'
      java_artifact :client_session_context, :comm, :client, :imit, '#{repository.name}SessionContext'
      java_artifact :client_session, :comm, :client, :imit, '#{repository.name}ClientSessionImpl'
      java_artifact :client_router_interface, :comm, :client, :imit, '#{repository.name}ClientRouter'
      java_artifact :client_router_impl, :comm, :client, :imit, '#{repository.name}ClientRouterImpl'
      java_artifact :data_loader_service_interface, :comm, :client, :imit, '#{repository.name}DataLoaderService'
      java_artifact :client_session_interface, :comm, :client, :imit, '#{repository.name}ClientSession'
      java_artifact :graph_enum, :comm, :shared, :imit, '#{repository.name}ReplicationGraph'
      java_artifact :session, :comm, :server, :imit, '#{repository.name}Session'
      java_artifact :session_manager, :comm, :server, :imit, '#{repository.name}SessionManager#{repository.ejb.implementation_suffix}'
      java_artifact :session_rest_service, :rest, :server, :imit, '#{repository.name}SessionRestService'
      java_artifact :session_exception_mapper, :rest, :server, :imit, '#{repository.name}BadSessionExceptionMapper'
      java_artifact :router_interface, :comm, :server, :imit, '#{repository.name}Router'
      java_artifact :router_impl, :comm, :server, :imit, '#{repository.name}RouterImpl'
      java_artifact :jpa_encoder, :comm, :server, :imit, '#{repository.name}JpaEncoder'
      java_artifact :message_constants, :comm, :server, :imit, '#{repository.name}MessageConstants'
      java_artifact :message_generator_interface, :comm, :server, :imit, '#{repository.name}EntityMessageGenerator'
      java_artifact :message_generator, :comm, :server, :imit, '#{repository.name}EntityMessageGeneratorImpl'
      java_artifact :graph_encoder, :comm, :server, :imit, '#{repository.name}GraphEncoder'
      java_artifact :change_recorder, :comm, :server, :imit, '#{repository.name}ChangeRecorder'
      java_artifact :change_recorder_impl, :comm, :server, :imit, '#{repository.name}ChangeRecorderImpl'
      java_artifact :change_listener, :comm, :server, :imit, '#{repository.name}EntityChangeListener'
      java_artifact :replication_interceptor, :comm, :server, :imit, '#{repository.name}ReplicationInterceptor'
      java_artifact :graph_encoder_impl, :comm, :server, :imit, '#{repository.name}GraphEncoderImpl'
      java_artifact :services_module, :ioc, :client, :imit, '#{repository.name}ImitServicesModule'
      java_artifact :mock_services_module, :test, :client, :imit, '#{repository.name}MockImitServicesModule', :sub_package => 'util'
      java_artifact :callback_success_answer, :test, :client, :imit, '#{repository.name}CallbackSuccessAnswer', :sub_package => 'util'
      java_artifact :callback_failure_answer, :test, :client, :imit, '#{repository.name}CallbackFailureAnswer', :sub_package => 'util'
      java_artifact :abstract_client_test, :test, :client, :imit, 'Abstract#{repository.name}ClientTest', :sub_package => 'util'
      java_artifact :server_net_module, :test, :server, :imit, '#{repository.name}ImitNetModule', :sub_package => 'util'
      java_artifact :test_factory_set, :test, :client, :imit, '#{repository.name}FactorySet', :sub_package => 'util'
      java_artifact :integration_module, :test, :server, :imit, '#{repository.name}IntegrationModule', :sub_package => 'util'

      def qualified_client_session_context_impl_name
        "#{qualified_client_session_context_name}Impl"
      end

      def abstract_session_context_impl_name
        qualified_abstract_session_context_impl_name.gsub(/^.*\.([^.]+)$/, '\1')
      end

      def qualified_abstract_session_context_impl_name
        "#{repository.service_by_name(self.session_context_service).ejb.qualified_service_name.gsub(/^(.*)\.([^.]+$)/, '\1.Abstract\2Impl')}"
      end

      def extra_test_modules
        @extra_test_modules ||= []
      end

      def replicate_mode=(replicate_mode)
        Domgen.error("replicate_mode '#{replicate_mode}' is invalid. Must be one of #{self.class.valid_replicate_modes.inspect}") unless self.class.valid_replicate_modes.include?(replicate_mode)
        @replicate_mode = replicate_mode
      end

      def replicate_mode
        @replicate_mode || :poll
      end

      def poll_replicate_mode?
        :poll == replicate_mode
      end

      def undefined_replicate_mode?
        :undefined == replicate_mode
      end

      def self.valid_replicate_modes
        [:poll, :undefined]
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
        Domgen::Imit::ReplicationGraph.new(self, name, options, &block)
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
        @subscription_manager || "#{self.imit_control_data_module}.SubscriptionService"
      end

      def invalid_session_exception=(invalid_session_exception)
        Domgen.error('invalid_session_exception invalid. Expected to be in format DataModule.Exception') if invalid_session_exception.to_s.split('.').length != 2
        @invalid_session_exception = invalid_session_exception
      end

      def invalid_session_exception
        @invalid_session_exception || "#{self.imit_control_data_module}.BadSession"
      end

      def session_context_service=(session_context_service)
        Domgen.error('invalid_session_exception invalid. Expected to be in format DataModule.SessionContext') if session_context_service.to_s.split('.').length != 2
        @session_context_service = session_context_service
      end

      def session_context_service
        @session_context_service || "#{self.imit_control_data_module}.SessionContext"
      end

      def imit_control_data_module=(imit_control_data_module)
        @imit_control_data_module = imit_control_data_module
      end

      def imit_control_data_module
        @imit_control_data_module || (self.repository.data_module_by_name?(self.repository.name) ? self.repository.name : Domgen.error('imit_control_data_module unspecified and unable to derive default.'))
      end

      def pre_complete
        if repository.jaxrs?
          repository.jaxrs.extensions << self.qualified_session_rest_service_name
          repository.jaxrs.extensions << self.qualified_session_exception_mapper_name
          repository.jaxrs.extensions << 'org.realityforge.replicant.server.ee.rest.ReplicantPollResource'
        end
      end

      def pre_verify
        repository.ejb.extra_test_modules << self.qualified_server_net_module_name if repository.ejb?
        if self.graphs.size == 0
          Domgen.error('imit facet enabled but no graphs defined')
        end

        self.repository.exception(self.invalid_session_exception) unless self.repository.exception_by_name?(self.invalid_session_exception)
        self.repository.exception_by_name(self.invalid_session_exception).tap do |e|
          e.java.exception_category = :runtime
          e.ejb.rollback = false
          (e.all_enabled_facets - [:java, :ee, :ejb, :gwt, :gwt_rpc, :json, :jackson, :imit]).each do |facet_key|
            e.disable_facet(facet_key) if e.facet_enabled?(facet_key)
          end
        end

        self.repository.service(self.session_context_service) unless self.repository.service_by_name?(self.session_context_service)
        self.repository.service_by_name(self.session_context_service).tap do |s|
          (s.all_enabled_facets - [:java, :ee, :ejb]).each do |facet_key|
            s.disable_facet(facet_key) if s.facet_enabled?(facet_key)
          end
          repository.imit.graphs.each do |graph|
            s.method("FilterMessageOfInterestIn#{graph.name}Graph") do |m|
              m.parameter(:Message, 'org.realityforge.replicant.server.EntityMessage')
              m.parameter(:Session, self.repository.imit.qualified_session_name)
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
                  options[:referenced_entity] = routing_key.target_attribute.referenced_entity if routing_key.target_attribute.reference?
                  options[:referenced_struct] = routing_key.target_attribute.referenced_struct if routing_key.target_attribute.struct?
                  m.parameter(routing_key.name,
                              routing_key.target_attribute.attribute_type,
                              options)
                end
              end

              m.returns('org.realityforge.replicant.server.EntityMessage', :nullable => true)
            end
          end

          repository.imit.graphs.each do |graph|
            if !graph.instance_root?
              if graph.cacheable? && graph.external_cache_management?
                s.method("Get#{graph.name}CacheKey") do |m|
                  m.returns(:text, :nullable => true)
                end
              end
              if graph.filter_parameter? && !graph.filter_parameter.immutable?
                s.method("CollectForFilterChange#{graph.name}") do |m|
                  m.parameter(:Messages, 'org.realityforge.replicant.server.EntityMessageSet')
                  m.parameter(:OriginalFilter, graph.filter_parameter.filter_type, filter_options(graph))
                  m.parameter(:CurrentFilter, graph.filter_parameter.filter_type, filter_options(graph))
                end
              end
              if graph.external_data_load? || graph.filter_parameter?
                s.method("Collect#{graph.name}") do |m|
                  m.parameter(:Messages, 'org.realityforge.replicant.server.EntityMessageSet')
                  m.parameter(:Filter, graph.filter_parameter.filter_type, filter_options(graph)) if graph.filter_parameter?
                end
              end
            else
              if graph.filter_parameter?
                unless graph.filter_parameter.immutable?
                  s.method("CollectForFilterChange#{graph.name}") do |m|
                    m.parameter(:Messages, 'org.realityforge.replicant.server.EntityMessageSet')
                    m.reference(graph.instance_root, :name => :Entity)
                    m.parameter(:OriginalFilter, graph.filter_parameter.filter_type, filter_options(graph))
                    m.parameter(:CurrentFilter, graph.filter_parameter.filter_type, filter_options(graph))
                  end
                end

                graph.reachable_entities.collect { |n| repository.entity_by_name(n) }.select { |entity| entity.imit? && entity.concrete? }.each do |entity|
                  outgoing_links = entity.referencing_attributes.select { |a| a.imit? && a.imit.client_side? && a.inverse.imit.traversable? && a.inverse.imit.replication_edges.include?(graph.name) }
                  outgoing_links.each do |a|
                    if a.inverse.multiplicity == :many
                      s.method("Get#{a.inverse.attribute.qualified_name.gsub('.','')}In#{graph.name}Graph") do |m|
                        m.reference(a.referenced_entity.qualified_name, :name => :Entity)
                        m.parameter(:Filter, graph.filter_parameter.filter_type, filter_options(graph))
                        m.returns(:reference, :referenced_entity => a.entity.qualified_name, :collection_type => :sequence)
                      end
                    elsif a.inverse.multiplicity == :one || a.inverse.multiplicity == :zero_or_one
                      s.method("Get#{a.inverse.attribute.qualified_name.gsub('.','')}In#{graph.name}Graph") do |m|
                        m.reference(a.referenced_entity.qualified_name, :name => :Entity)
                        m.parameter(:Filter, graph.filter_parameter.filter_type, filter_options(graph))
                        m.returns(:reference, :referenced_entity => a.entity.qualified_name, :nullable => (a.inverse.multiplicity == :zero_or_one))
                      end
                    end
                  end
                end
              end
            end
          end

          processed = []
          repository.imit.graphs.select { |g| g.instance_root? }.collect { |g| g.inward_graph_links }.flatten.each do |graph_link|
            source_graph = repository.imit.graph_by_name(graph_link.source_graph)
            target_graph = repository.imit.graph_by_name(graph_link.target_graph)
            next unless target_graph.filtered?
            key = "#{graph_link.source_graph}=>#{graph_link.target_graph}"
            next if processed.include?(key)
            processed << key
            instance_root = repository.entity_by_name(target_graph.instance_root)

            s.method(:"ShouldFollowLinkFrom#{graph_link.source_graph}To#{target_graph.name}") do |m|
              m.reference(instance_root.qualified_name, :name => :Entity)
              m.parameter(:Filter, source_graph.filter_parameter.filter_type, filter_options(source_graph))
              m.returns(:boolean)
            end

            s.method(:"GetLinksToUpdateFor#{graph_link.source_graph}To#{target_graph.name}") do |m|
              m.reference(repository.entity_by_name(source_graph.instance_root).qualified_name, :name => :Entity)
              m.parameter(:Filter, source_graph.filter_parameter.filter_type, filter_options(source_graph))
              m.returns(:reference, :referenced_entity => instance_root, :collection_type => :sequence)
            end
          end
        end

        self.repository.service(self.subscription_manager) unless self.repository.service_by_name?(self.subscription_manager)
        self.repository.service_by_name(self.subscription_manager).tap do |s|
          (s.all_enabled_facets - [:java, :ee, :ejb, :gwt, :gwt_rpc, :json, :jackson, :imit]).each do |facet_key|
            s.disable_facet(facet_key) if s.facet_enabled?(facet_key)
          end
          s.ejb.bind_in_tests = false
          s.ejb.generate_base_test = false

          s.method(:RemoveIdleSessions, 'ejb.schedule.hour' => '*', 'ejb.schedule.minute' => '*', 'ejb.schedule.second' => '30')

          repository.imit.graphs.each do |graph|
            s.method(:"SubscribeTo#{graph.name}") do |m|
              m.string(:ClientID, 50)
              if graph.cacheable?
                m.imit.graph_to_subscribe = graph.name
                m.text(:ETag, :nullable => true)
                m.returns(:boolean)
              end
              m.reference(graph.instance_root) if graph.instance_root?
              m.parameter(:Filter, graph.filter_parameter.filter_type, filter_options(graph)) if graph.filtered?
              m.exception(self.invalid_session_exception)
            end
            if graph.filtered? && !graph.filter_parameter.immutable?
              s.method(:"Update#{graph.name}Subscription") do |m|
                m.string(:ClientID, 50)
                m.reference(graph.instance_root) if graph.instance_root?
                m.parameter(:Filter, graph.filter_parameter.filter_type, filter_options(graph))
                m.exception(self.invalid_session_exception)
              end
            end
            s.method(:"UnsubscribeFrom#{graph.name}") do |m|
              m.string(:ClientID, 50)
              m.reference(graph.instance_root) if graph.instance_root?
              m.exception(self.invalid_session_exception)
            end
          end
          if self.poll_replicate_mode?
            s.method(:Poll) do |m|
              m.string(:ClientID, 50)
              m.integer(:LastSequenceAcked)
              m.returns(:text, :nullable => true) do |a|
                a.description('A change set represented as json or null if no change set outstanding.')
              end
              m.exception(self.invalid_session_exception)
            end
          end
        end

        repository.data_modules.select { |data_module| data_module.ejb? }.each do |data_module|
          data_module.services.select { |service| service.ejb? && service.ejb.generate_boundary? }.each do |service|
            if repository.ee.use_cdi?
              service.ejb.boundary_annotations << 'org.realityforge.replicant.server.ee.Replicate'
            else
              service.ejb.boundary_interceptors << repository.imit.qualified_replication_interceptor_name
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
        repository.imit.graphs.select { |graph| graph.instance_root? }.each do |graph|
          entity_list = [repository.entity_by_name(graph.instance_root)]
          while entity_list.size > 0
            entity = entity_list.pop
            if !graph.reachable_entities.include?(entity.qualified_name.to_s)
              graph.reachable_entities << entity.qualified_name.to_s
              entity.referencing_attributes.each do |a|
                if a.imit? && a.imit.client_side? && a.inverse.imit.traversable? && !a.inverse.imit.exclude_edges.include?(graph.name)
                  a.inverse.imit.replication_edges = a.inverse.imit.replication_edges + [graph.name]
                  entity_list << a.entity unless graph.reachable_entities.include?(a.entity.qualified_name.to_s)
                end
              end
            end
          end
        end
        repository.imit.graphs.each { |g| g.post_verify }
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
        @graphs ||= Domgen::OrderedHash.new
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::ImitJavaPackage

      attr_writer :short_test_code

      def short_test_code
        @short_test_code || Domgen::Naming.split_into_words(data_module.name.to_s).collect { |w| w[0, 1] }.join.downcase
      end

      java_artifact :mapper, :entity, :client, :imit, '#{data_module.name}Mapper'
      java_artifact :abstract_test_factory, :entity, :client, :imit, 'Abstract#{data_module.name}Factory'

      attr_writer :test_factory_name

      def test_factory_name
        @test_factory_name || abstract_test_factory_name.gsub(/^Abstract/, '')
      end

      def qualified_test_factory_name
        "#{client_entity_package}.#{test_factory_name}"
      end
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :name, :service, :client, :imit, '#{service.name}'
      java_artifact :proxy, :service, :client, :imit, '#{name}Impl', :sub_package => 'internal'
    end

    facet.enhance(Method) do
      def bulk_load=(bulk_load)
        @bulk_load = !!bulk_load
      end

      def bulk_load?
        @bulk_load.nil? ? false : @bulk_load
      end

      # TODO: Remove this ugly hack!
      attr_accessor :graph_to_subscribe
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

      java_artifact :name, :entity, :client, :imit, '#{entity.name}'

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

      def referencing_client_side_attributes
        entity.referencing_attributes.select do |attribute|
          attribute.entity.imit? &&
            attribute.inverse.imit? &&
            attribute.inverse.imit.traversable? &&
            entity == attribute.referenced_entity &&
            attribute.imit? &&
            attribute.referenced_entity.imit?
        end
      end

      def pre_verify
        if entity.data_module.repository.imit.auto_register_change_listener? && entity.jpa?
          entity.jpa.entity_listeners << entity.data_module.repository.imit.qualified_change_listener_name
        end
      end
    end

    facet.enhance(Attribute) do
      def client_side=(client_side)
        @client_side = client_side
      end

      def client_side?
        @client_side.nil? ? (!attribute.reference? || attribute.referenced_entity.imit?) : @client_side
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

      def graph_links_map
        @graph_links ||= {}
      end

      def graph_links
        graph_links_map.values
      end

      def graph_link(source_graph, target_graph, options = {}, &block)
        key = "#{source_graph}->#{target_graph}"
        Domgen.error("Graph link already defined between #{source_graph} and #{target_graph} on attribute '#{attribute.qualified_name}'") if graph_links_map[key]
        graph_links_map[key] = Domgen::Imit::GraphLink.new(self, source_graph, target_graph, options, &block)
      end

      include Domgen::Java::ImitJavaCharacteristic

      def post_verify
        self.graph_links.each do |graph_link|
          graph_link.post_verify
        end
        self.routing_keys.each do |routing_key|
          routing_key.post_verify
        end
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
    end

    facet.enhance(Struct) do
      def filter_for_graph(graph_key, options = {})
        struct.data_module.repository.imit.graph_by_name(graph_key).filter(:struct, options.merge(:referenced_struct => struct.qualified_name))
      end
    end
  end
end
