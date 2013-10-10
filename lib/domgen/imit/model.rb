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
    end

    class ImitationAttribute < Domgen.ParentedElement(:attribute)

      attr_writer :client_side

      def client_side?
        @client_side.nil? ? (attribute.entity.imit? && (!attribute.reference? || attribute.referenced_entity.imit?) ) : @client_side
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
      attr_writer :client_side

      def client_side?
        @client_side.nil? ? service.data_module.imit? : @client_side
      end

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

      attr_accessor :transport_id

      def name
        entity.name
      end

      def qualified_name
        "#{entity.data_module.imit.entity_package}.#{name}"
      end

      attr_writer :client_side

      def client_side?
        @client_side.nil? ? entity.data_module.imit? : @client_side
      end

      def referencing_client_side_attributes
        entity.referencing_attributes.select do |attribute|
          attribute.entity.imit? &&
            attribute.inverse.imit? &&
            attribute.inverse.imit.traversable? &&
            entity == attribute.referenced_entity &&
            attribute.imit? &&
            attribute.imit.client_side? &&
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

      def jpa_encoder_name
        "#{data_module.name}JpaEncoder"
      end

      def qualified_jpa_encoder_name
        "#{encoder_package}.#{jpa_encoder_name}"
      end

      def router_interface_name
        "#{data_module.name}Router"
      end

      def qualified_router_interface_name
        "#{encoder_package}.#{router_interface_name}"
      end

      def updater_name
        "#{data_module.name}Updater"
      end

      def qualified_updater_name
        "#{entity_package}.#{updater_name}"
      end

      attr_writer :client_side

      def client_side?
        @client_side.nil? ? !@entity_package.nil? : @client_side
      end

      def client_side_entities
        data_module.entities.select { |entity| entity.imit?  }
      end

      def concrete_client_side_entities
        client_side_entities.select{|entity| !entity.abstract?}
      end
    end

    class ImitationApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::ClientJavaApplication

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

      def message_generator_name
        "#{repository.name}EntityMessageGenerator"
      end

      def qualified_message_generator_name
        "#{encoder_package}.#{message_generator_name}"
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

      def client_side_data_modules
        repository.data_modules.select{|data_module| data_module.imit? }
      end

      def client_side_entities
        client_side_data_modules.collect{ |data_module| data_module.imit.client_side_entities }.flatten
      end

      def concrete_client_side_entities
        client_side_entities.select{|entity| !entity.abstract?}
      end

      def post_verify
        concrete_client_side_entities.each_with_index {|entity, index| entity.imit.transport_id = index}
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
