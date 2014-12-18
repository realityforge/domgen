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

  module Characteristic
    attr_reader :name

    def allows_length?
      text? || (enumeration? && enumeration.textual_values?) || (reference? && referenced_entity.primary_key.allows_length?)
    end

    attr_reader :length

    def length=(length)
      Domgen.error("length on #{name} of type '#{characteristic_type_key}' is invalid as #{characteristic_container.characteristic_kind} is not string-ish") unless allows_length?
      @length = length
    end

    def has_non_max_length?
      !@length.nil? && @length != :max
    end

    def min_length
      return @min_length if @min_length
      allow_blank? ? 0 : 1
    end

    def min_length=(length)
      Domgen.error("min_length on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a string") unless allows_length?
      @min_length = length
    end

    attr_writer :allow_blank

    def allow_blank?
      @allow_blank.nil? ? true : @allow_blank
    end

    attr_writer :nullable

    def nullable?
      @nullable.nil? ? false : @nullable
    end

    attr_reader :enumeration

    def enumeration=(enumeration)
      Domgen.error("enumeration on #{name} is invalid as #{characteristic_container.characteristic_kind} is not an enumeration") unless enumeration?
      @enumeration = enumeration
    end

    def enumeration?
      characteristic_type_key == :enumeration
    end

    def text?
      characteristic_type_key == :text
    end

    def reference?
      self.characteristic_type_key == :reference
    end

    def integer?
      self.characteristic_type_key == :integer
    end

    def long?
      self.characteristic_type_key == :long
    end

    def real?
      self.characteristic_type_key == :real
    end

    def boolean?
      self.characteristic_type_key == :boolean
    end

    def datetime?
      self.characteristic_type_key == :datetime
    end

    def date?
      self.characteristic_type_key == :date
    end

    def struct?
      self.characteristic_type_key == :struct
    end

    def geometry?
      self.characteristic_type_key == :geometry
    end

    def characteristic_type
      Domgen::TypeDB.characteristic_type?(self.characteristic_type_key) ?
        Domgen::TypeDB.characteristic_type_by_name(self.characteristic_type_key) :
        nil
    end

    def collection?
      self.collection_type != :none
    end

    def collection_type
      @collection_type || :none
    end

    def collection_type=(collection_type)
      Domgen.error("collection_type #{collection_type} is invalid") unless [:none, :sequence, :set].include?(collection_type)
      @collection_type = collection_type
    end

    def referenced_struct
      Domgen.error("referenced_struct on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a struct") unless struct?
      @referenced_struct
    end

    def geometry
      Domgen.error("geometry on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a geometry") unless geometry?
      @geometry ||= Geometry.new(self)
    end

    def referenced_struct=(referenced_struct)
      Domgen.error("struct on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a struct") unless struct?
      @referenced_struct = (referenced_struct.is_a?(Symbol) || referenced_struct.is_a?(String)) ? self.struct_by_name(referenced_struct) : referenced_struct
    end

    def referenced_entity
      Domgen.error("referenced_entity on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a reference") unless reference?
      @referenced_entity
    end

    def referenced_entity=(referenced_entity)
      Domgen.error("referenced_entity on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a reference") unless reference?
      @referenced_entity = (referenced_entity.is_a?(Symbol) || referenced_entity.is_a?(String)) ? self.entity_by_name(referenced_entity) : referenced_entity
    end

    # The name of the local field appended with PK of foreign entity
    def referencing_link_name
      Domgen.error("referencing_link_name on #{name} is invalid as #{characteristic_container.characteristic_kind} is not a reference") unless reference?
      "#{name}#{referenced_entity.primary_key.name}"
    end

    attr_writer :polymorphic

    def polymorphic?
      Domgen.error("polymorphic? on #{name} is invalid as attribute is not a reference") unless reference?
      @polymorphic.nil? ? !referenced_entity.final? : @polymorphic
    end

    def struct_by_name(name)
      self.characteristic_container.data_module.struct_by_name(name)
    end

    def entity_by_name(name)
      self.characteristic_container.data_module.entity_by_name(name)
    end

    def characteristic_type_key
      Domgen.error('characteristic_type_key not implemented')
    end

    def characteristic_container
      Domgen.error('characteristic_container not implemented')
    end
  end


  module InheritableCharacteristic
    include Characteristic

    def inherited?
      !!@inherited
    end

    def mark_as_inherited
      @inherited = true
    end

    attr_writer :abstract

    def abstract?
      @abstract.nil? ? false : @abstract
    end

    attr_writer :override

    def override?
      @override.nil? ? false : @override
    end
  end


  module CharacteristicContainer
    attr_reader :name

    def boolean(name, options = {}, &block)
      characteristic(name, :boolean, options, &block)
    end

    def text(name, options = {}, &block)
      characteristic(name, :text, options, &block)
    end

    def string(name, length, options = {}, &block)
      if length.class == Range
        options = options.merge({:min_length => length.first, :length => length.last})
      elsif length.is_a?(Numeric)
        options = options.merge({:length => length})
      else
        Domgen.error("Second parameter to string is neither a range nor an integer. Parameter = #{length.inspect}")
      end
      characteristic(name, :text, options, &block)
    end

    def integer(name, options = {}, &block)
      characteristic(name, :integer, options, &block)
    end

    def long(name, options = {}, &block)
      characteristic(name, :long, options, &block)
    end

    def real(name, options = {}, &block)
      characteristic(name, :real, options, &block)
    end

    def datetime(name, options = {}, &block)
      characteristic(name, :datetime, options, &block)
    end

    def date(name, options = {}, &block)
      characteristic(name, :date, options, &block)
    end

    def i_enum(name, values, options = {}, &block)
      enumeration = data_module.enumeration("#{self.name}#{name}", :integer, {:top_level => false, :values => values})
      enumeration(name, enumeration.name, options, &block)
    end

    def s_enum(name, values, options = {}, &block)
      enumeration = data_module.enumeration("#{self.name}#{name}", :text, {:top_level => false, :values => values})
      enumeration(name, enumeration.name, options, &block)
    end

    def enumeration(name, enumeration_key, options = {}, &block)
      enumeration = data_module.enumeration_by_name(enumeration_key)
      params = options.dup
      params[:enumeration] = enumeration
      c = characteristic(name, :enumeration, params, &block)
      c.length = enumeration.max_value_length if enumeration.textual_values?
      c
    end

    def reference(other_type, options = {}, &block)
      name = options.delete(:name)
      if name.nil?
        if other_type.to_s.include? "."
          name = other_type.to_s.sub(/.+\./, '').to_sym
        else
          name = other_type
        end
      end

      characteristic(name.to_s.to_sym, :reference, options.merge({:referenced_entity => other_type}), &block)
    end

    def struct(name, struct_key, options = {}, &block)
      struct = data_module.struct_by_name(struct_key)
      params = options.dup
      params[:referenced_struct] = struct
      characteristic(name, :struct, params, &block)
    end

    protected

    def characteristic_by_name(name)
      characteristic = characteristic_map[name.to_s]
      Domgen.error("Unable to find #{characteristic_kind} named #{name} on type #{self.name}. Available #{characteristic_kind} set = #{attributes.collect { |a| a.name }.join(', ')}") unless characteristic
      characteristic
    end

    def characteristic_exists?(name)
      !!characteristic_map[name.to_s]
    end

    def characteristic(name, type, options, &block)
      characteristic = new_characteristic(name, type, options, &block)
      Domgen.error("Attempting to override #{characteristic_kind} #{name} on #{self.name}") if characteristic_map[name.to_s]
      characteristic_map[name.to_s] = characteristic
      characteristic
    end

    def characteristics
      characteristic_map.values
    end

    def characteristic_map
      @characteristics ||= Domgen::OrderedHash.new
    end

    def new_characteristic(name, type, options, &block)
      Domgen.error('new_characteristic not implemented')
    end

    def characteristic_kind
      Domgen.error('characteristic_kind not implemented')
    end

    # Also need to define data_module
  end

  SUPPORTED_GEOMETRY_TYPES.each do |geometry|
    CharacteristicContainer.module_eval(<<-CODE)
      def #{geometry}(name, options = {}, &block)
        params = options.dup
        params[:"geometry.geometry_type"] = :#{geometry}
        characteristic(name, :geometry, params, &block)
      end
    CODE
  end

  module InheritableCharacteristicContainer
    include CharacteristicContainer

    attr_accessor :extends

    def direct_subtypes
      @direct_subtypes ||= []
    end

    attr_writer :abstract

    def abstract?
      @abstract.nil? ? false : @abstract
    end

    attr_writer :final

    def final?
      @final.nil? ? !abstract? : @final
    end

    protected

    def declared_characteristics
      characteristics.select { |c| !c.inherited? }
    end

    def inherited_characteristics
      characteristics.select { |c| c.inherited? }
    end

    def perform_extend(data_module, type_key, extends)
      base_type = data_module.send :"#{type_key}_by_name", extends
      Domgen.error("#{type_key} #{name} attempting to extend final #{type_key} #{extends}") if base_type.final?
      base_type.direct_subtypes << self
      base_type.characteristics.collect { |c| c.clone }.each do |characteristic|
        characteristic.instance_variable_set("@#{type_key}", self)
        characteristic.mark_as_inherited
        characteristic_map[characteristic.name.to_s] = characteristic
      end
    end
  end
end
