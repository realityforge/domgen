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
  class << self
    def repositorys
      repository_map.values
    end

    def repository(name, options = {}, &block)
      Domgen::Repository.new(name, options, &block)
    end

    def repository_by_name(name)
      repository = repository_map[name.to_s]
      Domgen.error("Unable to locate repository #{name}") unless repository
      repository
    end

    private

    def register_repository(name, repository)
      repository_map[name.to_s] = repository
    end

    def repository_map
      @repositorys ||= Domgen::OrderedHash.new
    end
  end

  class ModelConstraint < self.ParentedElement(:entity)
    def initialize(entity, options, &block)
      super(entity, options, &block)
    end

    def attribute_names_to_key(entity, attribute_names)
      attribute_names.collect { |a| entity.attribute_by_name(a).name.to_s }.sort.join('_')
    end
  end

  class AttributeSetConstraint < ModelConstraint
    attr_reader :name
    attr_accessor :attribute_names

    def initialize(entity, name, attribute_names, options, &block)
      super(entity, options, &block)
      @name, @attribute_names = name, attribute_names
    end
  end

  class UniqueConstraint < AttributeSetConstraint
    def initialize(entity, attribute_names, options, &block)
      super(entity, attribute_names_to_key(entity, attribute_names), attribute_names, options, &block)
    end
  end

  class CodependentConstraint < AttributeSetConstraint
    def initialize(entity, attribute_names, options, &block)
      super(entity, "#{attribute_names_to_key(entity, attribute_names)}_CoDep", attribute_names, options, &block)
    end
  end

  class IncompatibleConstraint < AttributeSetConstraint
    def initialize(entity, attribute_names, options, &block)
      super(entity, "#{attribute_names_to_key(entity, attribute_names)}_Incompat", attribute_names, options, &block)
    end
  end

  class DependencyConstraint < ModelConstraint
    attr_reader :name
    attr_accessor :attribute_name
    attr_accessor :dependent_attribute_names

    def initialize(entity, attribute_name, dependent_attribute_names, options, &block)
      @name = "#{attribute_name}_#{attribute_names_to_key(entity, dependent_attribute_names)}_Dep"
      @attribute_name, @dependent_attribute_names = attribute_name, dependent_attribute_names
      super(entity, options, &block)
    end
  end

  class RelationshipConstraint < self.ParentedElement(:entity)
    attr_reader :name
    attr_reader :lhs_operand
    attr_reader :rhs_operand
    attr_reader :operator

    def initialize(entity, operator, lhs_operand, rhs_operand, options, &block)
      @name = "#{lhs_operand}_#{operator}_#{rhs_operand}"
      @lhs_operand, @rhs_operand, @operator = lhs_operand, rhs_operand, operator
      super(entity, options, &block)

      lhs = entity.attribute_by_name(lhs_operand)
      rhs = entity.attribute_by_name(rhs_operand)

      if lhs.attribute_type != rhs.attribute_type
        Domgen.error("Relationship constraint #{self.name} between attributes of different types LHS: #{lhs.name}:#{lhs.attribute_type}, RHS: #{rhs.name}:#{rhs.attribute_type}")
      end

      if self.class.comparable_attribute_types.include?(lhs.attribute_type) || (lhs.enumeration? && lhs.enumeration.numeric_values?)
        Domgen.error("Unknown operator #{operator} for relationship constraint #{self.name}") unless self.class.operators.keys.include?(operator)
      elsif self.class.equality_attribute_types.include?(lhs.attribute_type) || (lhs.enumeration? && lhs.enumeration.textual_values?)
        Domgen.error("Unknown operator #{operator} for relationship constraint #{self.name}") unless self.class.equality_operators.keys.include?(operator)
      else
        Domgen.error("Unsupported attribute type #{lhs.attribute_type} for relationship constraint #{self.name}")
      end
    end

    def self.operators
      self.equality_operators.merge(:lte => '<=', :lt => '<', :gte => '>=', :gt => '>')
    end

    def self.equality_operators
      {:eq => '=', :neq => '!='}
    end

    def self.numeric_operator_descriptions
      {:eq => 'equal', :neq => 'not equal', :lte => 'less than or equal', :lt => 'less than', :gte => 'greater than or equal', :gt => 'greater than'}
    end

    def self.temporal_operator_descriptions
      {:eq => 'equal', :neq => 'not equal', :lte => 'before or at the same time', :lt => 'before', :gte => 'at the same time or after', :gt => 'after'}
    end

    def self.comparable_attribute_types
      [:integer, :long, :date, :datetime, :real]
    end

    def self.equality_attribute_types
      [:text, :reference, :boolean]
    end
  end

  class CycleConstraint < self.ParentedElement(:entity)
    attr_reader :name
    attr_accessor :attribute_name
    attr_accessor :attribute_name_path

    def initialize(entity, attribute_name, attribute_name_path, options, &block)
      @name = ([attribute_name] + attribute_name_path).collect { |a| a.to_s }.sort.join('_')
      @attribute_name, @attribute_name_path = attribute_name, attribute_name_path
      super(entity, options, &block)
    end

    # the attribute on the Entity at the end of the path that must link to the same entity
    attr_writer :scoping_attribute

    def scoping_attribute
      @scoping_attribute || @attribute_name_path.last
    end
  end

  class InverseElement < Domgen.FacetedElement(:attribute)

    def initialize(attribute, options, &block)
      super(attribute, options, &block)
    end

    def to_s
      "InverseElement[#{self.attribute.qualified_name}]"
    end

    def multiplicity
      @multiplicity || :many
    end

    def multiplicity=(multiplicity)
      Domgen.error("multiplicity #{multiplicity} is invalid") unless self.class.inverse_multiplicity_types.include?(multiplicity)
      @multiplicity = multiplicity
    end

    def traversable=(traversable)
      Domgen.error("traversable #{traversable} is invalid") unless self.class.inverse_traversable_types.include?(traversable)
      @traversable = traversable
    end

    def traversable?
      @traversable.nil? ? false : @traversable
    end

    def name=(name)
      @name = name
      self.traversable = true
    end

    def name
      @name || attribute.entity.name
    end

    def relationship_kind
      @relationship_kind || :association
    end

    def relationship_kind=(relationship_kind)
      Domgen.error("relationship_kind #{relationship_kind} is invalid") unless self.class.relationship_kind_types.include?(relationship_kind)
      @relationship_kind = relationship_kind
    end

    def self.relationship_kind_types
      [:association, :aggregation, :composition]
    end

    def self.inverse_multiplicity_types
      [:one, :many, :zero_or_one]
    end

    def self.inverse_traversable_types
      [true, false]
    end
  end

  class Geometry < Domgen.ParentedElement(:characteristic)
    def geometry_type=(geometry_type)
      Domgen.error("geometry_type on #{characteristic.name} is invalid as #{geometry_type} is not a known type of geometry") unless Domgen::SUPPORTED_GEOMETRY_TYPES.include?(geometry_type.to_s)
      @geometry_type = geometry_type
    end

    def geometry_type
      @geometry_type || :geometry
    end

    def dimensions=(dimensions)
      Domgen.error("dimensions can not be specified on #{characteristic.name} as geometry_type is not raw geometry") unless geometry_type == :geometry
      Domgen.error("dimensions on #{characteristic.name} is invalid as #{dimensions} is not valid") unless [2,3].include?(dimensions)
      @dimensions = dimensions
    end

    def dimensions
      return @dimensions if geometry_type == :geometry
      return 2 if Domgen::SUPPORTED_2D_GEOMETRY_TYPES.include?(geometry_type)
      return 3 if Domgen::SUPPORTED_3D_GEOMETRY_TYPES.include?(geometry_type)
      return nil
    end

    def srid=(srid)
      @srid = srid
    end

    attr_reader :srid
  end

  class EnumerationValue < self.FacetedElement(:enumeration_set)
    attr_reader :name
    attr_reader :enumeration_set

    def initialize(enumeration_set, name, options = {}, &block)
      @name = name
      enumeration_set.send :register_enumeration_value, name, self
      super(enumeration_set, options, &block)
    end

    def value=(value)
      raise "value= invoked on #{name} enumeration value of #{enumeration_set.qualified_name} when not a text value" unless enumeration_set.textual_values?
      @value = value
    end

    def value
      raise "value invoked on #{name} enumeration value of #{enumeration_set.qualified_name} when not a text value" unless enumeration_set.textual_values?
      @value.nil? ? name.to_s : @value
    end
  end

  class EnumerationSet < self.FacetedElement(:data_module)
    include GenerateFacet

    attr_reader :name
    attr_reader :enumeration_type

    def initialize(data_module, name, enumeration_type, options = {}, &block)
      Domgen.error("Unknown enumeration type #{enumeration_type}") if !self.class.enumeration_types.include?(enumeration_type)
      @name = name
      @enumeration_type = enumeration_type
      data_module.send :register_enumeration, name, self
      super(data_module, options, &block)
    end

    def qualified_name
      "#{data_module.name}.#{self.name}"
    end

    attr_writer :top_level

    def top_level?
      @top_level.nil? ? true : @top_level
    end

    def numeric_values?
      self.enumeration_type == :integer
    end

    def textual_values?
      self.enumeration_type == :text
    end

    def value_map
      @values ||= Domgen::OrderedHash.new
    end

    def values
      value_map.values
    end

    def values=(values)
      Domgen.error("More than 0 values must be specified for enumeration #{name}") if values.size == 0
      values.each do |k|
        Domgen.error("Key #{k} of enumeration #{qualified_name} should be a string") unless k.instance_of?(String)
      end
      Domgen.error("Duplicate keys detected for enumeration #{name}") if values.uniq.size != values.size
      values.each do |v|
        self.value(v)
      end
    end

    def value(name, options = {})
      Domgen.error("Duplicate value defined enumeration #{qualified_name}") if value_map[name.to_s]
      Domgen::EnumerationValue.new(self, name, options)
    end

    def max_value_length
      Domgen.error("max_value_length invoked on numeric enumeration #{qualified_name}") if numeric_values?
      values.inject(0) { |max, value| max > value.value.length ? max : value.value.length }
    end

    def self.enumeration_types
      [:integer, :text]
    end

    def to_s
      "EnumerationSet[#{self.qualified_name}]"
    end

    protected

    def register_enumeration_value(name, enumeration_value)
      value_map[name.to_s] = enumeration_value
    end

  end

  class QueryParameter < Domgen.FacetedElement(:query)
    include Characteristic

    attr_reader :parameter_type
    attr_reader :name

    def initialize(message, name, parameter_type, options, &block)
      @name = name
      @parameter_type = parameter_type
      super(message, options, &block)
    end

    def qualified_name
      "#{query.qualified_name}$#{self.name}"
    end

    def to_s
      "QueryParameter[#{self.qualified_name}]"
    end

    def characteristic_type_key
      parameter_type
    end

    def characteristic
      self
    end

    def characteristic_kind
      "parameter"
    end

    def characteristic_container
      query
    end
  end

  class Query < self.FacetedElement(:dao)
    include GenerateFacet
    include Domgen::CharacteristicContainer

    attr_reader :name

    def initialize(dao, base_name, options = {}, &block)
      super(dao, options) do
        @name = local_name(base_name)
        yield self if block_given?
      end
    end

    def parameters
      characteristics
    end

    def parameter_by_name(name)
      characteristic_by_name(name)
    end

    def parameter_exists?(name)
      characteristic_exists?(name)
    end

    def parameter(name, type, options = {}, &block)
      characteristic(name, type, options, &block)
    end

    def qualified_name
      "#{dao.qualified_name}.#{name}"
    end

    def query_type=(query_type)
      Domgen.error("query_type #{query_type} is invalid") unless self.class.valid_query_types.include?(query_type)
      @query_type = query_type
    end

    def query_type
      @query_type || :select
    end

    def multiplicity
      @multiplicity || :many
    end

    def multiplicity=(multiplicity)
      Domgen.error("multiplicity #{multiplicity} is invalid") unless Domgen::InverseElement.inverse_multiplicity_types.include?(multiplicity)
      @multiplicity = multiplicity
    end

    def self.valid_query_types
      [:select, :update, :delete, :insert]
    end

    def to_s
      "Query[#{self.qualified_name}]"
    end

    def data_module
      self.dao.data_module
    end

    def result_type?
      !!@result_type
    end

    def result_type
      Domgen.error("result_type called on #{qualified_name} before it has been specified") unless @result_type
      @result_type
    end

    def result_type=(result_type)
      Domgen.error("Attempt to reassign result_type on #{qualified_name} from #{@result_type} to #{result_type}") if @result_type
      Domgen.error("Attempt to assign result_type on #{qualified_name} to invalid type #{result_type}") unless ([:reference, :struct] + self.class.supported_scalar_types).include?(result_type)
      @result_type = result_type
    end

    def self.supported_scalar_types
      [:integer, :long, :datetime, :real, :text, :boolean]
    end

    def result_scalar?
      !result_entity? && !result_struct?
    end

    def result_entity?
      self.result_type == :reference
    end

    def result_entity=(entity)
      self.result_type = :reference
      @entity = (entity.is_a?(Symbol) || entity.is_a?(String)) ? data_module.entity_by_name(entity) : entity
    end

    def entity
      Domgen.error("entity called on #{qualified_name} before being specified") unless @entity
      @entity
    end

    def result_struct?
      self.result_type == :struct
    end

    def result_struct=(struct)
      self.result_type = :struct
      @struct = (struct.is_a?(Symbol) || struct.is_a?(String)) ? data_module.struct_by_name(struct) : struct
    end

    def struct
      Domgen.error("struct called on #{qualified_name} before being specified") unless @struct
      @struct
    end

    protected

    def local_name(base_name)
      base_name = base_name.to_s
      if base_name =~ /^[fF]indAll$/
        self.query_type = :select if @query_type.nil?
        self.multiplicity = :many if @multiplicity.nil?
        return base_name
      elsif base_name =~ /^[fF]indAll.+$/
        self.query_type = :select if @query_type.nil?
        self.multiplicity = :many if @multiplicity.nil?
        return base_name
      elsif base_name =~ /^[fF]ind.+$/
        self.query_type = :select if @query_type.nil?
        self.multiplicity = :zero_or_one if @multiplicity.nil?
        return base_name
      elsif base_name =~ /^[gG]et.+$/
        self.query_type = :select if @query_type.nil?
        self.multiplicity = :one if @multiplicity.nil?
        return base_name
      elsif base_name =~ /^[uU]pdate.+$/
        self.query_type = :update if @query_type.nil?
        return base_name
      elsif base_name =~ /^[dD]elete.+$/
        self.query_type = :delete if @query_type.nil?
        return base_name
      elsif base_name =~ /^[iI]nsert.+$/
        self.query_type = :insert if @query_type.nil?
        return base_name
      elsif base_name =~ /^[cC]ount.+$/
        self.query_type = :select if @query_type.nil?
        self.multiplicity = :one if @multiplicity.nil?
        return base_name
      elsif self.query_type == :select
        if self.multiplicity == :many
          :"FindAllBy#{base_name}"
        elsif self.multiplicity == :zero_or_one
          :"FindBy#{base_name}"
        else
          :"GetBy#{base_name}"
        end
      elsif self.query_type == :update
        :"Update#{base_name}"
      elsif self.query_type == :delete
        :"Delete#{base_name}"
      elsif self.query_type == :insert
        :"Insert#{base_name}"
      end
    end

    def characteristic_kind
      "parameter"
    end

    def new_characteristic(name, type, options, &block)
      QueryParameter.new(self, name, type, options, &block)
    end
  end

  class DataAccessObject <  self.FacetedElement(:data_module)
    attr_reader :name

    include GenerateFacet

    def initialize(data_module, name, options, &block)
      @name = name
      @queries = Domgen::OrderedHash.new
      data_module.send :register_dao, name, self
      super(data_module, options, &block)
    end

    def qualified_name
      "#{data_module.name}.#{self.name}"
    end

    def to_s
      "DataAccessObject[#{self.qualified_name}]"
    end

    def entity=(entity)
      Domgen.error("entity= on #{qualified_name} is invalid as entity already specified") if @entity
      @entity = (entity.is_a?(Symbol) || entity.is_a?(String)) ? data_module.entity_by_name(entity) : entity
      queries.each do |query|
        query.result_entity = @entity unless query.result_type?
      end
      @entity
    end

    def entity
      Domgen.error("entity on #{qualified_name} is invalid as entity not specified") unless @entity
      @entity
    end

    def repository?
      !@entity.nil?
    end

    def queries
      @queries.values
    end

    def query(name, options = {}, &block)
      Domgen.error("Attempting to override query #{name} on #{self.name}") if @queries[name.to_s]
      params = repository? ? options.merge(:result_entity => entity) : options.dup
      query = Query.new(self, name, params, &block)
      @queries[name.to_s] = query
      query
    end
  end

  class Attribute < self.FacetedElement(:entity)
    include GenerateFacet

    include InheritableCharacteristic

    attr_reader :attribute_type

    def initialize(entity, name, attribute_type, options = {}, &block)
      @name = name
      @attribute_type = attribute_type
      super(entity, options, &block)
      Domgen.error("Invalid type #{attribute_type} for persistent attribute #{self.qualified_name}") if !((characteristic_type && characteristic_type.persistent?) || reference? || enumeration?)
      Domgen.error("Attribute #{self.qualified_name} must not be a collection") if collection?
    end

    def qualified_name
      "#{entity.qualified_name}.#{self.name}"
    end

    attr_writer :set_once

    def set_once?
      @set_once.nil? ? false : @set_once
    end

    attr_writer :generated_value

    def generated_value?
      return @generated_value unless @generated_value.nil?
      return self.primary_key? && self.integer? && !entity.abstract? && entity.final? && entity.extends.nil?
    end

    attr_writer :primary_key

    def primary_key?
      @primary_key.nil? ? false : @primary_key
    end

    attr_writer :unique

    def unique?
      @unique.nil? ? false : @unique
    end

    attr_writer :immutable

    def immutable?
      @immutable.nil? ? primary_key? : @immutable
    end

    def updatable?
      !immutable? && !generated_value?
    end

    def inverse
      Domgen.error("inverse called on #{name} is invalid as attribute is not a reference") unless reference?
      @inverse ||= InverseElement.new(self, {})
    end

    def to_s
      "Attribute[#{self.qualified_name}]"
    end

    def characteristic_type_key
      attribute_type
    end

    def characteristic_container
      entity
    end
  end

  class Entity < self.FacetedElement(:data_module)
    attr_reader :unique_constraints
    attr_reader :codependent_constraints
    attr_reader :incompatible_constraints
    attr_reader :dependency_constraints
    attr_reader :cycle_constraints
    attr_reader :referencing_attributes
    attr_reader :queries

    include GenerateFacet
    include InheritableCharacteristicContainer

    def initialize(data_module, name, options, &block)
      @name = name
      @unique_constraints = Domgen::OrderedHash.new
      @codependent_constraints = Domgen::OrderedHash.new
      @incompatible_constraints = Domgen::OrderedHash.new
      @dependency_constraints = Domgen::OrderedHash.new
      @relationship_constraints = Domgen::OrderedHash.new
      @cycle_constraints = Domgen::OrderedHash.new
      @queries = Domgen::OrderedHash.new
      @referencing_attributes = []
      data_module.send :register_entity, name, self
      super(data_module, options, &block)
    end

    def qualified_name
      "#{data_module.name}.#{self.name}"
    end

    def non_abstract_superclass?
      extends.nil? ? false : !data_module.entity_by_name(extends).abstract?
    end

    # Return the root entity in the hierarchy
    #
    # This means the current entity if it does not extend any other entity, else it means the root of the inheritance tree.
    #
    def root_entity
      self.extends.nil? ? self : data_module.entity_by_name(self.extends).root_entity
    end

    attr_writer :read_only

    def read_only?
      @read_only.nil? ? false : @read_only
    end

    def declared_attributes
      declared_characteristics
    end

    def inherited_attributes
      inherited_characteristics
    end

    def attributes
      characteristics
    end

    def attribute(name, type, options = {}, &block)
      characteristic(name, type, options, &block)
    end

    def attribute_exists?(name)
      characteristic_exists?(name)
    end

    def attribute_by_name(name)
      characteristic_by_name(name)
    end

    def queries
      dao.queries
    end

    def query(name, options = {}, &block)
      dao.query(name, options, &block)
    end

    def dao
      @dao ||= data_module.dao("#{name}Repository", :entity => name)
    end

    def unique_constraints
      @unique_constraints.values
    end

    def unique_constraint(attribute_names, options = {}, &block)
      Domgen.error("Must have at least 1 or more attribute names for uniqueness constraint") if attribute_names.empty?
      constraint = UniqueConstraint.new(self, attribute_names, options, &block)
      add_unique_to_set("unique", constraint, @unique_constraints)
    end

    def dependency_constraints
      @dependency_constraints.values
    end

    # Check that either the attribute is null or the attribute and all the dependents are not null
    def dependency_constraint(attribute_name, dependent_attribute_names, options = {}, &block)
      constraint = DependencyConstraint.new(self, attribute_name, dependent_attribute_names, options, &block)
      Domgen.error("Dependency constraint #{constraint.name} on #{self.name} has an illegal non nullable attribute") if !attribute_by_name(attribute_name).nullable?
      dependent_attribute_names.collect { |a| attribute_by_name(a) }.each do |a|
        Domgen.error("Dependency constraint #{constraint.name} on #{self.name} has an illegal non nullable dependent attribute") if !a.nullable?
      end
      add_unique_to_set('dependency', constraint, @dependency_constraints)
    end

    def relationship_constraints
      @relationship_constraints.values
    end

    # Check that either the attribute is null or the attribute and all the dependents are not null
    def relationship_constraint(operator, lhs_operand, rhs_operand, options = {}, &block)
      constraint = RelationshipConstraint.new(self, operator, lhs_operand, rhs_operand, options, &block)
      add_unique_to_set('relationship', constraint, @relationship_constraints)
    end

    def codependent_constraints
      @codependent_constraints.values
    end

    # Check that either all attributes are null or all are not null
    def codependent_constraint(attribute_names, options = {}, &block)
      constraint = CodependentConstraint.new(self, attribute_names, options, &block)
      attribute_names.collect { |a| attribute_by_name(a) }.each do |a|
        Domgen.error("Codependent constraint #{constraint.name} on #{self.name} has an illegal non nullable attribute") if !a.nullable?
      end
      add_unique_to_set('codependent', constraint, @codependent_constraints)
    end

    def incompatible_constraints
      @incompatible_constraints.values
    end

    # Check that at most one of the attributes is not null
    def incompatible_constraint(attribute_names, options = {}, &block)
      constraint = IncompatibleConstraint.new(self, attribute_names, options, &block)
      attribute_names.collect { |a| attribute_by_name(a) }.each do |a|
        Domgen.error("Incompatible constraint #{constraint.name} on #{self.name} has an illegal non nullable attribute") if !a.nullable?
      end
      add_unique_to_set('incompatible', constraint, @incompatible_constraints)
    end

    def cycle_constraints
      @cycle_constraints.values
    end

    # Constraint that ensures that the value of a particular value is within a particular scope
    def cycle_constraint(attribute_name, attribute_name_path, options = {}, &block)
      Domgen.error('Cycle constraint must have a path of length 1 or more') if attribute_name_path.empty?

      constraint = CycleConstraint.new(self, attribute_name, attribute_name_path, options, &block)

      entity = self
      constraint.attribute_name_path.each_with_index do |attribute_name_path_element, i|
        other = entity.attribute_by_name(attribute_name_path_element)
        Domgen.error("Path element #{attribute_name_path_element} is nullable") if other.nullable? && i != 0
        Domgen.error("Path element #{attribute_name_path_element} is not immutable") if !other.immutable?
        Domgen.error("Path element #{attribute_name_path_element} is not a reference") if !other.reference?
        entity = other.referenced_entity
      end
      local_reference = attribute_by_name(attribute_name)
      Domgen.error("Attribute named #{attribute_name} is not a reference") if !local_reference.reference?
      scoping_attribute = local_reference.referenced_entity.attribute_by_name(constraint.scoping_attribute)
      if entity.name.to_s != scoping_attribute.referenced_entity.name.to_s
        Domgen.error("Attribute in cycle references #{scoping_attribute.referenced_entity.name} while last reference in path is #{entity.name}")
      end

      add_unique_to_set('cycle', constraint, @cycle_constraints)
    end

    # Assume single column pk
    def primary_key
      primary_key = attributes.find { |a| a.primary_key? }
      Domgen.error("Unable to locate primary key for #{self.qualified_name}, attributes: #{attributes.collect { |a| a.name }.inspect}") unless primary_key
      primary_key
    end

    def to_s
      "Entity[#{self.qualified_name}]"
    end

    def characteristic_kind
       'attribute'
    end

    protected

    def new_characteristic(name, type, options, &block)
      override = false
      if characteristic_exists?(name)
        Domgen.error("Attempting to override non abstract attribute #{name} on #{self.qualified_name}") unless characteristic_by_name(name).abstract?
        override = true
      end
      Attribute.new(self, name, type, {:override => override}.merge(options), &block)
    end

    def perform_verify
      # Add unique constraints on all unique attributes unless covered by existing constraint
      self.attributes.each do |a|
        if a.unique?
          existing_constraint = unique_constraints.find do |uq|
            uq.attribute_names.length == 1 && uq.attribute_names[0].to_s == a.name.to_s
          end
          unique_constraint([a.name]) if existing_constraint.nil?
        end
      end

      Domgen.error("Entity #{qualified_name} must define exactly one primary key") if attributes.select { |a| a.primary_key? }.size != 1
      attributes.each do |a|
        Domgen.error("Abstract attribute #{a.name} on non abstract object type #{qualified_name}") if !abstract? && a.abstract?
      end
    end

    private

    def container_kind
      :entity
    end

    def add_unique_to_set(type, constraint, set)
      Domgen.error("Only 1 #{type} constraint with name #{constraint.name} should be defined") if set[constraint.name]
      set[constraint.name] = constraint
      constraint
    end
  end

  class StructField < Domgen.FacetedElement(:struct)
    include InheritableCharacteristic

    attr_reader :field_type
    attr_reader :component_name

    def initialize(struct, name, field_type, options, &block)
      @component_name = name
      @name = (options[:collection_type] && options[:collection_type] != :none) ? Domgen::Naming.pluralize(name) : name
      @field_type = field_type
      super(struct, options, &block)
    end

    def qualified_name
      "#{struct.qualified_name}$#{self.name}"
    end

    def to_s
      "StructField[#{self.qualified_name}]"
    end

    def characteristic_type_key
      field_type
    end

    def characteristic_container
      struct
    end
  end

  class Struct < self.FacetedElement(:data_module)
    include GenerateFacet
    include InheritableCharacteristicContainer

    def initialize(data_module, name, options, &block)
      @name = name
      data_module.send :register_struct, name, self
      perform_extend(data_module, :struct, options[:extends]) if options[:extends]
      super(data_module, options, &block)
    end

    def qualified_name
      "#{data_module.name}.#{self.name}"
    end

    attr_writer :top_level

    def top_level?
      @top_level.nil? ? true : @top_level
    end

    def substruct(name, options = {}, &block)
      struct = data_module.struct("#{self.name}#{name}", {:top_level => false}, &block)
      struct(name, struct.name, options)
    end

    def fields
      characteristics
    end

    def field(name, type, options = {}, &block)
      characteristic(name, type, options, &block)
    end

    def to_s
      "Struct[#{self.qualified_name}]"
    end

    def characteristic_kind
       "field"
    end

    protected

    def new_characteristic(name, type, options, &block)
      StructField.new(self, name, type, options, &block)
    end
  end

  class MessageParameter < Domgen.FacetedElement(:message)
    include Characteristic

    attr_reader :component_name
    attr_reader :parameter_type

    def initialize(message, name, parameter_type, options, &block)
      @component_name = name
      @name = (options[:collection_type] && options[:collection_type] != :none) ? Domgen::Naming.pluralize(name) : name
      @parameter_type = parameter_type
      super(message, options, &block)
    end

    def qualified_name
      "#{message.qualified_name}$#{self.name}"
    end

    def to_s
      "MessageParameter[#{self.qualified_name}]"
    end

    def characteristic_type_key
      parameter_type
    end

    def characteristic_container
      message
    end
  end

  class Message < self.FacetedElement(:data_module)
    include GenerateFacet
    include CharacteristicContainer

    def initialize(data_module, name, options, &block)
      @name = name
      data_module.send :register_message, name, self
      super(data_module, options, &block)
    end

    def qualified_name
      "#{data_module.name}.#{self.name}"
    end

    def parameters
      characteristics
    end

    def parameter(name, type, options = {}, &block)
      characteristic(name, type, options, &block)
    end

    def to_s
      "Message[#{self.qualified_name}]"
    end

    def characteristic_kind
       "parameter"
    end

    protected

    def new_characteristic(name, type, options, &block)
      MessageParameter.new(self, name, type, options, &block)
    end
  end

  class ExceptionParameter < Domgen.FacetedElement(:exception)
    include InheritableCharacteristic

    attr_reader :component_name
    attr_reader :parameter_type

    def initialize(exception, name, parameter_type, options, &block)
      @component_name = name
      @name = (options[:collection_type] && options[:collection_type] != :none) ? Domgen::Naming.pluralize(name) : name
      @parameter_type = parameter_type
      super(exception, options, &block)
    end

    def qualified_name
      "#{exception.qualified_name}$#{self.name}"
    end

    def to_s
      "ExceptionParameter[#{self.qualified_name}]"
    end

    def characteristic_type_key
      parameter_type
    end

    def characteristic_container
      exception
    end
  end

  class Exception < Domgen.FacetedElement(:data_module)
    include InheritableCharacteristicContainer
    include GenerateFacet

    attr_reader :name

    def initialize(data_module, name, options, &block)
      @name = name
      data_module.send :register_exception, name, self
      super(data_module, options, &block)
    end

    def qualified_name
      "#{data_module.name}.#{self.name}!"
    end

    def to_s
      "Exception[#{self.qualified_name}]"
    end

    def declared_parameters
      declared_characteristics
    end

    def inherited_parameters
      inherited_characteristics
    end

    def parameters
      characteristics
    end

    def parameter(name, type, options = {}, &block)
      characteristic(name, type, options, &block)
    end

    def characteristic_kind
      "parameter"
    end

    protected

    def container_kind
      :exception
    end

    def new_characteristic(name, type, options, &block)
      override = false
      if characteristic_exists?(name)
        Domgen.error("Attempting to override non abstract parameter #{name} on #{self.name}") unless characteristic_by_name(name).abstract?
        override = true
      end

      ExceptionParameter.new(self, name, type, {:override => override}.merge(options), &block)
    end
  end

  class Parameter < Domgen.FacetedElement(:method)
    attr_reader :name
    attr_reader :component_name
    attr_reader :parameter_type

    include Characteristic

    def initialize(method, name, parameter_type, options, &block)
      @component_name = name
      @name = (options[:collection_type] && options[:collection_type] != :none) ? Domgen::Naming.pluralize(name) : name
      @parameter_type = parameter_type
      super(method, options, &block)
    end

    def qualified_name
      "#{method.qualified_name}$#{self.name}"
    end

    def to_s
      "Parameter[#{self.qualified_name}]"
    end

    def characteristic_type_key
      parameter_type
    end

    def characteristic_container
      method
    end
  end

  class Result < Domgen.FacetedElement(:method)
    attr_reader :return_type

    include Characteristic

    def initialize(method, return_type, options, &block)
      @return_type = return_type
      super(method, options, &block)
    end

    def name
      "Return"
    end

    def qualified_name
      "#{method.qualified_name}$#{name}"
    end

    def to_s
      "Result[#{self.qualified_name}]"
    end

    def characteristic_type_key
      return_type
    end

    def characteristic_container
      method
    end
  end

  class Method <  self.FacetedElement(:service)
    include CharacteristicContainer
    include GenerateFacet

    def initialize(service, name, options, &block)
      @name = name
      @exceptions = Domgen::OrderedHash.new
      super(service, options, &block)
    end

    def qualified_name
      "#{service.qualified_name}##{self.name}"
    end

    def to_s
      "Method[#{self.qualified_name}]"
    end

    def parameters
      characteristics
    end

    def parameter(name, type, options = {}, &block)
      characteristic(name, type, options, &block)
    end

    def returns(parameter_type, options = {}, &block)
      Domgen.error("Attempting to redefine return type #{name} on #{self.qualified_name}") if @return_type
      @return_type ||= Result.new(self, parameter_type, options, &block)
    end

    def return_value
      @return_type ||= Result.new(self, :void, {})
    end

    def result
      @return_type
    end

    def exceptions
      @exceptions.values
    end

    def exception(name, options = {}, &block)
      Domgen.error("Attempting to redefine exception #{name} on #{self.qualified_name}") if @exceptions[name.to_s]
      exception = service.data_module.exception_by_name(name, true)
      if exception.nil?
        exception = service.data_module.exception(name, options)
      end
      @exceptions[name.to_s] = exception
    end

    def data_module
      self.service.data_module
    end

    def characteristic_kind
      "parameter"
    end

    protected

    def new_characteristic(name, type, options, &block)
      Parameter.new(self, name, type, options, &block)
    end
  end

  class Service <  self.FacetedElement(:data_module)
    attr_reader :name
    attr_reader :methods

    include GenerateFacet

    def initialize(data_module, name, options, &block)
      @name = name
      @methods = Domgen::OrderedHash.new
      data_module.send :register_service, name, self
      super(data_module, options, &block)
    end

    def qualified_name
      "#{data_module.name}.#{self.name}"
    end

    def to_s
      "Service[#{self.qualified_name}]"
    end

    def methods
      @methods.values
    end

    def method(name, options = {}, &block)
      Domgen.error("Attempting to override method #{name} on #{self.name}") if @methods[name.to_s]
      method = Method.new(self, name, options, &block)
      @methods[name.to_s] = method
      method
    end

    def method_by_name(name)
      m = @methods[name.to_s]
      Domgen.error("Attempting to retrieve non-existent method #{name} on #{self.name}") unless m
      m
    end

    def method_by_name?(name)
      !!@methods[name.to_s]
    end
  end

  class DataModule <  self.FacetedElement(:repository)
    attr_reader :name

    include GenerateFacet

    def initialize(repository, name, options, &block)
      repository.send :register_data_module, name, self
      @name = name
      @entities = Domgen::OrderedHash.new
      @services = Domgen::OrderedHash.new
      @messages = Domgen::OrderedHash.new
      @structs = Domgen::OrderedHash.new
      @enumerations = Domgen::OrderedHash.new
      @exceptions = Domgen::OrderedHash.new
      @daos = Domgen::OrderedHash.new
      @elements = Domgen::OrderedHash.new
      Logger.info "DataModule '#{name}' definition started"
      super(repository, options, &block)
      Logger.info "DataModule '#{name}' definition completed"
    end

    def qualified_name
      self.name
    end

    def to_s
      "DataModule[#{self.name}]"
    end

    def enumerations
      @enumerations.values
    end

    def enumeration(name, enumeration_type, options = {}, &block)
      pre_enumeration_create(name)
      enumeration = EnumerationSet.new(self, name, enumeration_type, options, &block)
      post_enumeration_create(name)
      enumeration
    end

    def enumeration_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_enumeration_by_name(name_parts[1], optional)
    end

    def enumeration_by_name?(name)
      name_parts = split_name(name)
      repository.data_module_by_name?(name_parts[0]) &&
        repository.data_module_by_name(name_parts[0]).local_enumeration_by_name?(name_parts[1])
    end

    def local_enumeration_by_name(name, optional = false)
      enumeration = @enumerations[name.to_s]
      Domgen.error("Unable to locate local enumeration #{name} in #{self.name}") if !enumeration && !optional
      yield enumeration if block_given?
      enumeration
    end

    def local_enumeration_by_name?(name)
      !@enumerations[name.to_s].nil?
    end

    def exceptions
      @exceptions.values
    end

    def exception(name, options = {}, &block)
      pre_exception_create(name)
      exception = Exception.new(self, name, options, &block)
      post_exception_create(name)
      exception
    end

    def exception_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_exception_by_name(name_parts[1], optional)
    end

    def exception_by_name?(name)
      name_parts = split_name(name)
      repository.data_module_by_name?(name_parts[0]) &&
        repository.data_module_by_name(name_parts[0]).local_exception_by_name?(name_parts[1])
    end

    def local_exception_by_name(name, optional = false)
      exception = @exceptions[name.to_s]
      Domgen.error("Unable to locate local exception #{name} in #{self.name}") if !exception && !optional
      yield exception if block_given?
      exception
    end

    def local_exception_by_name?(name)
      !@exceptions[name.to_s].nil?
    end

    def daos
      @daos.values
    end

    def dao(name, options = {}, &block)
      pre_dao_create(name)
      dao = DataAccessObject.new(self, name, options, &block)
      post_dao_create(name)
      dao
    end

    def dao_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_dao_by_name(name_parts[1], optional)
    end

    def dao_by_name?(name)
      name_parts = split_name(name)
      repository.data_module_by_name?(name_parts[0]) &&
        repository.data_module_by_name(name_parts[0]).local_dao_by_name?(name_parts[1])
    end

    def local_dao_by_name(name, optional = false)
      dao = @daos[name.to_s]
      Domgen.error("Unable to locate local dao #{name} in #{self.name}") if !dao && !optional
      yield dao if block_given?
      dao
    end

    def local_dao_by_name?(name)
      !@daos[name.to_s].nil?
    end

    def entities
      @entities.values
    end

    def entity(name, options = {}, &block)
      pre_entity_create(name)
      entity = Entity.new(self, name, options, &block)
      post_entity_create(name)
      entity
    end

    def entity_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_entity_by_name(name_parts[1], optional)
    end

    def entity_by_name?(name)
      name_parts = split_name(name)
      repository.data_module_by_name?(name_parts[0]) &&
        repository.data_module_by_name(name_parts[0]).local_entity_by_name?(name_parts[1])
    end

    def local_entity_by_name(name, optional = false)
      entity = @entities[name.to_s]
      Domgen.error("Unable to locate local entity #{name} in #{self.name}") if !entity && !optional
      yield entity if block_given?
      entity
    end

    def local_entity_by_name?(name)
      !@entities[name.to_s].nil?
    end

    def services
      @services.values
    end

    def service(name, options = {}, &block)
      pre_service_create(name)
      service = Service.new(self, name, options, &block)
      post_service_create(name)
      service
    end

    def service_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_service_by_name(name_parts[1], optional)
    end

    def service_by_name?(name)
      name_parts = split_name(name)
      repository.data_module_by_name?(name_parts[0]) &&
        repository.data_module_by_name(name_parts[0]).local_service_by_name?(name_parts[1])
    end

    def local_service_by_name(name, optional = false)
      service = @services[name.to_s]
      Domgen.error("Unable to locate local service #{name} in #{self.name}") if !service && !optional
      yield service if block_given?
      service
    end

    def local_service_by_name?(name)
      !@services[name.to_s].nil?
    end

    def messages
      @messages.values
    end

    def message(name, options = {}, &block)
      pre_message_create(name)
      message = Message.new(self, name, options, &block)
      post_message_create(name)
      message
    end

    def message_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_message_by_name(name_parts[1], optional)
    end

    def message_by_name?(name)
      name_parts = split_name(name)
      repository.data_module_by_name?(name_parts[0]) &&
        repository.data_module_by_name(name_parts[0]).local_message_by_name?(name_parts[1])
    end

    def local_message_by_name(name, optional = false)
      message = @messages[name.to_s]
      Domgen.error("Unable to locate local message #{name} in #{self.name}") if !message && !optional
      yield message if block_given?
      message
    end

    def local_message_by_name?(name)
      !@messages[name.to_s].nil?
    end

    def structs
      @structs.values
    end

    def struct(name, options = {}, &block)
      pre_struct_create(name)
      struct = Struct.new(self, name, options, &block)
      post_struct_create(name)
      struct
    end

    def struct_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_struct_by_name(name_parts[1], optional)
    end

    def struct_by_name?(name)
      name_parts = split_name(name)
      repository.data_module_by_name?(name_parts[0]) &&
        repository.data_module_by_name(name_parts[0]).local_struct_by_name?(name_parts[1])
    end

    def local_struct_by_name(name, optional = false)
      struct = @structs[name.to_s]
      Domgen.error("Unable to locate local struct #{name} in #{self.name}") if !struct && !optional
      yield struct if block_given?
      struct
    end

    def local_struct_by_name?(name)
      !@structs[name.to_s].nil?
    end

    private

    def split_name(name)
      name_parts = name.to_s.split('.')
      Domgen.error("Name should have 0 or 1 '.' separators") if (name_parts.size != 1 && name_parts.size != 2)
      name_parts = [self.name] + name_parts if name_parts.size == 1
      name_parts
    end

    def register_type_name(key, type_name, element)
      Domgen.error("Attempting to redefine #{key} of type #{@elements[key].class.name} as an #{type_name}") if @elements[key]
      @elements[key] = element
    end

    def pre_dao_create(name)
      Logger.debug "DataAccessObject '#{name}' definition started"
    end

    def post_dao_create(name)
      Logger.debug "DataAccessObject '#{name}' definition completed"
    end

    def register_dao(name, dao)
      register_type_name(name.to_s, 'jpa.dao', dao)
      @daos[name.to_s] = dao
    end

    def pre_enumeration_create(name)
      Domgen.error("Attempting to redefine Enumeration '#{name}'") if @enumerations[name.to_s]
      Logger.debug "Enumeration '#{name}' definition started"
    end

    def post_enumeration_create(name)
      Logger.debug "Enumeration '#{name}' definition completed"
    end

    def register_enumeration(name, enumeration)
      register_type_name(name.to_s, "enumeration", enumeration)
      @enumerations[name.to_s] = enumeration
    end

    def pre_exception_create(name)
      Domgen.error("Attempting to redefine Exception '#{name}'") if @exceptions[name.to_s]
      Logger.debug "Exception '#{name}' definition started"
    end

    def post_exception_create(name)
      Logger.debug "Exception '#{name}' definition completed"
    end

    def register_exception(name, exception)
      register_type_name(name.to_s, "exception", exception)
      @exceptions[name.to_s] = exception
    end

    def pre_struct_create(name)
      Domgen.error("Attempting to redefine Struct '#{name}'") if @structs[name.to_s]
      Logger.debug "Struct '#{name}' definition started"
    end

    def post_struct_create(name)
      Logger.debug "Struct '#{name}' definition completed"
    end

    def register_struct(name, struct)
      register_type_name(name.to_s, "struct", struct)
      @structs[name.to_s] = struct
    end

    def pre_entity_create(name)
      Domgen.error("Attempting to redefine Entity '#{name}'") if @entities[name.to_s]
      Logger.debug "Entity '#{name}' definition started"
    end

    def post_entity_create(name)
      Logger.debug "Entity '#{name}' definition completed"
    end

    def register_entity(name, entity)
      register_type_name(name.to_s, "entity", entity)
      @entities[name.to_s] = entity
    end

    def pre_service_create(name)
      Domgen.error("Attempting to redefine Service '#{name}'") if @services[name.to_s]
      Logger.debug "Service '#{name}' definition started"
    end

    def post_service_create(name)
      Logger.debug "Service '#{name}' definition completed"
    end

    def register_service(name, service)
      register_type_name(name.to_s, "service", service)
      @services[name.to_s] = service
    end

    def pre_message_create(name)
      Domgen.error("Attempting to redefine Message '#{name}'") if @messages[name.to_s]
      Logger.debug "Message '#{name}' definition started"
    end

    def post_message_create(name)
      Logger.debug "Message '#{name}' definition completed"
    end

    def register_message(name, message)
      register_type_name(name.to_s, "message", message)
      @messages[name.to_s] = message
    end
  end

  class ModelCheck < BaseTaggableElement
    attr_reader :repository
    attr_reader :name
    attr_accessor :check

    def initialize(repository, name, options, &block)
      @repository = repository
      repository.send :register_model_check, name, self
      @name = name
      Logger.info "Model Check '#{name}' definition started"
      super(options, &block)
      Domgen.error("Model Check '#{name}' defines no check.") unless @check
      Logger.info "Model Check '#{name}' definition completed"
    end

    def to_s
      "ModelCheck[#{self.name}]"
    end

    def check_model
      begin
        @check.call(self.repository)
      rescue
        Logger.error "Model Check '#{name}' failed."
        raise
      end
    end
  end

  class Repository <  BaseTaggableElement
    attr_reader :name

    def initialize(name, options, &block)
      @name = name
      @data_modules = Domgen::OrderedHash.new
      @model_checks = Domgen::OrderedHash.new
      Domgen::TypeDB.mark_as_initialized
      Domgen.send :register_repository, name, self
      Logger.info "Repository definition started"
      self.activate_facets
      super(options, &block)
      post_repository_definition
      Logger.info "Model Checking started."
      @model_checks.values.each do |model_check|
        model_check.check_model
      end
      Logger.info "Model Checking completed."
      Logger.info "Repository definition completed"
      Domgen.repositorys << self
    end

    def qualified_name
      self.name
    end

    def to_s
      "Repository[#{self.name}]"
    end

    def data_module(name, options = {}, &block)
      pre_data_module_create(name)
      data_module = Domgen::DataModule.new(self, name, options, &block)
      post_data_module_create(name)
      data_module
    end

    def data_modules
      @data_modules.values
    end

    def data_module_by_name(name)
      data_module = @data_modules[name.to_s]
      Domgen.error("Unable to locate data_module #{name}") unless data_module
      yield data_module if block_given?
      data_module
    end

    def data_module_by_name?(name)
      !!@data_modules[name.to_s]
    end

    def model_check(name, options = {}, &block)
      Domgen::ModelCheck.new(self, name, options, &block)
    end

    def enumeration_by_name(name, optional = false, &block)
      name_parts = split_name(name)
      data_module_by_name(name_parts[0]).local_enumeration_by_name(name_parts[1], optional, &block)
    end

    def exception_by_name(name, optional = false, &block)
      name_parts = split_name(name)
      data_module_by_name(name_parts[0]).local_exception_by_name(name_parts[1], optional, &block)
    end

    def entity_by_name(name, optional = false, &block)
      name_parts = split_name(name)
      data_module_by_name(name_parts[0]).local_entity_by_name(name_parts[1], optional, &block)
    end

    def service_by_name(name, optional = false, &block)
      name_parts = split_name(name)
      data_module_by_name(name_parts[0]).local_service_by_name(name_parts[1], optional, &block)
    end

    def struct_by_name(name, optional = false, &block)
      name_parts = split_name(name)
      data_module_by_name(name_parts[0]).local_struct_by_name(name_parts[1], optional, &block)
    end

    def message_by_name(name, optional = false, &block)
      name_parts = split_name(name)
      data_module_by_name(name_parts[0]).local_message_by_name(name_parts[1], optional, &block)
    end

    include GenerateFacet
    include Faceted

    protected

    def pre_data_module_create(name)
      Domgen.error("Attempting to redefine DataModule '#{name}'") if @data_modules[name.to_s]
      Logger.debug "DataModule '#{name}' definition started"
    end

    def post_data_module_create(name)
      Logger.debug "DataModule '#{name}' definition completed"
    end

    private

    def split_name(name)
      name_parts = name.to_s.split('.')
      Domgen.error("Name '#{name}' should have 1 '.' separator") if 2 != name_parts.size
      name_parts
    end

    def register_data_module(name, data_module)
      @data_modules[name.to_s] = data_module
    end

    def register_model_check(name, model_check)
      @model_checks[name.to_s] = model_check
    end

    def post_repository_definition
      # Run hooks in all the modules that can generate other model elements
      self.complete

      # Add back links for all references
      Logger.debug "Repository #{name}: Adding back links for all references"
      self.data_modules.each do |data_module|
        data_module.entities.each do |entity|
          entity.attributes.each do |attribute|
            if attribute.reference? && !attribute.abstract? && !attribute.inherited?
              other_entities = [attribute.referenced_entity]
              while !other_entities.empty?
                other_entity = other_entities.pop
                other_entity.direct_subtypes.each { |st| other_entities << st }
                other_entity.referencing_attributes << attribute
              end
            end
          end
        end
      end
      self.verify
    end
  end
end
