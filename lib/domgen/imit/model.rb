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

    class ImitationAttributeInverse < Domgen.ParentedElement(:inverse)
      def traversable=(traversable)
        Domgen.error("traversable #{traversable} is invalid") unless inverse.class.inverse_traversable_types.include?(traversable)
        @traversable = traversable
      end

      def traversable?
        @traversable.nil? ? (self.inverse.traversable? && self.inverse.attribute.referenced_entity.imit?) : @traversable
      end

      def replication_modes=(replication_modes)
        raise "replication_modes should be an array of symbols" unless replication_modes.is_a?(Array) && replication_modes.all? { |m| m.is_a?(Symbol) }
        raise "replication_modes should only be set when traversable?" unless inverse.traversable?
        @replication_modes = replication_modes
      end

      def replication_modes
        @replication_modes || [:default]
      end
    end

    class ImitationAttribute < Domgen.ParentedElement(:attribute)

      def client_side?
        !attribute.reference? || attribute.referenced_entity.imit?
      end

      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        attribute
      end
    end

    class ImitationResult < Domgen.ParentedElement(:result)

      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    class ImitationParameter < Domgen.ParentedElement(:parameter)
      include Domgen::Java::ImitJavaCharacteristic

      def environmental?
        parameter.gwt_rpc? && parameter.gwt_rpc.environmental?
      end

      protected

      def characteristic
        parameter
      end
    end

    class ImitationService < Domgen.ParentedElement(:service)
      attr_writer :name

      def name
        @name || service.name
      end

      def qualified_name
        "#{service.data_module.imit.service_package}.#{name}"
      end

      attr_writer :proxy_name

      def proxy_name
        @proxy_name || "#{name}Proxy"
      end

      def qualified_proxy_name
        "#{service.data_module.imit.service_package}.#{proxy_name}"
      end
    end

    class ImitationMethod < Domgen.ParentedElement(:method)
    end

    class ImitationException < Domgen.ParentedElement(:exception)
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.imit.service_package}.#{name}"
      end
    end

    class ImitationEntity < Domgen.ParentedElement(:entity)

      def transport_id
        raise "Attempted to invoke transport_id on abstract entity" if entity.abstract?
        @transport_id
      end

      def transport_id=(transport_id)
        raise "Attempted to assign transport_id on abstract entity" if entity.abstract?
        @transport_id = transport_id
      end

      def name
        entity.name
      end

      def qualified_name
        "#{entity.data_module.imit.entity_package}.#{name}"
      end

      def replication_root?
        @replication_root.nil? ? false : @replication_root
      end

      attr_writer :replication_root

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
    end

    class ImitationModule < Domgen.ParentedElement(:data_module)
      include Domgen::Java::ImitJavaPackage

      attr_writer :encoder_package

      def encoder_package
        @encoder_package || "#{data_module.repository.imit.encoder_package}.#{Domgen::Naming.underscore(data_module.name)}"
      end

      attr_writer :decoder_package

      def decoder_package
        @decoder_package || "#{data_module.repository.imit.decoder_package}.#{Domgen::Naming.underscore(data_module.name)}"
      end

      def mapper_name
        "#{data_module.name}Mapper"
      end

      def qualified_mapper_name
        "#{entity_package}.#{mapper_name}"
      end

      def updater_name
        "#{data_module.name}Updater"
      end

      def qualified_updater_name
        "#{entity_package}.#{updater_name}"
      end
    end

    class ImitationApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::ClientJavaApplication
      attr_writer :async_callback_name

      def async_callback_name
        @async_callback_name || "#{repository.name}AsyncCallback"
      end

      def qualified_async_callback_name
        "#{service_package}.#{async_callback_name}"
      end

      attr_writer :async_error_callback_name

      def async_error_callback_name
        @async_error_callback_name || "#{repository.name}AsyncErrorCallback"
      end

      def qualified_async_error_callback_name
        "#{service_package}.#{async_error_callback_name}"
      end

      def ioc_package
        repository.gwt_rpc.client_ioc_package
      end

      attr_writer :encoder_package

      def encoder_package
        @encoder_package || repository.jpa.entity_package
      end

      attr_writer :decoder_package

      def decoder_package
        @decoder_package || "#{repository.imit.package}.transport"
      end

      def change_mapper_name
        "#{repository.name}ChangeMapper"
      end

      def qualified_change_mapper_name
        "#{entity_package}.#{change_mapper_name}"
      end

      def router_interface_name
        "#{repository.name}Router"
      end

      def qualified_router_interface_name
        "#{encoder_package}.#{router_interface_name}"
      end

      def jpa_encoder_name
        "#{repository.name}JpaEncoder"
      end

      def qualified_jpa_encoder_name
        "#{encoder_package}.#{jpa_encoder_name}"
      end

      def message_constants_name
        "#{repository.name}MessageConstants"
      end

      def qualified_message_constants_name
        "#{encoder_package}.#{message_constants_name}"
      end

      def message_generator_name
        "#{repository.name}EntityMessageGenerator"
      end

      def qualified_message_generator_name
        "#{encoder_package}.#{message_generator_name}"
      end

      def graph_encoder_name
        "#{repository.name}GraphEncoder"
      end

      def qualified_graph_encoder_name
        "#{encoder_package}.#{graph_encoder_name}"
      end

      def change_recorder_name
        "#{repository.name}ChangeRecorder"
      end

      def qualified_change_recorder_name
        "#{encoder_package}.#{change_recorder_name}"
      end

      def replication_interceptor_name
        "#{repository.name}ReplicationInterceptor"
      end

      def qualified_replication_interceptor_name
        "#{encoder_package}.#{replication_interceptor_name}"
      end

      def graph_encoder_impl_name
        "#{repository.name}GraphEncoderImpl"
      end

      def qualified_graph_encoder_impl_name
        "#{encoder_package}.#{graph_encoder_impl_name}"
      end

      attr_writer :services_module_name

      def services_module_name
        @services_module_name || "#{repository.name}ImitServicesModule"
      end

      def qualified_services_module_name
        "#{ioc_package}.#{services_module_name}"
      end

      attr_writer :mock_services_module_name

      def mock_services_module_name
        @mock_services_module_name || "#{repository.name}MockImitServicesModule"
      end

      def qualified_mock_services_module_name
        "#{ioc_package}.#{mock_services_module_name}"
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
      end
    end
  end

  FacetManager.define_facet(:imit,
                            {
                              Attribute => Domgen::Imit::ImitationAttribute,
                              InverseElement => Domgen::Imit::ImitationAttributeInverse,
                              Entity => Domgen::Imit::ImitationEntity,
                              Method => Domgen::Imit::ImitationMethod,
                              Result => Domgen::Imit::ImitationResult,
                              Parameter => Domgen::Imit::ImitationParameter,
                              Exception => Domgen::Imit::ImitationException,
                              Service => Domgen::Imit::ImitationService,
                              DataModule => Domgen::Imit::ImitationModule,
                              Repository => Domgen::Imit::ImitationApplication
                            },
                            [:gwt_rpc])
end
