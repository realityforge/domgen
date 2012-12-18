module Domgen
  module JMS
    class JmsMethod < Domgen.ParentedElement(:method)
      attr_writer :mdb

      def mdb?
        @mdb.nil? ? false : @mdb
      end

      def resource_name
        "mdb/#{mdb_name}"
      end

      attr_writer :mdb_name

      def mdb_name
        @mdb_name || "#{method.name}#{method.service.name}MDB"
      end

      def qualified_mdb_name
        "#{method.service.data_module.jms.service_package}.#{mdb_name}"
      end

      attr_writer :destination_name

      def destination_name
        @destination_name || method.qualified_name.gsub('#','.')
      end

      attr_writer :destination_resource_name

      def destination_resource_name
        @destination_resource_name || "jms/#{destination_name}"
      end

      def destination_type=(destination_type)
        raise "Invalid destination type #{destination_type}" unless %w(javax.jms.Queue javax.jms.Topic).include?(destination_type)
        @destination_type = destination_type
      end

      def destination_type
        @destination_type || 'javax.jms.Queue'
      end

      attr_accessor :message_selector

      def acknowledge_mode=(acknowledge_mode)
        raise "Invalid acknowledge_mode #{acknowledge_mode}" unless %w(Auto-acknowledge Dups-ok-acknowledge).include?(acknowledge_mode)
        @acknowledge_mode = acknowledge_mode
      end

      def acknowledge_mode
        @acknowledge_mode || 'Auto-acknowledge'
      end

      attr_accessor :client_id

      attr_accessor :subscription_name

      attr_accessor :durable

      def durable?
        !!@durable
      end

      #TODO: Validate that at max one parameter and no return
    end

    class JmsClass < Domgen.ParentedElement(:service)
    end

    class JmsPackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::JavaPackage

      protected

      def facet_key
        :ee
      end
    end

    class JmsApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::ServerJavaApplication
    end
  end

  FacetManager.define_facet(:jms,
                            {
                              Method => Domgen::JMS::JmsMethod,
                              Service => Domgen::JMS::JmsClass,
                              DataModule => Domgen::JMS::JmsPackage,
                              Repository => Domgen::JMS::JmsApplication
                            },
                            [:ejb, :jaxb, :ee])
end
