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

      def read_permitted?
        self.access_level == :read || self.access_level == :readwrite
      end

      def write_permitted?
        self.access_level == :write || self.access_level == :readwrite
      end

      attr_accessor :resource_name
      attr_writer :physical_name

      def resource_name
        @resource_name || "#{Reality::Naming.underscore(jms_repository.repository.name)}/jms/#{default_name}"
      end

      def physical_name
        @physical_name || default_name
      end

      def is_queue?
        self.destination_type == 'javax.jms.Queue'
      end

      def destination_type
        @destination_type || 'javax.jms.Queue'
      end

      def destination_type=(destination_type)
        Domgen.error("Invalid destination type #{destination_type}") unless valid_destination_types.include?(destination_type)
        @destination_type = destination_type
      end

      def generate_base_test?
        @generate_base_test.nil? ? true : !!@generate_base_test
      end

      def generate_base_test=(generate_base_test)
        @generate_base_test = generate_base_test
      end

      private

      def default_name
        prefix = self.access_level == :read ? 'Consumer.' : self.access_level == :write ? 'Producer.' : nil
        prefix = "#{jms_repository.repository.name}.#{prefix}" if prefix
        "#{prefix}#{jms_repository.repository.name}.#{name}"
      end

      def valid_destination_types
        %w(javax.jms.Queue javax.jms.Topic)
      end
    end
  end

  FacetManager.facet(:jms => [:ejb, :ee]) do |facet|
    facet.suggested_facets << :jaxb

    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :constants_container, nil, :server, :jms, '#{repository.name}JmsConstants'
      java_artifact :abstract_test_broker, :test, :server, :jms, 'Abstract#{repository.name}Broker', :sub_package => 'util'
      java_artifact :test_broker, :test, :server, :jms, '#{repository.name}Broker', :sub_package => 'util'
      java_artifact :test_broker_factory, :test, :server, :jms, '#{repository.name}BrokerFactory', :sub_package => 'util'
      java_artifact :test_module, :test, :server, :jms, '#{repository.name}JmsServerModule', :sub_package => 'util'

      attr_writer :custom_test_broker

      def custom_test_broker?
        @custom_test_broker.nil? ? false : !!@custom_test_broker
      end

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

      Domgen.target_manager.target(:destination, :repository, :facet_key => :jms)

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

      def pre_verify
        if repository.ejb?
          repository.ejb.add_test_module(self.test_module_name, nil)
          content = <<-JAVA

  protected boolean enableBroker()
  {
    return false;
  }

  @javax.annotation.Nullable
  protected com.google.inject.Module new#{self.repository.name}JmsServerModule()
  {
    return enableBroker() ? new #{self.qualified_test_module_name}() : null;
  }

  @org.testng.annotations.BeforeMethod
  @java.lang.Override
  public void preTest()
    throws Exception
  {
    if( enableBroker() )
    {
      // This is due to bug in GlassFish/Payara where the habitat is accessed incorrectly
      org.glassfish.internal.api.Globals.getStaticHabitat();
    }
    super.preTest();
    if( enableBroker() )
    {
      purgeDestinations();
    }
  }

  @org.testng.annotations.AfterMethod
  @java.lang.Override
  public void postTest()
  {
    if( enableBroker() )
    {
      shutdownJMSContexts();
    }
    super.postTest();
  }

  protected final void shutdownJMSContexts()
  {
    assert enableBroker();
    for ( final com.google.inject.Binding<javax.jms.JMSContext> binding : getInjector().findBindingsByType( com.google.inject.TypeLiteral.get( javax.jms.JMSContext.class ) ) )
    {
      binding.getProvider().get().close();
    }
  }

  protected void purgeDestinations()
    throws Exception
  {
    assert enableBroker();

          JAVA
          self.destinations.each do |destination|
            content += <<-JAVA
    org.realityforge.guiceyloops.server.glassfish.OpenMQUtil.purge#{destination.is_queue? ? 'Queue' : 'Topic' }( #{qualified_constants_container_name}.#{Reality::Naming.uppercase_constantize(destination.name) }_PHYSICAL_NAME );
            JAVA
          end
          content += <<-JAVA
  }

  @javax.annotation.Nonnull
  @java.lang.Override
  protected String getPrimaryJmsConnectionFactoryName()
  {
    return #{qualified_constants_container_name }.CONNECTION_FACTORY_RESOURCE_NAME;
  }

  @javax.annotation.Nonnull
  @java.lang.Override
  protected String getPrimaryBrokerName()
  {
    return "#{repository.name}";
  }

  @org.testng.annotations.BeforeClass
  public void beforeClass()
    throws Exception
  {
    if( enableBroker() )
    {
      #{qualified_test_broker_factory_name}.getBroker().start();
    }
  }

  @org.testng.annotations.AfterClass
  public void afterClass()
  {
    if( enableBroker() )
    {
      #{qualified_test_broker_factory_name}.getBroker().stop();
    }
  }
          JAVA
          repository.ejb.add_test_class_content(content)
        end
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
        service.methods.any? { |m| m.jms? && m.jms.router? }
      end

      def post_complete
        service.disable_facet(:jms) unless service.methods.any? { |m| m.jms? }
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

      java_artifact :mdb, :service, :server, :ee, '#{method.name}#{method.service.name}MDB'

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

      def router?
        !@route_to_destination.nil?
      end

      def route_to_destination=(destination_name)
        r = method.service.data_module.repository
        if r.jms.destination_by_name?(destination_name)
          @route_to_destination = r.jms.destination_by_name(destination_name)
          @route_to_destination.access_level = :readwrite if @route_to_destination.access_level == :read
        else
          @route_to_destination = r.jms.destination(destination_name, :access_level => :write)
        end
        @route_to_destination
      end

      def route_to_destination
        Domgen.error("route_to_destination called on non router method #{method.qualified_name}") if @route_to_destination.nil?
        @route_to_destination
      end

      def pre_complete
        self.method.ejb.generate_base_test = false if self.router?
        self.method.disable_facet(:jms) unless self.router? || self.mdb?
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
