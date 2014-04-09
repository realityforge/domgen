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
    class ReplicationGraph < Domgen.ParentedElement(:application)
      def initialize(application, name, options, &block)
        @name = name
        @type_roots = []
        @instance_root = nil
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

      def instance_root?
        !@instance_root.nil?
      end

      def type_roots
        raise "type_roots invoked for graph #{name} when instance based" if instance_root?
        @type_roots
      end

      def type_roots=(type_roots)
        raise "Attempted to assign type_roots #{type_roots.inspect} for graph #{name} when instance based on #{@instance_root.inspect}" if instance_root?
        @type_roots = type_roots
      end

      def instance_root
        raise "instance_root invoked for graph #{name} when not instance based" if 0 != @type_roots.size
        @instance_root
      end

      def instance_root=(instance_root)
        raise "Attempted to assign instance_root to #{instance_root.inspect} for graph #{name} when not instance based (type_roots=#{@type_roots.inspect})" if 0 != @type_roots.size
        @instance_root = instance_root
      end

      # Map of attribute that is the link to target graph
      def links
        raise "links invoked for graph #{name} when not instance based" if 0 != @type_roots.size
        @links ||= {}
      end

      def links=(links)
        raise "Attempted to assign links to #{links.inspect} for graph #{name} when not instance based (type_roots=#{@type_roots.inspect})" if 0 != @type_roots.size
        @links = links
      end

      # Return the list of entities reachable in instance graph
      def reachable_entities
        raise "reachable_entities invoked for graph #{name} when not instance based" if 0 != @type_roots.size
        @reachable_entities ||= []
      end

      def filter(parameter_type, options = {}, &block)
        Domgen.error("Attempting to redefine filter on graph #{self.name}") if @filter
        @filter ||= FilterParameter.new(self, parameter_type, options, &block)
      end

      def filter_parameter
        @filter
      end

      def post_verify
        if cacheable? && (filter_parameter || instance_root?)
          raise "Cacheable graphs are not supported for instance based or filterable graphs"
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
        "FilterParameter"
      end

      def qualified_name
        "#{graph.qualified_name}$#{name}"
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

      java_artifact :change_mapper, :comm, :client, :imit, '#{repository.name}ChangeMapper'
      java_artifact :data_loader_service, :comm, :client, :imit, 'Abstract#{repository.name}DataLoaderService'
      java_artifact :client_session, :comm, :client, :imit, '#{repository.name}ClientSessionImpl'
      java_artifact :client_session_interface, :comm, :client, :imit, '#{repository.name}ClientSession'
      java_artifact :graph_enum, :comm, :shared, :imit, '#{repository.name}ReplicationGraph'
      java_artifact :session, :comm, :server, :imit, '#{repository.name}Session'
      java_artifact :session_manager, :comm, :server, :imit, 'Abstract#{repository.name}SessionManager'
      java_artifact :server_session_context, :comm, :server, :imit, '#{repository.name}SessionContext'
      java_artifact :router_interface, :comm, :server, :imit, '#{repository.name}Router'
      java_artifact :router_impl, :comm, :server, :imit, '#{repository.name}RouterImpl'
      java_artifact :jpa_encoder, :comm, :server, :imit, '#{repository.name}JpaEncoder'
      java_artifact :message_constants, :comm, :server, :imit, '#{repository.name}MessageConstants'
      java_artifact :message_generator, :comm, :server, :imit, '#{repository.name}EntityMessageGenerator'
      java_artifact :graph_encoder, :comm, :server, :imit, '#{repository.name}GraphEncoder'
      java_artifact :change_recorder, :comm, :server, :imit, '#{repository.name}ChangeRecorder'
      java_artifact :replication_interceptor, :comm, :server, :imit, '#{repository.name}ReplicationInterceptor'
      java_artifact :graph_encoder_impl, :comm, :server, :imit, '#{repository.name}GraphEncoderImpl'
      java_artifact :services_module, :ioc, :client, :imit, '#{repository.name}ImitServicesModule'
      java_artifact :mock_services_module, :ioc, :client, :imit, '#{repository.name}MockImitServicesModule'

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

      def post_verify
        index = 0
        repository.data_modules.select { |data_module| data_module.imit? }.each do |data_module|
          data_module.entities.each do |entity|
            if entity.imit? && !entity.abstract?
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

      java_artifact :mapper, :entity, :client, :imit, '#{data_module.name}Mapper'
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
        raise "Attempted to invoke transport_id on abstract entity" if entity.abstract?
        @transport_id
      end

      def transport_id=(transport_id)
        raise "Attempted to assign transport_id on abstract entity" if entity.abstract?
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
        raise "#{replication_type.inspect} is not of a known type" unless [:instance, :type].include?(replication_type)
        graph = entity.data_module.repository.imit.graph_by_name(graph)
        k = entity.qualified_name
        graph.instance_root = k if :instance == replication_type
        graph.type_roots.concat([k.to_s]) if :type == replication_type
      end

      def replication_graphs
        entity.data_module.repository.imit.graphs.select do |graph|
          (graph.instance_root? && graph.reachable_entities.include?(entity.qualified_name.to_s)) ||
            (!graph.instance_root? && graph.type_roots.include?(entity.qualified_name.to_s)) ||
            entity.attributes.any? { |a| a.imit? && a.imit.filter_in_graphs.include?(graph.name) }
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

      def post_verify
        entity.jpa.entity_listeners << entity.data_module.repository.imit.qualified_change_recorder_name if entity.jpa?
      end
    end

    facet.enhance(Attribute) do
      def client_side?
        !attribute.reference? || attribute.referenced_entity.imit?
      end

      def filter_in_graphs=(filter_in_graphs)
        raise "filter_in_graphs should be an array of symbols" unless filter_in_graphs.is_a?(Array) && filter_in_graphs.all? { |m| m.is_a?(Symbol) }
        raise "filter_in_graphs should only contain valid graphs" unless filter_in_graphs.all? { |m| attribute.entity.data_module.repository.imit.graph_by_name(m) }
        @filter_in_graphs = filter_in_graphs
      end

      def filter_in_graphs
        @filter_in_graphs || []
      end

      def graph_links
        @graph_links ||= {}
      end

      def graph_links=(graph_links)
        @graph_links = graph_links
      end

      include Domgen::Java::ImitJavaCharacteristic

      protected

      def pre_verify
        self.graph_links.each_pair do |source_graph_key, target_graph_key|
          source_graph = attribute.entity.data_module.repository.imit.graph_by_name(source_graph_key)
          target_graph = attribute.entity.data_module.repository.imit.graph_by_name(target_graph_key)
          prefix = "Link #{source_graph_key}=>#{target_graph_key} on #{attribute.qualified_name}"
          raise "#{prefix} must have an instance graph on the LHS" unless source_graph.instance_root?
          raise "#{prefix} must have an non filtered graph on the LHS" unless source_graph.filter_parameter.nil?
          raise "#{prefix} must have an instance graph on the RHS" unless target_graph.instance_root?
          raise "#{prefix} must have an non filtered graph on the RHS" unless target_graph.filter_parameter.nil?
          source_graph.links[attribute] = target_graph
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

      def replication_edges=(replication_edges)
        raise "replication_edges should be an array of symbols" unless replication_edges.is_a?(Array) && replication_edges.all? { |m| m.is_a?(Symbol) }
        raise "replication_edges should only be set when traversable?" unless inverse.traversable?
        raise "replication_edges should only contain valid graphs" unless replication_edges.all? { |m| inverse.attribute.entity.data_module.repository.imit.graph_by_name(m) }
        @replication_edges = replication_edges
      end

      def replication_edges
        @replication_edges || []
      end
    end
  end
end
