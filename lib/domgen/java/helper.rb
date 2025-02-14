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
  module Java
    module Helper

      def to_package(classname)
        classname.gsub(/^(.*)\.[^.]+$/,'\1')
      end

      def nullability_annotation(is_nullable)
        is_nullable ? '@javax.annotation.Nullable' : '@javax.annotation.Nonnull'
      end

      def supports_nullable?(extension, modality = :default, options = {})
        !(extension.primitive?(modality, options) || extension.java_type(modality, options).to_s == 'void')
      end

      def annotated_type(characteristic, facet_key, modality = :default, options = {})
        final_qualifier = options[:final] ? 'final ' : ''
        public_qualifier = options[:public] ? 'public ' : ''
        private_qualifier = options[:private] ? 'private ' : ''
        protected_qualifier = options[:protected] ? 'protected ' : ''
        abstract_qualifier = options[:abstract] ? 'abstract ' : ''
        native_qualifier = options[:native] ? 'native ' : ''
        static_qualifier = options[:static] ? 'static ' : ''
        nullable = (options[:nullable].nil? ? characteristic.nullable? : options[:nullable]) || (options[:nonnull_requires_immutable] ? !characteristic.immutable? : false)
        extension = characteristic.facet(facet_key)
        nullability_prefix = (supports_nullable?(extension, modality, options)) ? "#{nullability_annotation(nullable)} " : ''
        type = options[:non_primitive] ? extension.non_primitive_java_type(modality) : extension.java_type(modality, options)
        "#{nullability_prefix}#{public_qualifier}#{protected_qualifier}#{private_qualifier}#{static_qualifier}#{abstract_qualifier}#{final_qualifier}#{native_qualifier}#{type}"
      end

      def javabean_property_name(key)
        name = key.to_s
        return name if name == name.upcase
        "#{name[0,1].downcase}#{name[1,name.length]}"
      end

      def getter_prefix(attribute)
        attribute.boolean? && !attribute.nullable? ? 'is' : 'get'
      end

      def getter_for( attribute, name = nil )
        name = attribute.name unless name
        "#{getter_prefix(attribute)}#{name}()"
      end

      def modality_default_to_transport(variable_name, characteristic, characteristic_key)
        extension = characteristic.send(characteristic_key)

        return variable_name if extension.java_type == extension.java_type(:boundary)

        transform = variable_name
        if characteristic.characteristic_type_key == :enumeration
          if characteristic.enumeration.numeric_values?
            transform = "#{variable_name}.ordinal()"
          else
            transform = "#{variable_name}.name()"
          end
        elsif characteristic.characteristic_type_key == :reference
          transform = "#{variable_name}.get#{characteristic.referenced_entity.primary_key.name}()"
        end
        if characteristic.nullable?
          transform = "null == #{variable_name} ? null : #{transform}"
        end
        transform
      end

      def modality_boundary_to_default(variable_name, characteristic, characteristic_key)
        extension = characteristic.send(characteristic_key)

        return variable_name if extension.java_type == extension.java_type(:boundary)
        return "$#{variable_name}" if characteristic.reference? && characteristic.collection?

        transform = variable_name
        if characteristic.characteristic_type_key == :reference
          transform = "_#{Reality::Naming.camelize(characteristic.referenced_entity.dao.jpa.dao_service_name)}.getBy#{characteristic.referenced_entity.primary_key.name}( #{variable_name} )"
        end
        if characteristic.nullable? && transform != variable_name
          transform = "(null == #{variable_name} ? null : #{transform})"
        end
        transform
      end

      def j_escape_string( str )
        str.gsub('"', '\"')
      end
    end
  end
end
