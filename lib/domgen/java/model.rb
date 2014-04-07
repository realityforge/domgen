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

Domgen::TypeDB.config_element(:java) do
  attr_writer :primitive_type

  def primitive_type?
    !!@primitive_type
  end

  def primitive_type
    raise "#{root.name} is not a primitive type" unless @primitive_type
    @primitive_type
  end

  attr_writer :object_type

  def object_type
    raise "#{root.name} is not a simple object type" unless @object_type
    @object_type
  end
end

Domgen::TypeDB.config_element(:"java.imit") do
  def primitive_type?
    root.java.primitive_type?
  end

  def primitive_type
    root.java.primitive_type
  end

  attr_writer :object_type

  def object_type
    @object_type || root.java.object_type
  end
end

Domgen::TypeDB.enhance(:void, 'java.primitive_type' => 'void', 'java.object_type' => 'java.lang.Void')
Domgen::TypeDB.enhance(:integer, 'java.primitive_type' => 'int', 'java.object_type' => 'java.lang.Integer')
Domgen::TypeDB.enhance(:real, 'java.primitive_type' => 'float', 'java.object_type' => 'java.lang.Float')
Domgen::TypeDB.enhance(:date, 'java.object_type' => 'java.util.Date', 'java.imit.object_type' => 'org.realityforge.gwt.datatypes.client.date.RDate')
Domgen::TypeDB.enhance(:datetime, 'java.object_type' => 'java.util.Date')
Domgen::TypeDB.enhance(:boolean, 'java.primitive_type' => 'boolean', 'java.object_type' => 'java.lang.Boolean')
Domgen::TypeDB.enhance(:text, 'java.object_type' => 'java.lang.String')

Domgen::TypeDB.enhance(:point, 'java.object_type' => 'org.geolatte.geom.Point')
Domgen::TypeDB.enhance(:multipoint, 'java.object_type' => 'org.geolatte.geom.MultiPoint')
Domgen::TypeDB.enhance(:linestring, 'java.object_type' => 'org.geolatte.geom.LineString')
Domgen::TypeDB.enhance(:multilinestring, 'java.object_type' => 'org.geolatte.geom.MultiLineString')
Domgen::TypeDB.enhance(:polygon, 'java.object_type' => 'org.geolatte.geom.Polygon')
Domgen::TypeDB.enhance(:multipolygon, 'java.object_type' => 'org.geolatte.geom.MultiPolygon')
Domgen::TypeDB.enhance(:geometry, 'java.object_type' => 'org.geolatte.geom.Geometry')
Domgen::TypeDB.enhance(:pointm, 'java.object_type' => 'org.geolatte.geom.Point')
Domgen::TypeDB.enhance(:multipointm, 'java.object_type' => 'org.geolatte.geom.MultiPoint')
Domgen::TypeDB.enhance(:linestringm, 'java.object_type' => 'org.geolatte.geom.LineString')
Domgen::TypeDB.enhance(:multilinestringm, 'java.object_type' => 'org.geolatte.geom.MultiLineString')
Domgen::TypeDB.enhance(:polygonm, 'java.object_type' => 'org.geolatte.geom.Polygon')
Domgen::TypeDB.enhance(:multipolygonm, 'java.object_type' => 'org.geolatte.geom.MultiPolygon')

