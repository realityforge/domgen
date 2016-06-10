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
  FacetManager.facet(:jms => [:ejb, :jaxb, :ee]) do |facet|
    facet.enhance(Repository) do
      def connection_factory_resource_name=(connection_factory_resource_name)
        @connection_factory_resource_name = connection_factory_resource_name
      end

      def connection_factory_resource_name
        @connection_factory_resource_name || "#{Domgen::Naming.underscore(repository.name)}/jms/ConnectionFactory"
      end

      attr_writer :default_username

      def default_username
        @default_username || Domgen::Naming.underscore(repository.name)
      end

      def endpoint_methods
        repository.data_modules.select { |data_module| data_module.jms? }.collect do |data_module|
          data_module.services.select { |service| service.jms? }.collect do |service|
            service.methods.select { |method| method.jms? && method.jms.mdb? }
          end
        end.flatten
      end

      def router_methods
        repository.data_modules.select { |data_module| data_module.jms? }.collect do |data_module|
          data_module.services.select { |service| service.jms? }.collect do |service|
            service.methods.select { |method| method.jms? && method.jms.router? }
          end
        end.flatten
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

      def resource_name
        "#{Domgen::Naming.underscore(method.service.data_module.repository.name)}/jms/#{mdb_name}"
      end

      java_artifact :mdb, :service, :server, :ee, '#{method.name}#{method.service.name}MDB', :sub_package => 'internal'

      def mdb_name=(mdb_name)
        self.mdb = true
        @mdb_name = mdb_name
      end

      def destination_resource_name=(destination_resource_name)
        self.mdb = true
        @destination_resource_name = destination_resource_name
      end

      def destination_resource_name
        @destination_resource_name || "#{Domgen::Naming.underscore(method.service.data_module.repository.name)}/jms/#{method.qualified_name.gsub('#', '.')}"
      end

      def physical_resource_name=(physical_resource_name)
        self.mdb = true
        @physical_resource_name = physical_resource_name
      end

      def physical_resource_name
        @physical_resource_name || destination_resource_name.gsub(/.*\/jms\//, '')
      end

      def destination_type=(destination_type)
        Domgen.error("Invalid destination type #{destination_type}") unless valid_destination_types.include?(destination_type)
        self.mdb = true
        @destination_type = destination_type
      end

      def destination_type
        @destination_type || 'javax.jms.Queue'
      end

      attr_accessor :message_selector

      def acknowledge_mode=(acknowledge_mode)
        raise "Invalid acknowledge_mode #{acknowledge_mode}" unless %w(Auto-acknowledge Dups-ok-acknowledge).include?(acknowledge_mode)
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

      def route_to_destination_resource_name=(route_to_destination_resource_name)
        self.router = true
        @route_to_destination_resource_name = route_to_destination_resource_name
      end

      def route_to_destination_resource_name
        @route_to_destination_resource_name
      end

      def route_to_destination_type=(route_to_destination_type)
        Domgen.error("Invalid route to destination type #{route_to_destination_type}") unless valid_destination_types.include?(route_to_destination_type)
        @route_to_destination_type = route_to_destination_type
      end

      def route_to_destination_type
        @route_to_destination_type || 'javax.jms.Queue'
      end

      def route_to_physical_resource_name=(physical_resource_name)
        self.router = true
        @route_to_physical_resource_name = physical_resource_name
      end

      def route_to_physical_resource_name
        @route_to_physical_resource_name || route_to_destination_resource_name.gsub(/.*\/jms\//, '')
      end

      def valid_destination_types
        %w(javax.jms.Queue javax.jms.Topic)
      end

      def perform_verify
        unless self.durable?
          raise "Method #{method.qualified_name} is not a durable subscriber but a subscription name is specified." unless self.subscription_name.nil?
          raise "Method #{method.qualified_name} is not a durable subscriber but a client_id is specified." unless self.subscription_name.nil?
        end

        if self.mdb?
          raise "Method #{method.qualified_name} is marked as a mdb but has a return value" unless method.return_value.return_type == :void
          raise "Method #{method.qualified_name} is marked as a mdb but has more than 1 parameter. Parameters: #{method.parameters.collect { |p| p.name }.inspect}" if method.parameters.size > 1
        end
        if self.router?
          raise "Method #{method.qualified_name} is marked as a router but has a return value" unless method.return_value.return_type == :void
          raise "Method #{method.qualified_name} is marked as a router but has more than 1 parameter. Parameters: #{method.parameters.collect { |p| p.name }.inspect}" if method.parameters.size > 1
        end
      end
    end
  end
end
