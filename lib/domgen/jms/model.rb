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
  module JMS
    class JmsMethod < Domgen.ParentedElement(:method)
      attr_writer :mdb

      def mdb?
        @mdb.nil? ? false : @mdb
      end

      def resource_name
        "mdb/#{mdb_name}"
      end

      def mdb_name=(mdb_name)
        self.mdb = true
        @mdb_name =mdb_name
      end

      def mdb_name
        @mdb_name || "#{method.name}#{method.service.name}MDB"
      end

      def qualified_mdb_name
        "#{method.service.data_module.jms.service_package}.#{mdb_name}"
      end

      def destination_resource_name=(destination_resource_name)
        self.mdb = true
        @destination_resource_name = destination_resource_name
      end

      def destination_resource_name
        @destination_resource_name || "jms/#{method.qualified_name.gsub('#','.')}"
      end

      def destination_type=(destination_type)
        raise "Invalid destination type #{destination_type}" unless %w(javax.jms.Queue javax.jms.Topic).include?(destination_type)
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
      include Domgen::Java::EEJavaPackage
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
