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

  attr_writer :fixture_value

  def fixture_value
    raise "#{root.name} has no fixture value" unless @fixture_value
    @fixture_value
  end
end

Domgen::TypeDB.config_element('java.gwt') do
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

  attr_writer :fixture_value

  def fixture_value
    @fixture_value || root.java.fixture_value
  end
end

Domgen::TypeDB.enhance(:void, 'java.primitive_type' => 'void', 'java.object_type' => 'java.lang.Void')
Domgen::TypeDB.enhance(:integer, 'java.primitive_type' => 'int', 'java.object_type' => 'java.lang.Integer', 'java.fixture_value' => '42')
Domgen::TypeDB.enhance(:long, 'java.primitive_type' => 'long', 'java.object_type' => 'java.lang.Long', 'java.fixture_value' => '42L')
Domgen::TypeDB.enhance(:real, 'java.primitive_type' => 'float', 'java.object_type' => 'java.lang.Float', 'java.fixture_value' => '3.14F')
Domgen::TypeDB.enhance(:date, 'java.object_type' => 'java.util.Date', 'java.fixture_value' => 'new java.util.Date(114, 3, 1)', 'java.gwt.fixture_value' => 'new iris.rose.shared.util.RDate(2014, 3, 1)')
Domgen::TypeDB.enhance(:datetime, 'java.object_type' => 'java.util.Date', 'java.fixture_value' => 'new java.util.Date(114, 14, 3, 10, 9)')
Domgen::TypeDB.enhance(:boolean, 'java.primitive_type' => 'boolean', 'java.object_type' => 'java.lang.Boolean', 'java.fixture_value' => 'true')
Domgen::TypeDB.enhance(:text, 'java.object_type' => 'java.lang.String', 'java.fixture_value' => '"Hello Space!"')

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

      def primitive?(characteristic, group_type, modality = :default, options = {})
        check_modality(modality)
        return false if characteristic.collection?
        return false if characteristic.nullable?
        return false if !options[:assume_generated] && (characteristic.respond_to?(:generated_value?) && characteristic.generated_value?)
        return true if :transport == modality && characteristic.enumeration? && characteristic.enumeration.numeric_values?

        characteristic_type = characteristic.characteristic_type
        return true if characteristic_type && characteristic.characteristic_type.java.primitive_type?

        return false unless characteristic.reference?
        return false if :default == modality

        return primitive?(characteristic.referenced_entity.primary_key, group_type, modality, options)
      end

      def java_component_type(characteristic, group_type, modality = :default, options = {})
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
              data_type = Domgen::TypeDB.characteristic_type_by_name(:integer)
              return characteristic.nullable? || options[:non_primitive_value] ? data_type.java.object_type : data_type.java.primitive_type
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
        elsif characteristic.date?
          if :default == modality || :boundary == modality
            # TODO: Fix Hackity hack
            if group_type == :gwt
              return characteristic.characteristic_container.data_module.repository.gwt.qualified_rdate_name
            else
              return characteristic.characteristic_type.java.object_type
            end
          else #if :transport == modality
            return Domgen::TypeDB.characteristic_type_by_name(:text).java.object_type
          end
        else
          characteristic_type = characteristic.characteristic_type
          if characteristic_type
            return characteristic_type.java.object_type
          else
            return characteristic.characteristic_type_key.to_s
          end
        end
      end

      def java_component_fixture_value(characteristic, group_type, modality = :default)
        check_modality(modality)
        characteristic_group = group_type(group_type)

        if characteristic.reference?
          if :default == modality
            raise 'Unable to create fixture data for reference in default modality'
          else #if :boundary == modality || :transport == modality
            other = characteristic.referenced_entity.primary_key.facet(characteristic_group.entity_key)
            return java_fixture_value(other, group_type, modality)
          end
        elsif characteristic.enumeration?
          if :default == modality || :boundary == modality
            return "#{characteristic.enumeration.facet(characteristic_group.enumeration_key).qualified_name}.#{characteristic.enumeration.values[0]}"
          else #if :transport == modality
            if characteristic.enumeration.textual_values?
              return "\"#{characteristic.enumeration.values[0].name}\""
            else
              return '0'
            end
          end
        elsif characteristic.struct?
          if :default == modality || :boundary == modality
            return "new #{characteristic.referenced_struct.send(characteristic_group.struct_key).qualified_name}(#{characteristic.referenced_struct.fields.collect { |p| java_fixture_value(p) }.join(', ')})"
          else #if :transport == modality
            raise 'Unable to determine fixture type for transport struct type'
          end
        elsif characteristic.geometry?
          return Domgen::TypeDB.characteristic_type_by_name(characteristic.geometry.geometry_type).java.fixture_value
        elsif characteristic.date? && group_type == :gwt
          # TODO: Fix Hackity hack
          return characteristic.characteristic_type.java.gwt.fixture_value
        else
          characteristic_type = characteristic.characteristic_type
          if characteristic_type
            return characteristic_type.java.fixture_value
          end
          return nil
        end
      end

      def java_fixture_value(characteristic, group_type, modality = :default)
        if primitive?(characteristic, group_type, modality)
          return java_component_fixture_value(characteristic, group_type, modality)
        else
          non_primitive_fixture_value(characteristic, group_type, modality)
        end
      end

      def non_primitive_fixture_value(characteristic, group_type, modality = :default)
        component_type = java_component_fixture_value(characteristic, group_type, modality)
        if :none == characteristic.collection_type
          component_type
        elsif :sequence == characteristic.collection_type
          "java.util.Collections.singletonList( #{component_type} )"
        else #if :set == characteristic.collection_type
          "new java.util.HashSet<>( java.util.Collections.singletonList( #{component_type} ) )"
          set_type(component_type)
        end
      end

      def java_type(characteristic, group_type, modality = :default, options = {})
        if primitive?(characteristic, group_type, modality, options)
          return primitive_java_type(characteristic, group_type, modality)
        else
          non_primitive_java_type(characteristic, group_type, modality)
        end
      end

      def non_primitive_java_type(characteristic, group_type, modality = :default)
        if :none == characteristic.collection_type
          java_component_type(characteristic, group_type, modality)
        elsif :sequence == characteristic.collection_type
          sequence_type(java_component_type(characteristic, group_type, modality, :non_primitive_value => true))
        else #if :set == characteristic.collection_type
          set_type(java_component_type(characteristic, group_type, modality, :non_primitive_value => true))
        end
      end

      def transport_characteristic_type_key(characteristic)
        if characteristic.reference?
          characteristic.referenced_entity.primary_key.characteristic_type_key
        else
          characteristic.characteristic_type_key
        end
      end

      protected

      def sequence_type(component_type)
        "java.util.List<#{component_type}>"
      end

      def set_type(component_type)
        "java.util.Set<#{component_type}>"
      end

      GroupType = ::Struct.new('GroupType', :entity_key, :enumeration_key, :struct_key)

      GROUP_TYPE_MAP = {
        :ee => GroupType.new(:jpa, :ee, :ee),
        :gwt => GroupType.new(:arez, :ce, :gwt)
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

      def java_type(modality = :default, options = {})
        Domgen::Java.java_type(characteristic, group_type, modality, options)
      end

      def java_component_type(modality = :default)
        Domgen::Java.java_component_type(characteristic, group_type, modality)
      end

      def non_primitive_java_type(modality = :default)
        Domgen::Java.non_primitive_java_type(characteristic, group_type, modality)
      end

      def primitive?(modality = :default, options = {})
        Domgen::Java.primitive?(characteristic, group_type, modality, options)
      end

      def primitive_java_type(modality = :default)
        Domgen::Java.primitive_java_type(characteristic, group_type, modality)
      end

      def java_fixture_value(modality = :default)
        Domgen::Java.java_fixture_value(characteristic, group_type, modality)
      end

      def transport_characteristic_type_key
        Domgen::Java.transport_characteristic_type_key(characteristic)
      end

      protected

      def characteristic
        raise 'characteristic unimplemented'
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
        :gwt
      end
    end

    module BaseDefiner
      def self.included(base)
        class << base
          def idefine_method(*args, &block)
            @defined_methods ||= []
            raise "Method #{args[0]} already defined" if @defined_methods.include?(args[0])
            @defined_methods << args[0]
            define_method(*args, &block)
          end

          def idefine_setter(key)
            idefine_method("#{key}=") do |value|
              instance_variable_set("@#{key}", value)
            end
          end

          def idefine_getter(key, default_value, options = {})
            customizable = options[:customizable].nil? ? true : !!options[:customizable]
            idefine_method(key) do
              (customizable ? instance_variable_get("@#{key}") : nil) ||
                (default_value.is_a?(Proc) ?
                  instance_eval(&default_value) :
                  eval("\"#{default_value}\"", binding, key))
            end
          end
        end
      end
    end

    module BaseJavaPackage
      protected

      def self.included(base)
        base.send :include, BaseDefiner
        base.send :extend, ClassMethods
      end

      module ClassMethods
        def java_package(package_key, options = {})
          scope = options[:scope]
          sub_packages = options[:sub_packages] || []
          raise "Sub-packages #{sub_packages.inspect} expected to be an array" unless sub_packages.is_a?(Array)

          key = scope.nil? ? :"#{package_key}_package" : "#{scope}_#{package_key}_package"
          idefine_getter(key, Proc.new { self.resolve_package(key, parent_facet) })
          idefine_setter(key)
          sub_packages.each do |sub_package|
            sub_package_ruby_name = sub_package.split('.').reverse.join('_')
            sub_package_key = scope.nil? ? :"#{sub_package_ruby_name}_#{package_key}_package" : "#{scope}_#{sub_package_ruby_name}_#{package_key}_package"
            idefine_getter(sub_package_key, Proc.new { "#{self.send(key)}.#{sub_package}" })
            idefine_setter(sub_package_key)
          end
        end

        def standard_java_packages(scopes)
          scopes = scopes.is_a?(Array) ? scopes : [scopes]
          scopes.each do |scope|
            java_package :data_type, :scope => scope, :sub_packages => %w(internal)
            java_package :entity, :scope => scope, :sub_packages => %w(internal dao dao.internal)
            java_package :service, :scope => scope, :sub_packages => %w(internal)
            java_package :rest, :scope => scope, :sub_packages => %w(internal)
            java_package :filter, :scope => scope, :sub_packages => %w(internal)
            java_package :servlet, :scope => scope, :sub_packages => %w(internal)
            java_package :test, :scope => scope, :sub_packages => %w(util)
          end
        end
      end

      def resolve_package(package_type, facet = parent_facet)
        (data_module.name == data_module.repository.name) ? facet.send(package_type) : "#{facet.send(package_type)}.#{package_key}"
      end

      def facet_key
        raise 'facet_key unimplemented'
      end

      def parent_facet
        return nil unless parent.respond_to?(:parent, true)
        parent.send(:parent).facet(self.facet_key)
      end

      def package_key
        Reality::Naming.underscore(data_module.name)
      end
    end

    module BaseJavaGenerator
      def self.included(base)
        base.send :include, BaseDefiner
        class << base
          def java_artifact(key, artifact_type, scope, facet_key, default_value, options = {})
            method_name = :name == key ? 'name' : "#{key}_name"
            sub_package = options[:sub_package]
            sub_package_prefix = options[:sub_package] ? "#{sub_package.split('.').reverse.join('_')}_" : ''
            package_key_suffix = "#{sub_package_prefix}#{artifact_type.nil? ? '' : "#{artifact_type}_"}package"
            idefine_getter(method_name, default_value)
            idefine_method("qualified_#{method_name}=") do |value|
              instance_variable_set("@qualified_#{method_name}", value)
            end
            idefine_method("qualified_#{method_name}") do
              qualified_name = instance_variable_get("@qualified_#{method_name}")
              return qualified_name if qualified_name
              facet_parent = parent
              while !facet_parent.is_a?(DataModule) && !facet_parent.is_a?(Repository)
                facet_parent = facet_parent.parent
              end
              package_key = "#{scope.nil? ? '' : "#{scope}_"}#{package_key_suffix}"
              "#{facet_parent.facet(facet_key).send(package_key)}.#{send(method_name)}"
            end
          end
        end
      end
    end

    module ClientServerJavaPackage
      include BaseJavaPackage

      java_package :message, :scope => :integration
      java_package :api, :scope => :integration
      java_package :rest, :scope => :integration
      java_package :test, :scope => :integration, :sub_packages => ['util']
      standard_java_packages([:shared, :client, :server])
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
        :gwt
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
            idefine_getter(key, Proc.new { "#{self.send(scope_package)}.#{package_key}" })
            idefine_setter(key)
            sub_packages.each do |sub_package|
              sub_package_ruby_name = sub_package.split('.').reverse.join('_')
              sub_package_key = scope.nil? ? :"#{sub_package_ruby_name}_#{package_key}_package" : "#{scope}_#{sub_package_ruby_name}_#{package_key}_package"
              idefine_getter(sub_package_key, Proc.new { "#{self.send(key)}.#{sub_package}" })
            end
          end

          def standard_java_packages(scopes)
            scopes = scopes.is_a?(Array) ? scopes : [scopes]
            scopes.each do |scope|
              java_package :data_type, :scope => scope, :sub_packages => ['internal']
              java_package :entity, :scope => scope, :sub_packages => ['internal']
              java_package :event, :scope => scope
              java_package :service, :scope => scope, :sub_packages => ['internal']
              java_package :rest, :scope => scope, :sub_packages => ['internal']
              java_package :filter, :scope => scope, :sub_packages => ['internal']
              java_package :servlet, :scope => scope, :sub_packages => ['internal']
              java_package :test, :scope => scope, :sub_packages => ['util']
            end
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
      context_package(:client)
      context_package(:server)
      context_package(:integration)
      java_package :message, :scope => :integration
      java_package :api, :scope => :integration
      java_package :rest, :scope => :integration
      java_package :test, :scope => :integration, :sub_packages => ['util']
      standard_java_packages([:shared, :client, :server])
    end
  end

  FacetManager.facet(:java) do |facet|
    facet.enhance(Repository) do
      attr_writer :generate_package_info

      def generate_package_info?
        @generate_package_info.nil? ? false : !!@generate_package_info
      end

      attr_writer :base_package

      def base_package
        @base_package || Reality::Naming.underscore(repository.name)
      end

      def pre_complete
        if repository.ee?

          spatial_types = [:point, :multipoint, :linestring, :multilinestring, :polygon, :multipolygon, :geometry, :pointm, :multipointm, :linestringm, :multilinestringm, :polygonm, :multipolygonm]
          has_spatial_attributes =
            repository.data_modules.any? do |data_module|
              data_module.entities.any? do |entity|
                entity.attributes.any? do |attribute|
                  spatial_types.include?(attribute.attribute_type)
                end
              end
            end
          if has_spatial_attributes
            # Just in case some attributes use spatial types
            repository.ee.cdi_scan_excludes << 'org.realityforge.jeo.geolatte.**'
            repository.ee.cdi_scan_excludes << 'org.geolatte.**'
            repository.ee.cdi_scan_excludes << 'com.vividsolutions.**'
          end
        end
      end
    end

    facet.enhance(Exception) do
      def runtime?
        :runtime == exception_category
      end

      def normal?
        :normal == exception_category
      end

      def error?
        :error == exception_category
      end

      def standard_extends
        runtime? ? 'java.lang.RuntimeException' : normal? ? 'java.lang.Exception' : 'java.lang.Error'
      end

      def exception_category
        @exception_category || :normal
      end

      def exception_category=(exception_category)
        raise "Invalid exception category #{exception_category}" unless valid_exception_categories.include?(exception_category)
        @exception_category = exception_category
      end

      def valid_exception_categories
        [:normal, :runtime, :error]
      end
    end
  end
end