module Domgen
  module Java
    class << self

      def primitive_java_type(characteristic, group_type, modality = :default)
        check_modality(modality)
        if (:boundary == modality || :transport == modality) && characteristic.reference?
          return primitive_java_type(characteristic.referenced_entity.primary_key, group_type, modality)
        elsif :transport == modality && characteristic.enumeration? && characteristic.enumeration.numeric_values?
          return Domgen::TypeDB.characteristic_type_by_name(:integer).java.primitive_type
        else
          characteristic_type = characteristic.characteristic_type
          if characteristic_type
            return characteristic.characteristic_type.java.primitive_type
          else
            Domgen.error("#{characteristic.name} is not a primitive type yet primitive_java_type invoked")
          end
        end
      end

      def primitive?(characteristic, group_type, modality = :default)
        check_modality(modality)
        return false if characteristic.collection?
        return false if characteristic.nullable?
        return false if (characteristic.respond_to?(:generated_value?) && characteristic.generated_value?)
        return true if :transport == modality && characteristic.enumeration? && characteristic.enumeration.numeric_values?

        characteristic_type = characteristic.characteristic_type
        return true if characteristic_type && characteristic.characteristic_type.java.primitive_type?

        return false unless characteristic.reference? && :default != modality

        return primitive?(characteristic.referenced_entity.primary_key, group_type, modality)
      end

      def java_component_type(characteristic, group_type, modality = :default)
        check_modality(modality)
        characteristic_group = group_type(group_type)

        if characteristic.reference?
          if :default == modality
            return characteristic.referenced_entity.send(characteristic_group.entity_key).qualified_name
          else #if :boundary == modality || :transport == modality
            return characteristic.referenced_entity.primary_key.send(characteristic_group.entity_key).non_primitive_java_type(modality)
          end
        elsif characteristic.enumeration?
          if :default == modality || :boundary == modality
            return characteristic.enumeration.send(characteristic_group.enumeration_key).qualified_name
          else #if :transport == modality
            if characteristic.enumeration.textual_values?
              return Domgen::TypeDB.characteristic_type_by_name(:text).java.object_type
            else
              return Domgen::TypeDB.characteristic_type_by_name(:integer).java.object_type
            end
          end
        elsif characteristic.struct?
          if :default == modality || :boundary == modality
            return characteristic.referenced_struct.send(characteristic_group.struct_key).qualified_name
          else #if :transport == modality
            return Domgen::TypeDB.characteristic_type_by_name(:text).java.object_type
          end
        elsif characteristic.geometry?
          return Domgen::TypeDB.characteristic_type_by_name(characteristic.geometry.geometry_type).java.object_type
        elsif characteristic.date? && group_type == :imit
          # TODO: Fix Hackity hack
          return characteristic.characteristic_type.java.imit.object_type
        else
          characteristic_type = characteristic.characteristic_type
          if characteristic_type
            return characteristic_type.java.object_type
          else
            return characteristic.characteristic_type_key.to_s
          end
        end
      end

      def java_type(characteristic, group_type, modality = :default)
        if primitive?(characteristic, group_type, modality)
          return primitive_java_type(characteristic, group_type, modality)
        else
          non_primitive_java_type(characteristic, group_type, modality)
        end
      end

      def non_primitive_java_type(characteristic, group_type, modality = :default)
        component_type = java_component_type(characteristic, group_type, modality)
        if :none == characteristic.collection_type
          component_type
        elsif :sequence == characteristic.collection_type
          sequence_type(component_type)
        else #if :set == characteristic.collection_type
          set_type(component_type)
        end
      end

      def transport_characteristic_type_key(characteristic)
        return characteristic.reference? ?
          characteristic.referenced_entity.primary_key.characteristic_type_key :
          characteristic.characteristic_type_key
      end

      protected

      def sequence_type(component_type)
        "java.util.List<#{component_type}>"
      end

      def set_type(component_type)
        "java.util.Set<#{component_type}>"
      end

      GroupType = ::Struct.new("GroupType", :entity_key, :enumeration_key, :struct_key)

      GROUP_TYPE_MAP = {
        :ee => GroupType.new(:jpa, :ee, :ee),
        :imit => GroupType.new(:imit, :gwt, :gwt)
      }

      MODALITIES = [:default, :boundary, :transport]

      def group_type(group_type)
        check_group_type(group_type)
        GROUP_TYPE_MAP[group_type]
      end

      def check_group_type(group_type)
        raise "Unknown group_type #{group_type}" unless GROUP_TYPE_MAP[group_type]
      end

      def check_modality(modality)
        raise "Unknown modality #{modality}" unless MODALITIES.include?(modality)
      end
    end

    module JavaCharacteristic
      def name(modality = :default)
        return characteristic.referencing_link_name if characteristic.reference? && (:boundary == modality || :transport == modality)
        return characteristic.name
      end

      def java_type(modality = :default)
        Domgen::Java.java_type(characteristic, group_type, modality)
      end

      def java_component_type(modality = :default)
        Domgen::Java.java_component_type(characteristic, group_type, modality)
      end

      def non_primitive_java_type(modality = :default)
        Domgen::Java.non_primitive_java_type(characteristic, group_type, modality)
      end

      def primitive?(modality = :default)
        Domgen::Java.primitive?(characteristic, group_type, modality)
      end

      def primitive_java_type(modality = :default)
        Domgen::Java.primitive_java_type(characteristic, group_type, modality)
      end

      def transport_characteristic_type_key
        Domgen::Java.transport_characteristic_type_key(characteristic)
      end

      protected

      def characteristic
        raise "characteristic unimplemented"
      end
    end

    module EEJavaCharacteristic
      include JavaCharacteristic

      protected

      def group_type
        :ee
      end
    end

    module ImitJavaCharacteristic
      include JavaCharacteristic

      protected

      def group_type
        :imit
      end
    end

    module BaseDefiner
      def self.included(base)
        class << base
          def idefine_method(*args, &block)
            raise "Method #{args[0]} already defined" if method_defined?(args[0])
            define_method(*args, &block)
          end

          def idefine_setter(key)
            idefine_method("#{key}=") do |value|
              instance_variable_set("@#{key}", value)
            end
          end

          def idefine_getter(key, default_value)
            idefine_method(key) do
              instance_variable_get("@#{key}") || (default_value.is_a?(Proc) ? instance_eval(&default_value) : eval("\"#{default_value}\"", binding, key))
            end
          end
        end
      end
    end

    module BaseJavaPackage
      protected

      def self.included(base)
        base.send :include, BaseDefiner
        class << base
          def java_package(package_key, options = {})
            scope = options[:scope]
            sub_packages = options[:sub_packages] || []
            raise "Sub-packages #{sub_packages.inspect} expected to be an array" unless sub_packages.is_a?(Array)

            key = scope.nil? ? :"#{package_key}_package" : "#{scope}_#{package_key}_package"
            idefine_getter(key, Proc.new {self.resolve_package(key)})
            idefine_setter(key)
            sub_packages.each do |sub_package|
              sub_package_ruby_name = sub_package.split('.').reverse.join('_')
              sub_package_key = scope.nil? ? :"#{sub_package_ruby_name}_#{package_key}_package" : "#{scope}_#{sub_package_ruby_name}_#{package_key}_package"
              idefine_getter(sub_package_key, Proc.new { "#{self.send(key)}.#{sub_package}" })
            end
          end

          def standard_java_packages(scope)
            java_package :data_type, :scope => scope
            java_package :entity, :scope => scope
            java_package :service, :scope => scope, :sub_packages => ['internal']
          end
        end
      end

      def resolve_package(package_type, facet = parent_facet)
        (data_module.name == data_module.repository.name) ? facet.send(package_type) : "#{facet.send(package_type)}.#{package_key}"
      end

      def facet_key
        raise "facet_key unimplemented"
      end

      def parent_facet
        data_module.repository.send(facet_key)
      end

      def package_key
        Domgen::Naming.underscore(data_module.name)
      end
    end

    module JavaPackage
      include BaseJavaPackage

      standard_java_packages(nil)
    end

    module ClientServerJavaPackage
      include BaseJavaPackage

      standard_java_packages(:shared)
      standard_java_packages(:client)
      standard_java_packages(:server)
    end

    module EEClientServerJavaPackage
      include ClientServerJavaPackage

      protected

      def facet_key
        :ee
      end
    end

    module ImitJavaPackage
      include ClientServerJavaPackage

      protected

      def facet_key
        :imit
      end
    end

    module BaseJavaApplication
      def self.included(base)
        base.send :include, BaseDefiner
        class << base
          def java_package(package_key, options = {})
            scope = options[:scope]
            sub_packages = options[:sub_packages] || []
            raise "Sub-packages #{sub_packages.inspect} expected to be an array" unless sub_packages.is_a?(Array)

            key = scope.nil? ? "#{package_key}_package" : "#{scope}_#{package_key}_package"
            scope_package = scope.nil? ? 'package' : "#{scope}_package"
            idefine_getter(key, Proc.new {"#{self.send(scope_package)}.#{package_key}"})
            idefine_setter(key)
            sub_packages.each do |sub_package|
              sub_package_ruby_name = sub_package.split('.').reverse.join('_')
              sub_package_key = scope.nil? ? :"#{sub_package_ruby_name}_#{package_key}_package" : "#{scope}_#{sub_package_ruby_name}_#{package_key}_package"
              idefine_getter(sub_package_key, Proc.new { "#{self.send(key)}.#{sub_package}" })
            end
          end

          def standard_java_packages(scope)
            java_package :data_type, :scope => scope
            java_package :entity, :scope => scope
            java_package :service, :scope => scope, :sub_packages => ['internal']
          end

          def context_package(scope)
            scope_package = "#{scope}_package"
            idefine_setter(scope_package)
            idefine_getter(scope_package, Proc.new { "#{self.send(:package)}.#{scope}" })
          end
        end
      end

      protected

      def base_package
        repository.java.base_package
      end

      attr_writer :package

      def package
        @package || (default_package_root ? "#{base_package}.#{default_package_root}" : base_package)
      end

      def default_package_root
        nil
      end
    end

    module JavaApplication
      include BaseJavaApplication

      standard_java_packages(nil)
    end

    module JavaClientServerApplication
      include BaseJavaApplication

      context_package(:shared)
      standard_java_packages(:shared)
      context_package(:client)
      standard_java_packages(:client)
      context_package(:server)
      standard_java_packages(:server)
    end

    class Application < Domgen.ParentedElement(:repository)
      attr_writer :base_package

      def base_package
        @base_package || Domgen::Naming.underscore(repository.name)
      end
    end
  end

  FacetManager.define_facet(:java,
                            {Repository => Domgen::Java::Application},
                            [])
end
