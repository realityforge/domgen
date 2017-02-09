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
  module Jms
    class Destination < Domgen.ParentedElement(:jms_repository)
      def initialize(jms_repository, name, options = {}, &block)
        @name = name
        super(jms_repository, options, &block)
      end

      include Domgen::Java::BaseJavaGenerator

      attr_accessor :name

      def access_level
        @access_level || :read
      end

      def access_level=(access_level)
        Domgen.error("Bad access level '#{access_level}' specified for jms destination #{name}") unless [:read, :write, :readwrite].include?(access_level)
        @access_level = access_level
      end

      attr_accessor :resource_name
      attr_writer :physical_name

      def resource_name
        @resource_name || "#{jms_repository.repository.name}/jms/#{default_name}"
      end

      def physical_name
        @physical_name || default_name
      end

      def destination_type
        @destination_type || 'javax.jms.Queue'
      end

      def destination_type=(destination_type)
        Domgen.error("Invalid destination type #{destination_type}") unless valid_destination_types.include?(destination_type)
        @destination_type = destination_type
      end

      private

      def default_name
        "#{jms_repository.repository.name}.#{access_level == :read ? 'Consumer.' : access_level == :write ? 'Producer.' : ''}#{jms_repository.repository.name}.#{name}"
      end

      def valid_destination_types
        %w(javax.jms.Queue javax.jms.Topic)
      end
    end
  end

  FacetManager.facet(:jms => [:ejb, :jaxb, :ee]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :constants_container, nil, :server, :jms, '#{repository.name}JmsConstants'

      def destination(name, options = {}, &block)
        Domgen.error("Attempting to register duplicate destination #{name}") if destination_map[name.to_s]
        destination_map[name.to_s] = Domgen::Jms::Destination.new(self, name, options, &block)
      end

      def destination_by_name?(name)
        !!destination_map[name.to_s]
      end

      def destination_by_name(name)
        destination = destination_map[name.to_s]
        Domgen.error("Unable to locate destination #{name}. Valid destinations include #{destination_map.keys.inspect}") unless destination
        destination
      end

      def destinations
        destination_map.values.dup
      end

      def connection_factory_resource_name=(connection_factory_resource_name)
        @connection_factory_resource_name = connection_factory_resource_name
      end

      def connection_factory_resource_name
        @connection_factory_resource_name || "#{Reality::Naming.underscore(repository.name)}/jms/ConnectionFactory"
      end

      def additional_connection_factory_properties
        @additional_connection_factory_properties ||= {
          'transaction_support' => 'NoTransaction'
        }
      end

      attr_writer :default_username

      def default_username
        @default_username || Reality::Naming.underscore(repository.name)
      end

      private

      def destination_map
        @destinations ||= {}
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      attr_accessor :router_extends

      java_artifact :abstract_router, :service, :server, :jms, 'Abstract#{service.ejb.service_name}Impl'

      def router?
        service.methods.any? { |m| m.jms.router? }
      end

      def post_complete
        active = false
        service.methods.each do |method|
          next unless method.jms?
          if method.jms.router? || method.jms.mdb?
            active = true
          else
            method.disable_facet(:jms)
          end
        end
        service.disable_facet(:jms) unless active
      end
    end

    facet.enhance(Parameter) do
      attr_accessor :object_factory
    end

    facet.enhance(Method) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :mdb

      def mdb?
        @mdb.nil? ? false : @mdb
      end

      attr_writer :router

      def router?
        @router.nil? ? false : @router
      end

      def destination=(destination_name)
        self.mdb = true
        r = method.service.data_module.repository
        @destination = r.jms.destination_by_name?(destination_name) ? r.jms.destination_by_name(destination_name) : r.jms.destination(destination_name)
      end

      def destination
        Domgen.error("destination called on non router method #{method.qualified_name}") if @destination.nil?
        @destination
      end

      def mdb_resource_name
        "#{Reality::Naming.underscore(method.service.data_module.repository.name)}/jms/#{mdb_name}"
      end

      java_artifact :mdb, :service, :server, :ee, '#{method.name}#{method.service.name}MDB', :sub_package => 'internal'

      def mdb_name=(mdb_name)
        self.mdb = true
        @mdb_name = mdb_name
      end

      attr_accessor :message_selector

      def acknowledge_mode=(acknowledge_mode)
        Domgen.error("Invalid acknowledge_mode #{acknowledge_mode}") unless %w(Auto-acknowledge Dups-ok-acknowledge).include?(acknowledge_mode)
        self.mdb = true
        @acknowledge_mode = acknowledge_mode
      end

      def acknowledge_mode
        @acknowledge_mode || 'Auto-acknowledge'
      end

      attr_writer :client_id

      def client_id
        @client_id || (self.durable? ? method.service.data_module.repository.name : nil)
      end

      attr_writer :subscription_name

      def subscription_name
        @subscription_name || (self.durable? ? method.qualified_name.gsub(/[#.]/, '') : nil)
      end

      attr_accessor :durable

      def durable?
        !!@durable
      end

      def route_to_destination=(destination_name)
        self.router = true
        r = method.service.data_module.repository
        @route_to_destination = r.jms.destination_by_name?(destination_name) ? r.jms.destination_by_name(destination_name) : r.jms.destination(destination_name)
      end

      def route_to_destination
        Domgen.error("route_to_destination called on non router method #{method.qualified_name}") if @route_to_destination.nil?
        @route_to_destination
      end

      def pre_complete
        self.method.ejb.generate_base_test = false if self.router?
      end

      def perform_verify
        unless self.durable?
          Domgen.error("Method #{method.qualified_name} is not a durable subscriber but a subscription name is specified.") unless self.subscription_name.nil?
          Domgen.error("Method #{method.qualified_name} is not a durable subscriber but a client_id is specified.") unless self.subscription_name.nil?
        end

        if self.mdb?
          Domgen.error("Method #{method.qualified_name} is marked as a mdb but has a return value") unless method.return_value.return_type == :void
          Domgen.error("Method #{method.qualified_name} is marked as a mdb but has more than 1 parameter. Parameters: #{method.parameters.collect { |p| p.name }.inspect}") if method.parameters.size > 1
        end
        if self.router?
          Domgen.error("Method #{method.qualified_name} is marked as a router but has a return value") unless method.return_value.return_type == :void
          Domgen.error("Method #{method.qualified_name} is marked as a router but has more than 1 parameter. Parameters: #{method.parameters.collect { |p| p.name }.inspect}") if method.parameters.size > 1
        end
      end
    end
  end
end
