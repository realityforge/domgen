module Domgen
  class << self
    def repositorys
      repository_map.values
    end

    def define_repository(name, options = {}, &block)
      Domgen::Repository.new(name, options, &block)
    end

    def repository_by_name(name)
      repository = repository_map[name.to_s]
      error("Unable to locate respository #{name}") unless repository
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

  class ModelConstraint < self.ParentedElement(:object_type)
    def initialize(object_type, options, &block)
      super(object_type, options, &block)
    end

    def attribute_names_to_key(object_type, attribute_names)
      attribute_names.collect { |a| object_type.attribute_by_name(a).name.to_s }.sort.join('_')
    end
  end

  class AttributeSetConstraint < ModelConstraint
    attr_reader :name
    attr_accessor :attribute_names

    def initialize(object_type, name, attribute_names, options, &block)
      super(object_type, options, &block)
      @name, @attribute_names = name, attribute_names
    end
  end

  class UniqueConstraint < AttributeSetConstraint
    def initialize(object_type, attribute_names, options, &block)
      super(object_type, attribute_names_to_key(object_type, attribute_names), attribute_names, options, &block)
    end
  end

  class CodependentConstraint < AttributeSetConstraint
    def initialize(object_type, attribute_names, options, &block)
      super(object_type, "#{attribute_names_to_key(object_type, attribute_names)}_CoDep", attribute_names, options, &block)
    end
  end

  class IncompatibleConstraint < AttributeSetConstraint
    def initialize(object_type, attribute_names, options, &block)
      super(object_type, "#{attribute_names_to_key(object_type, attribute_names)}_Incompat", attribute_names, options, &block)
    end
  end

  class DependencyConstraint < ModelConstraint
    attr_reader :name
    attr_accessor :attribute_name
    attr_accessor :dependent_attribute_names

    def initialize(object_type, attribute_name, dependent_attribute_names, options, &block)
      @name = "#{attribute_name}_#{attribute_names_to_key(object_type, dependent_attribute_names)}_Dep"
      @attribute_name, @dependent_attribute_names = attribute_name, dependent_attribute_names
      super(object_type, options, &block)
    end
  end

  class RelationshipConstraint < self.ParentedElement(:object_type)
    attr_reader :name
    attr_reader :lhs_operand
    attr_reader :rhs_operand
    attr_reader :operator

    def initialize(object_type, operator, lhs_operand, rhs_operand, options, &block)
      @name = "#{lhs_operand}_#{operator}_#{rhs_operand}"
      @lhs_operand, @rhs_operand, @operator = lhs_operand, rhs_operand, operator
      super(object_type, options, &block)

      lhs = object_type.attribute_by_name(lhs_operand)
      rhs = object_type.attribute_by_name(rhs_operand)

      if lhs.attribute_type != rhs.attribute_type
        error("Relationship constraint #{self.name} between attributes of different types LHS: #{lhs.name}:#{lhs.attribute_type}, RHS: #{rhs.name}:#{rhs.attribute_type}")
      end

      if self.class.comparable_attribute_types.include?(lhs.attribute_type) || (lhs.enum? && lhs.enumeration.numeric_values?)
        error("Unknown operator #{operator} for relationship constraint #{self.name}") unless self.class.operators.keys.include?(operator)
      elsif self.class.equality_attribute_types.include?(lhs.attribute_type) || (lhs.enum? && lhs.enumeration.textual_values?)
        error("Unknown operator #{operator} for relationship constraint #{self.name}") unless self.class.equality_operators.keys.include?(operator)
      else
        error("Unsupported attribute type #{lhs.attribute_type} for relationship constraint #{self.name}")
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
      [:integer, :datetime, :real]
    end

    def self.equality_attribute_types
      [:string, :reference, :boolean]
    end
  end

  class CycleConstraint < self.ParentedElement(:object_type)
    attr_reader :name
    attr_accessor :attribute_name
    attr_accessor :attribute_name_path

    def initialize(object_type, attribute_name, attribute_name_path, options, &block)
      @name = ([attribute_name] + attribute_name_path).collect { |a| a.to_s }.sort.join('_')
      @attribute_name, @attribute_name_path = attribute_name, attribute_name_path
      super(object_type, options, &block)
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
      error("multiplicity #{multiplicity} is invalid") unless self.class.inverse_multiplicity_types.include?(multiplicity)
      @multiplicity = multiplicity
    end

    def traversable=(traversable)
      error("traversable #{traversable} is invalid") unless self.class.inverse_traversable_types.include?(traversable)
      @traversable = traversable
    end

    def traversable?
      @traversable.nil? ? false : @traversable
    end

    def relationship_name=(relationship_name)
      @relationship_name = relationship_name
      self.traversable = true
    end

    def relationship_name
      @relationship_name || attribute.object_type.name
    end

    def relationship_kind
      @relationship_kind || :association
    end

    def relationship_kind=(relationship_kind)
      error("relationship_kind #{relationship_kind} is invalid") unless self.class.relationship_kind_types.include?(relationship_kind)
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

  class EnumerationSet < self.FacetedElement(:data_module)
    attr_reader :name
    attr_reader :enumeration_type

    def initialize(data_module, name, enumeration_type, options = {}, &block)
      raise "Unknown enumeration type #{enumeration_type}" if !self.class.enumeration_types.include?(enumeration_type)
      @name = name
      @enumeration_type = enumeration_type
      data_module.send :register_enumeration, name, self
      super(data_module, options, &block)
    end

    def numeric_values?
      self.enumeration_type == :integer
    end

    def textual_values?
      self.enumeration_type == :string
    end

    attr_reader :values

    def values=(values)
      error("More than 0 values must be specified for enumeration #{name}") if values.size == 0
      values.each_pair do |k, v|
        error("Key #{k} of enumeration #{name} should be a string") unless k.instance_of?(String)
        if numeric_values?
          error("Value #{v} for key #{k} of enumeration #{name} should be an integer") unless v.instance_of?(Fixnum)
        else
          error("Value #{v} for key #{k} of enumeration #{name} should be a string") unless v.instance_of?(String)
        end
      end
      error("Duplicate keys detected for enumeration #{name}") if values.keys.uniq.size != values.size
      error("Duplicate values detected for enumeration #{name}") if values.values.uniq.size != values.size
      if numeric_values?
        sorted_values = values.values.sort

        if (sorted_values[sorted_values.size - 1] - sorted_values[0] + 1) != sorted_values.size
          error("Non-continuous values detected for enumeration #{name}")
        end
      end

      @values = values
    end

    def max_value_length
      error("max_value_length invoked on numeric enumeration") if numeric_values?
      values.inject(0) { |max, value| max > value.length ? max : value.length }
    end

    def self.enumeration_types
      [:integer, :string]
    end

  end

  module Characteristic
    attr_reader :name

    def enum?
      characteristic_type == :enumeration
    end

    def has_length?
      characteristic_type == :string || (characteristic_type == :enumeration && enumeration.textual_values?)
    end

    attr_reader :length

    def length=(length)
      error("length on #{name} is invalid as #{characteristic_kind} is not a string") unless has_length?
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
      error("min_length on #{name} is invalid as #{characteristic_kind} is not a string") unless has_length?
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
      error("enumeration on #{name} is invalid as #{characteristic_kind} is not an enumeration") unless enum?
      @enumeration = enumeration
    end

    def characteristic_type
      raise "characteristic_type not implemented"
    end

    protected

    def characteristic_kind
       raise "characteristic_kind not implemented"
    end
  end

  class Attribute < self.FacetedElement(:object_type)
    include Characteristic

    attr_reader :attribute_type

    def initialize(object_type, name, attribute_type, options = {}, &block)
      @name = name
      @attribute_type = attribute_type
      super(object_type, options, &block)
      error("Invalid type #{attribute_type} for persistent attribute #{name}") if persistent? && !self.class.persistent_types.include?(attribute_type)
    end

    def qualified_name
      "#{object_type.qualified_name}.#{self.name}"
    end

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

    def reference?
      self.attribute_type == :reference
    end

    attr_writer :validate

    def validate?
      @validate.nil? ? true : @validate
    end

    attr_writer :set_once

    def set_once?
      @set_once.nil? ? false : @set_once
    end

    attr_writer :generated_value

    def generated_value?
      return @generated_value unless @generated_value.nil?
      return self.primary_key? && self.attribute_type == :integer && !object_type.abstract? && object_type.final? && object_type.extends.nil?
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

    attr_writer :persistent

    def persistent?
      @persistent.nil? ? true : @persistent
    end

    attr_writer :polymorphic

    def polymorphic?
      error("polymorphic? on #{name} is invalid as attribute is not a reference") unless reference?
      @polymorphic.nil? ? !referenced_object.final? : @polymorphic
    end

    def inverse
      error("inverse called on #{name} is invalid as attribute is not a reference") unless reference?
      @inverse ||= InverseElement.new(self, {})
    end

    attr_reader :references

    def references=(references)
      error("references on #{name} is invalid as attribute is not a reference") unless reference?
      @references = references
    end

    def referenced_object
      error("referenced_object on #{name} is invalid as attribute is not a reference") unless reference?
      self.object_type.data_module.object_type_by_name(self.references)
    end

    # The name of the local field appended with PK of foreign object
    def referencing_link_name
      error("referencing_link_name on #{name} is invalid as attribute is not a reference") unless reference?
      "#{name}#{referenced_object.primary_key.name}"
    end

    def on_update=(on_update)
      error("on_update on #{name} is invalid as attribute is not a reference") unless reference?
      error("on_update #{on_update} on #{name} is invalid") unless self.class.change_actions.include?(on_update)
      @on_update = on_update
    end

    def on_update
      error("on_update on #{name} is invalid as attribute is not a reference") unless reference?
      @on_update = :no_action if @on_update.nil?
      @on_update
    end

    def on_delete=(on_delete)
      error("on_delete on #{name} is invalid as attribute is not a reference") unless reference?
      error("on_delete #{on_delete} on #{name} is invalid") unless self.class.change_actions.include?(on_delete)
      @on_delete = on_delete
    end

    def on_delete
      error("on_delete on #{name} is invalid as attribute is not a reference") unless reference?
      @on_delete = :no_action if @on_delete.nil?
      @on_delete
    end

    def self.change_actions
      #{ :cascade => "CASCADE", :restrict => "RESTRICT", :set_null => "SET NULL", :set_default => "SET DEFAULT", :no_action => "NO ACTION" }.freeze
      [:cascade, :restrict, :set_null, :set_default, :no_action]
    end

    def self.persistent_types
      [:text, :string, :reference, :boolean, :datetime, :integer, :real, :enumeration]
    end

    def to_s
      "Attribute[#{self.qualified_name}]"
    end

    def characteristic_type
      attribute_type
    end

    private

    def characteristic_kind
       "attribute"
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
        options = options.merge({:min_length => length.first, :length => length.last })
      else
        options = options.merge({:length => length})
      end
      characteristic(name, :string, options, &block)
    end

    def integer(name, options = {}, &block)
      characteristic(name, :integer, options, &block)
    end

    def real(name, options = {}, &block)
      characteristic(name, :real, options, &block)
    end

    def datetime(name, options = {}, &block)
      characteristic(name, :datetime, options, &block)
    end

    def i_enum(name, values, options = {}, &block)
      enumeration_name = "#{self.name}#{name}"
      enum_manager.define_enumeration(enumeration_name,
                                      :integer,
                                      {:values => values}.merge(options))
      enumeration(name, enumeration_name, options, &block)
    end

    def s_enum(name, values, options = {}, &block)
      enumeration_name = "#{self.name}#{name}"
      enum_manager.define_enumeration(enumeration_name,
                                      :string,
                                      {:values => values}.merge(options))
      enumeration(name, enumeration_name, options, &block)
    end

    def enumeration(name, enumeration_key, options = {}, &block)
      enumeration = enum_manager.enumeration_by_name(enumeration_key)
      params = options.dup
      params[:enumeration] = enumeration
      c = characteristic(name, :enumeration, params, &block)
      if enumeration.textual_values? && c.length.nil?
        c.length = enumeration.values.inject(0) { |max, value| max > value.length ? max : value.length }
      end
      c
    end

    protected

    def characteristic_by_name(name)
      characteristic = characteristic_map[name.to_s]
      error("Unable to find #{characteristic_kind} named #{name} on type #{self.name}. Available #{characteristic_kind} set = #{attributes.collect { |a| a.name }.join(', ')}") unless characteristic
      characteristic
    end

    def characteristic_exists?(name)
      !!characteristic_map[name.to_s]
    end

    def characteristic(name, type, options, &block)
      characteristic = new_characteristic(name, type, options, &block)
      error("Attempting to override #{characteristic_kind} #{name} on #{self.name}") if characteristic_map[name.to_s]
      characteristic_map[name.to_s] = characteristic
      characteristic
    end

    def characteristics
      characteristic_map.values
    end

     def verify_characteristics
      self.characteristics.each do |c|
        c.verify
      end
    end

    def characteristic_map
      @characteristics ||= Domgen::OrderedHash.new
    end

    def new_characteristic(name, type, options, &block)
      raise "new_characteristic not implemented"
    end

    def characteristic_kind
      raise "characteristic_kind not implemented"
    end

    def enum_manager
      raise "enum_manager not implemented"
    end
  end

  class ObjectType < self.FacetedElement(:data_module)
    attr_reader :unique_constraints
    attr_reader :codependent_constraints
    attr_reader :incompatible_constraints
    attr_reader :dependency_constraints
    attr_reader :cycle_constraints
    attr_reader :referencing_attributes
    attr_accessor :extends
    attr_accessor :direct_subtypes
    attr_accessor :subtypes

    include GenerateFacet
    include CharacteristicContainer

    def initialize(data_module, name, options, &block)
      @name = name
      @unique_constraints = Domgen::OrderedHash.new
      @codependent_constraints = Domgen::OrderedHash.new
      @incompatible_constraints = Domgen::OrderedHash.new
      @dependency_constraints = Domgen::OrderedHash.new
      @relationship_constraints = Domgen::OrderedHash.new
      @cycle_constraints = Domgen::OrderedHash.new
      @referencing_attributes = []
      @direct_subtypes = []
      @subtypes = []
      data_module.send :register_object_type, name, self

      if options[:extends]
        base_type = data_module.object_type_by_name(options[:extends])
        Domgen.error("ObjectType #{name} attempting to extend final object_type #{options[:extends]}") if base_type.final?
        base_type.direct_subtypes << self
        extend_from(base_type)
      end
      super(data_module, options, &block)
    end

    def qualified_name
      "#{data_module.name}.#{self.name}"
    end

    def non_abstract_superclass?
      extends.nil? ? false : !data_module.object_type_by_name(extends).abstract?
    end

    attr_writer :abstract

    def abstract?
      @abstract.nil? ? false : @abstract
    end

    attr_writer :read_only

    def read_only?
      @read_only.nil? ? false : @read_only
    end

    attr_writer :final

    def final?
      @final.nil? ? !abstract? : @final
    end

    def reference(other_type, options = {}, &block)
      name = options.delete(:name)
      if name.nil?
        if other_type.to_s.include? "."
          name = other_type.to_s.sub(/.+\./,'').to_sym
        else
          name = other_type
        end
      end

      attribute(name.to_s.to_sym, :reference, options.merge({:references => other_type}), &block)
    end

    def declared_attributes
      attributes.select { |a| !a.inherited? }
    end

    def attributes
      characteristics
    end

    def attribute(name, type, options = {}, &block)
      characteristic(name, type, options, &block)
    end

    def unique_constraints
      @unique_constraints.values
    end

    def candidate_key(attribute_names)
      attribute_names.each do |attribute_name|
        attribute = attribute_by_name(attribute_name)
        error("Candidate keys must consist of immutable attributes") unless attribute.immutable?
      end
      unique_constraint(attribute_names)
    end

    def unique_constraint(attribute_names, options = {}, &block)
      error("Must have at least 1 or more attribute names for uniqueness constraint") if attribute_names.empty?
      constraint = UniqueConstraint.new(self, attribute_names, options, &block)
      add_unique_to_set("unique", constraint, @unique_constraints)
    end

    def dependency_constraints
      @dependency_constraints.values
    end

    # Check that either the attribute is null or the attribute and all the dependents are not null
    def dependency_constraint(attribute_name, dependent_attribute_names, options = {}, &block)
      constraint = DependencyConstraint.new(self, attribute_name, dependent_attribute_names, options, &block)
      error("Dependency constraint #{constraint.name} on #{self.name} has an illegal non nullable attribute") if !attribute_by_name(attribute_name).nullable?
      dependent_attribute_names.collect { |a| attribute_by_name(a) }.each do |a|
        error("Dependency constraint #{constraint.name} on #{self.name} has an illegal non nullable dependent attribute") if !a.nullable?
      end
      add_unique_to_set("dependency", constraint, @dependency_constraints)
    end

    def relationship_constraints
      @relationship_constraints.values
    end

    # Check that either the attribute is null or the attribute and all the dependents are not null
    def relationship_constraint(operator, lhs_operand, rhs_operand, options = {}, &block)
      constraint = RelationshipConstraint.new(self, operator, lhs_operand, rhs_operand, options, &block)
      add_unique_to_set("relationship", constraint, @relationship_constraints)
    end

    def codependent_constraints
      @codependent_constraints.values
    end

    # Check that either all attributes are null or all are not null
    def codependent_constraint(attribute_names, options = {}, &block)
      constraint = CodependentConstraint.new(self, attribute_names, options, &block)
      attribute_names.collect { |a| attribute_by_name(a) }.each do |a|
        error("Codependent constraint #{constraint.name} on #{self.name} has an illegal non nullable attribute") if !a.nullable?
      end
      add_unique_to_set("codependent", constraint, @codependent_constraints)
    end

    def incompatible_constraints
      @incompatible_constraints.values
    end

    # Check that at most one of the attributes is not null
    def incompatible_constraint(attribute_names, options = {}, &block)
      constraint = IncompatibleConstraint.new(self, attribute_names, options, &block)
      attribute_names.collect { |a| attribute_by_name(a) }.each do |a|
        error("Incompatible constraint #{constraint.name} on #{self.name} has an illegal non nullable attribute") if !a.nullable?
      end
      add_unique_to_set("incompatible", constraint, @incompatible_constraints)
    end

    def cycle_constraints
      @cycle_constraints.values
    end

    # Constraint that ensures that the value of a particular value is within a particular scope
    def cycle_constraint(attribute_name, attribute_name_path, options = {}, &block)
      error("Cycle constraint must have a path of length 1 or more") if attribute_name_path.empty?

      constraint = CycleConstraint.new(self, attribute_name, attribute_name_path, options, &block)

      object_type = self
      attribute_name_path.each do |attribute_name_path_element|
        other = object_type.attribute_by_name(attribute_name_path_element)
        error("Path element #{attribute_name_path_element} is not immutable") if !other.immutable?
        error("Path element #{attribute_name_path_element} is not a reference") if !other.reference?
        object_type = other.referenced_object
      end
      local_reference = attribute_by_name(attribute_name)
      error("Attribute named #{attribute_name} is not a reference") if !local_reference.reference?
      scoping_attribute = local_reference.referenced_object.attribute_by_name(constraint.scoping_attribute)
      error("Attribute in cycle references #{scoping_attribute.referenced_object.name} while last reference in path is #{object_type.name}") if object_type != scoping_attribute.referenced_object

      add_unique_to_set("cycle", constraint, @cycle_constraints)
    end

    # Assume single column pk
    def primary_key
      primary_key = attributes.find { |a| a.primary_key? }
      error("Unable to locate primary key for #{self.name}, attributes => #{attributes.collect { |a| a.name }}") unless primary_key
      primary_key
    end

    def attribute_by_name(name)
      characteristic_by_name(name)
    end

    def attribute_exists?(name)
      characteristic_exists?(name)
    end

    def to_s
      "ObjectType[#{self.qualified_name}]"
    end

    protected

    def characteristic_kind
       "attribute"
    end

    def enum_manager
      data_module
    end

    def new_characteristic(name, type, options, &block)
      if characteristic_map[name.to_s]
        error("Attempting to override non abstract attribute #{name} on #{self.name}") if !characteristic_map[name.to_s].abstract?
        # nil out atribute so the characteristic container will not complain about it overriding an existing value
        characteristic_map[name.to_s] = nil
      end
      Attribute.new(self, name, type, {:override => !characteristic_map[name.to_s].nil?}.merge(options), &block)
    end

    def perform_verify
      verify_characteristics

      # Add unique constraints on all unique attributes unless covered by existing constraint
      self.attributes.each do |a|
        if a.unique?
          existing_constraint = unique_constraints.find do |uq|
            uq.attribute_names.length == 1 && uq.attribute_names[0].to_s == a.name.to_s
          end
          unique_constraint([a.name]) if existing_constraint.nil?
        end
      end

      error("ObjectType #{name} must define exactly one primary key") if attributes.select { |a| a.primary_key? }.size != 1
      attributes.each do |a|
        error("Abstract attribute #{a.name} on non abstract object type #{name}") if !abstract? && a.abstract?
      end
    end

    private

    def extend_from(base_type)
      base_type.attributes.collect { |a| a.clone }.each do |attribute|
        attribute.instance_variable_set("@object_type", self)
        attribute.mark_as_inherited
        characteristic_map[attribute.name.to_s] = attribute
      end
    end

    def add_unique_to_set(type, constraint, set)
      error("Only 1 #{type} constraint with name #{constraint.name} should be defined") if set[constraint.name]
      set[constraint.name] = constraint
      constraint
    end
  end

  class MessageParameter < Domgen.FacetedElement(:message)
    include Characteristic

    attr_reader :parameter_type

    def initialize(message, name, parameter_type, options, &block)
      @name = name
      @parameter_type = parameter_type
      super(message, options, &block)
    end

    def qualified_name
      "#{message.qualified_name}$#{self.name}"
    end

    def to_s
      "MessageParameter[#{self.qualified_name}]"
    end

    def characteristic_type
      parameter_type
    end

    protected

    def characteristic_kind
       "parameter"
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

    protected

    def characteristic_kind
       raise "parameter"
    end

    def enum_manager
      data_module
    end

    def new_characteristic(name, type, options, &block)
      MessageParameter.new(self, name, type, options, &block)
    end

    def perform_verify
      verify_characteristics
    end
  end

  class Exception < Domgen.FacetedElement(:data_module)
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
  end

  class Parameter < Domgen.FacetedElement(:method)
    attr_reader :name
    attr_reader :parameter_type

    include Characteristic

    def initialize(method, name, parameter_type, options, &block)
      @name = name
      @parameter_type = parameter_type
      super(method, options, &block)
    end

    def qualified_name
      "#{method.qualified_name}$#{self.name}"
    end

    attr_writer :nullable

    def nullable?
      @nullable.nil? ? false : @nullable
    end

    def to_s
      "Parameter[#{self.qualified_name}]"
    end

    def characteristic_type
      parameter_type
    end

    protected

    def characteristic_kind
       "parameter"
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

    def characteristic_type
      return_type
    end

    protected

    def characteristic_kind
       "return"
    end
  end

  class Method <  self.FacetedElement(:service)
    include CharacteristicContainer

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
      characteristic_map.values
    end

    def parameter(name, type, options = {}, &block)
      characteristic(name, type, options, &block)
    end

    def returns(parameter_type, options = {}, &block)
      error("Attempting to redefine return type #{name} on #{self.qualified_name}") if @return_type
      @return_type = Result.new(self, parameter_type, options, &block)
      @return_type
    end

    def return_value
      @return_type ||= Result.new(self, :void, {})
    end

    def exceptions
      @exceptions.values
    end

    def exception(name, options = {}, &block)
      error("Attempting to redefine exception #{name} on #{self.qualified_name}") if @exceptions[name.to_s]
      begin
        service.data_module.exception_by_name(name)
      rescue
        service.data_module.define_exception(name)
      end
      @exceptions[name.to_s] = service.data_module.exception_by_name(name)
    end

    protected

    def new_characteristic(name, type, options, &block)
      Parameter.new(self, name, type, options, &block)
    end

    def characteristic_kind
      "parameter"
    end

    def enum_manager
      method.service.data_module
    end

    def perform_verify
      verify_characteristics
      return_value.verify
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
      error("Attempting to override method #{name} on #{self.name}") if @methods[name.to_s]
      method = Method.new(self, name, options, &block)
      @methods[name.to_s] = method
      method
    end

    protected

    def perform_verify
      methods.each { |p| p.verify }
    end
  end

  class DataModule <  self.FacetedElement(:repository)
    attr_reader :name

    include GenerateFacet

    def initialize(repository, name, options, &block)
      repository.send :register_data_module, name, self
      @name = name
      @object_types = Domgen::OrderedHash.new
      @services = Domgen::OrderedHash.new
      @messages = Domgen::OrderedHash.new
      @enumerations = Domgen::OrderedHash.new
      @exceptions = Domgen::OrderedHash.new
      Logger.info "DataModule '#{name}' definition started"
      super(repository, options, &block)
      Logger.info "DataModule '#{name}' definition completed"
    end

    def to_s
      "DataModule[#{self.name}]"
    end

    def enumerations
      @enumerations.values
    end

    def define_enumeration(name, enumeration_type, options = {}, &block)
      pre_enumeration_create(name)
      enumeration = EnumerationSet.new(self, name, enumeration_type, options, &block)
      post_enumeration_create(name)
      enumeration
    end

    def enumeration_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_enumeration_by_name(name_parts[1], optional)
    end

    def local_enumeration_by_name(name, optional = false)
      enumeration = @enumerations[name.to_s]
      error("Unable to locate local enumeration #{name} in #{self.name}") if !enumeration && !optional
      enumeration
    end

    def exceptions
      @exceptions.values
    end

    def define_exception(name, options = {}, &block)
      pre_exception_create(name)
      exception = Exception.new(self, name, options, &block)
      post_exception_create(name)
      exception
    end

    def exception_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_exception_by_name(name_parts[1], optional)
    end

    def local_exception_by_name(name, optional = false)
      exception = @exceptions[name.to_s]
      error("Unable to locate local exception #{name} in #{self.name}") if !exception && !optional
      exception
    end

    def object_types
      @object_types.values
    end

    def define_object_type(name, options = {}, &block)
      pre_object_type_create(name)
      object_type = ObjectType.new(self, name, options, &block)
      post_object_type_create(name)
      object_type
    end

    def object_type_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_object_type_by_name(name_parts[1], optional)
    end

    def local_object_type_by_name(name, optional = false)
      object_type = @object_types[name.to_s]
      error("Unable to locate local object_type #{name} in #{self.name}") if !object_type && !optional
      object_type
    end

    def services
      @services.values
    end

    def define_service(name, options = {}, &block)
      pre_service_create(name)
      service = Service.new(self, name, options, &block)
      post_service_create(name)
      service
    end

    def service_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_service_by_name(name_parts[1], optional)
    end

    def local_service_by_name(name, optional = false)
      service = @services[name.to_s]
      error("Unable to locate local service #{name} in #{self.name}") if !service && !optional
      service
    end

    def messages
      @messages.values
    end

    def define_message(name, options = {}, &block)
      pre_message_create(name)
      message = Message.new(self, name, options, &block)
      post_message_create(name)
      message
    end

    def message_by_name(name, optional = false)
      name_parts = split_name(name)
      repository.data_module_by_name(name_parts[0]).local_message_by_name(name_parts[1], optional)
    end

    def local_message_by_name(name, optional = false)
      message = @messages[name.to_s]
      error("Unable to locate local message #{name} in #{self.name}") if !message && !optional
      message
    end

    protected

    def perform_verify
      object_types.each { |p| p.verify }
      services.each { |p| p.verify }
      messages.each { |p| p.verify }
      enumerations.each { |p| p.verify }
      exceptions.each { |p| p.verify }
    end

    private

    def split_name(name)
      name_parts = name.to_s.split('.')
      error("Name should have 0 or 1 '.' separators") if (name_parts.size != 1 && name_parts.size != 2)
      name_parts = [self.name] + name_parts if name_parts.size == 1
      name_parts
    end

    def pre_enumeration_create(name)
      error("Attempting to redefine Enumeration '#{name}'") if @enumerations[name.to_s]
      Logger.debug "Enumeration '#{name}' definition started"
    end

    def post_enumeration_create(name)
      Logger.debug "Enumeration '#{name}' definition completed"
    end

    def register_enumeration(name, enumeration)
      @enumerations[name.to_s] = enumeration
    end

    def pre_exception_create(name)
      error("Attempting to redefine Exception '#{name}'") if @exceptions[name.to_s]
      Logger.debug "Exception '#{name}' definition started"
    end

    def post_exception_create(name)
      Logger.debug "Exception '#{name}' definition completed"
    end

    def register_exception(name, exception)
      @exceptions[name.to_s] = exception
    end

    def pre_object_type_create(name)
      error("Attempting to redefine Object Type '#{name}'") if @object_types[name.to_s]
      Logger.debug "Object Type '#{name}' definition started"
    end

    def post_object_type_create(name)
      Logger.debug "Object Type '#{name}' definition completed"
    end

    def register_object_type(name, object_type)
      @object_types[name.to_s] = object_type
    end

    def pre_service_create(name)
      error("Attempting to redefine Service '#{name}'") if @services[name.to_s]
      Logger.debug "Service '#{name}' definition started"
    end

    def post_service_create(name)
      Logger.debug "Service '#{name}' definition completed"
    end

    def register_service(name, service)
      @services[name.to_s] = service
    end

    def pre_message_create(name)
      error("Attempting to redefine Message '#{name}'") if @messages[name.to_s]
      Logger.debug "Message '#{name}' definition started"
    end

    def post_message_create(name)
      Logger.debug "Message '#{name}' definition completed"
    end

    def register_message(name, message)
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
      error("Model Check '#{name}' defines no check.") unless @check
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

    def to_s
      "Repository[#{self.name}]"
    end

    def define_data_module(name, options = {}, &block)
      Domgen::DataModule.new(self, name, options, &block)
    end

    def data_modules
      @data_modules.values
    end

    def data_module_by_name(name)
      data_module = @data_modules[name.to_s]
      error("Unable to locate data_module #{name}") unless data_module
      data_module
    end

    def define_model_check(name, options = {}, &block)
      Domgen::ModelCheck.new(self, name, options, &block)
    end

    include GenerateFacet
    include Faceted

    protected

    def perform_verify
      data_modules.each { |p| p.verify }
    end

    private

    def register_data_module(name, data_module)
      @data_modules[name.to_s] = data_module
    end

    def register_model_check(name, model_check)
      @model_checks[name.to_s] = model_check
    end

    def post_repository_definition
      # Add back links for all references
      Logger.debug "Repository #{name}: Adding back links for all references"
      self.data_modules.each do |data_module|
        data_module.object_types.each do |object_type|
          object_type.attributes.each do |attribute|
            if attribute.reference? && !attribute.abstract? && !attribute.inherited?
              other_object_types = [attribute.referenced_object]
              while !other_object_types.empty?
                other_object_type = other_object_types.pop
                other_object_type.direct_subtypes.each { |st| other_object_types << st }
                other_object_type.referencing_attributes << attribute
              end
            end
          end
        end
      end
      # generate lists of subtypes for object types
      Logger.debug "Repository #{name}: Generate lists of subtypes for object types"
      self.data_modules.each do |data_module|
        data_module.object_types.select { |object_type| !object_type.final? }.each do |object_type|
          subtypes = object_type.subtypes
          to_process = [object_type]
          completed = []
          while to_process.size > 0
            ot = to_process.pop
            ot.direct_subtypes.each do |subtype|
              next if completed.include?(subtype)
              subtypes << subtype
              to_process << subtype
              completed << subtype
            end
          end
        end
      end
      self.verify
    end
  end
end
