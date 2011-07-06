module Domgen
  Logger = ::Logger.new(STDOUT)
  Logger.level = ::Logger::WARN
  Logger.datetime_format = ''

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

    def error(message)
      Logger.error(message)
      raise message
    end

    private

    def register_repository(name, repository)
      repository_map[name.to_s] = repository
    end

    def repository_map
      @repositorys ||= Domgen::OrderedHash.new
    end
  end

  class BaseConfigElement

    attr_accessor :tags

    def initialize(options = {})
      @tags = {}
      self.options = options
      yield self if block_given?
    end

    def inherited?
      !!@inherited
    end

    def mark_as_inherited
      @inherited = true
    end

    def options=(options)
      options.each_pair do |k, v|
        self.send "#{k}=", v
      end
    end

    def description(value)
      tags[:Description] = value
    end

    def tag_as_html(key)
      value = tags[key]
      if value
        require 'maruku' unless defined?(::Maruku)
        ::Maruku.new(value).to_html
      else
        nil
      end
    end

    @@extensions = {}

    def self.extensions
      @@extensions[self.name] ||= []
    end

    def extension_point(action)
      self.class.extensions.each do |extension|
        extension_object = (self.send extension rescue nil)
        if extension_object && extension_object.respond_to?(action)
          extension_object.send action
        end
      end
    end

    protected

    def error(message)
      Domgen.error(message)
    end
  end

  class BaseGeneratableElement < BaseConfigElement
    attr_accessor :parent

    def initialize(parent, options, &block)
      @parent = parent
      @generator_keys = []
      super(options, &block)
    end

    def define_generator(generator_key)
      @generator_keys << generator_key.to_sym
    end

    def generate?(generator_key)
      @generator_keys.include?(generator_key) || (!@parent.nil? && @parent.generate?(generator_key))
    end
  end

  class ModelConstraint < BaseConfigElement
    attr_reader :object_type

    def initialize(object_type, options, &block)
      @object_type = object_type
      super(options, &block)
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

  class RelationshipConstraint < ModelConstraint
    attr_reader :name
    attr_reader :lhs_operand
    attr_reader :rhs_operand
    attr_reader :operator

    def initialize(object_type, operator, lhs_operand, rhs_operand, options, &block)
      @name = "#{lhs_operand}_#{operator}_#{rhs_operand}"
      @lhs_operand, @rhs_operand, @operator = lhs_operand, rhs_operand, operator
      raise "Unknwon operator #{operator} for relationship constraint #{@name}" unless self.class.operators.keys.include?(operator)
      super(object_type, options, &block)
    end

    def self.operators
      {:eq => '=', :neq => '!=', :lte => '<=', :lt => '<', :gte => '>=', :gt => '>'}
    end

    def self.numeric_operator_descriptions
      {:eq => 'equal', :neq => 'not equal', :lte => 'less than or equal', :lt => 'less than', :gte => 'greater than or equal', :gt => 'greater than'}
    end

    def self.temporal_operator_descriptions
      {:eq => 'equal', :neq => 'not equal', :lte => 'before or at the same time', :lt => 'before', :gte => 'at the same time or after', :gt => 'after'}
    end

    def self.comparable_attribute_types
      [:integer, :i_enum, :datetime, :real]
    end

    #TODO: Allow equality tests for [:text, :string, :reference, :boolean, :s_enum]
  end

  class CycleConstraint < ModelConstraint
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

  class InverseElement < BaseGeneratableElement

    def initialize(attribute, options, &block)
      super(attribute, options, &block)
    end

    def attribute
      self.parent
    end

    def multiplicity
      @inverse_multiplicity || :many
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

    def self.inverse_multiplicity_types
      [:one, :many, :zero_or_one]
    end

    def self.inverse_traversable_types
      [true, false]
    end
  end

  class Attribute < BaseConfigElement
    attr_reader :object_type
    attr_reader :name
    attr_reader :attribute_type

    def initialize(object_type, name, attribute_type, options = {}, &block)
      @object_type = object_type
      @name = name
      @attribute_type = attribute_type
      super(options, &block)
      error("Invalid type #{attribute_type} for persistent attribute #{name}") if persistent? && !self.class.persistent_types.include?(attribute_type)
    end

    def qualified_name
      "#{object_type.qualified_name}.#{self.name}"
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
      if @generated_value.nil?
        @generated_value = primary_key? &&
          self.attribute_type == :integer &&
          !object_type.abstract? &&
          object_type.final? &&
          object_type.extends.nil?
      end
      @generated_value
    end

    def enum?
      self.attribute_type == :i_enum || self.attribute_type == :s_enum
    end

    attr_writer :primary_key

    def primary_key?
      @primary_key.nil? ? false : @primary_key
    end

    attr_reader :length

    def length=(length)
      error("length on #{name} is invalid as attribute is not a string") unless self.attribute_type == :string || self.attribute_type == :s_enum
      @length = length
    end

    def has_non_max_length?
      !@length.nil? && @length != :max 
    end

    def min_length
      if @min_length.nil?
        @min_length = 0
      end
      if @min_length == 0 && ( @allow_blank.nil? || !@allow_blank )
        @min_length = 1
      end
      @min_length
    end

    def min_length=(length)
      error("min_length on #{name} is invalid as attribute is not a string") unless self.attribute_type == :string || self.attribute_type == :s_enum
      @min_length = length
    end

    attr_writer :allow_blank

    def allow_blank?
      if @allow_blank.nil?
        if self.min_length > 0
          false
        else
          true
        end
      else
        @allow_blank
      end
    end

    attr_writer :unique

    def unique?
      @unique.nil? ? false : @unique
    end

    attr_writer :nullable

    def nullable?
      @nullable.nil? ? false : @nullable
    end

    attr_reader :values

    def values=(values)
      error("values on #{name} is invalid as attribute is not an i_enum or s_enum") unless enum?
      @values = values
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
      [:text, :string, :reference, :boolean, :datetime, :integer, :real, :i_enum, :s_enum]
    end
  end

  class ObjectType < BaseGeneratableElement
    attr_reader :name
    attr_reader :unique_constraints
    attr_reader :codependent_constraints
    attr_reader :incompatible_constraints
    attr_reader :dependency_constraints
    attr_reader :cycle_constraints
    attr_reader :referencing_attributes
    attr_accessor :extends
    attr_accessor :direct_subtypes
    attr_accessor :subtypes

    def initialize(data_module, name, options = {}, &block)
      @name = name
      @attributes = Domgen::OrderedHash.new
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
      super(data_module, options, &block)
    end

    def data_module
      self.parent
    end

    def qualified_name
      "#{data_module.name}.#{self.name}"
    end

    def verify
      extension_point(:pre_verify)

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

      # Post verify is for when you add more things to the model
      extension_point(:post_verify)
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

    def boolean(name, options = {}, &block)
      attribute(name, :boolean, options, &block)
    end

    def text(name, options = {}, &block)
      attribute(name, :text, options, &block)
    end

    def string(name, length, options = {}, &block)
      if length.class == Range
        options = options.merge({:min_length => length.first, :length => length.last })
      else
        options = options.merge({:length => length})
      end
      attribute(name, :string, options, &block)
    end

    def integer(name, options = {}, &block)
      attribute(name, :integer, options, &block)
    end

    def real(name, options = {}, &block)
      attribute(name, :real, options, &block)
    end

    def datetime(name, options = {}, &block)
      attribute(name, :datetime, options, &block)
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

    def i_enum(name, values, options = {}, &block)
      error("More than 0 values must be specified for i_enum #{name}") if values.size == 0
      values.each_pair do |k, v|
        error("Key #{k} of i_enum #{name} should be a string") unless k.instance_of?(String)
        error("Value #{v} for key #{k} of i_enum #{name} should be an integer") unless v.instance_of?(Fixnum)
      end
      error("Duplicate keys detected for i_enum #{name}") if values.keys.uniq.size != values.size
      error("Duplicate values detected for i_enum #{name}") if values.values.uniq.size != values.size
      sorted_values = values.values.sort

      if (sorted_values[sorted_values.size - 1] - sorted_values[0] + 1) != sorted_values.size
        error("Non-continuous values detected for i_enum #{name}")
      end

      attribute(name, :i_enum, options.merge({:values => values}), &block)
    end

    def s_enum(name, values, options = {}, &block)
      error("More than 0 values must be specified for s_enum #{name}") if values.size == 0
      values.each_pair do |k, v|
        error("Key #{k} of s_enum #{name} should be a string") unless k.instance_of?(String)
        error("Value #{v} for key #{k} of s_enum #{name} should be a string") unless v.instance_of?(String)
      end
      error("Duplicate keys detected for s_enum #{name}") if values.keys.uniq.size != values.size
      error("Duplicate values detected for s_enum #{name}") if values.values.uniq.size != values.size
      sorted_values = values.values.sort

      length = sorted_values.inject(0) { |max, value| max > value.length ? max : value.length }

      attribute(name, :s_enum, options.merge({:values => values, :length => length}), &block)
    end

    def declared_attributes
      @attributes.values.select { |a| !a.inherited? }
    end

    def attributes
      @attributes.values
    end

    def attribute(name, type, options = {}, &block)
      error("Attempting to override non abstract attribute #{name} on #{self.name}") if @attributes[name.to_s] && !@attributes[name.to_s].abstract?
      attribute = Attribute.new(self, name, type, {:override => !@attributes[name.to_s].nil?}.merge(options), &block)
      @attributes[name.to_s] = attribute
      attribute
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
      lhs = attribute_by_name(lhs_operand)
      rhs = attribute_by_name(rhs_operand)
      if !RelationshipConstraint.comparable_attribute_types.include?(lhs.attribute_type)
        raise "Relationship constraint #{constraint.name} can not compare attribute type #{lhs.attribute_type} on LHS"
      end
      if !RelationshipConstraint.comparable_attribute_types.include?(rhs.attribute_type)
        raise "Relationship constraint #{constraint.name} can not compare attribute type #{rhs.attribute_type} on RHS"
      end
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
      attribute = @attributes[name.to_s]
      error("Unable to find attribute named #{name} on type #{self.name}. Available attributes = #{attributes.collect { |a| a.name }.join(', ')}") unless attribute
      attribute
    end

    def attribute_exists?(name)
      !!@attributes[name.to_s]
    end

    private

    def add_unique_to_set(type, constraint, set)
      error("Only 1 #{type} constraint with name #{constraint.name} should be defined") if set[constraint.name]
      set[constraint.name] = constraint
      constraint
    end
  end

  class DataModule < BaseGeneratableElement
    attr_reader :repository
    attr_reader :name

    def initialize(repository, name, options = {}, &block)
      @repository = repository
      repository.send :register_data_module, name, self
      @name = name
      @object_types = Domgen::OrderedHash.new
      Logger.info "DataModule '#{name}' definition started"
      super(repository, options, &block)
      Logger.info "DataModule '#{name}' definition completed"
    end

    def object_types
      @object_types.values
    end

    def define_object_type(name, options = {}, &block)
      pre_object_type_create(name)
      if options[:extends]
        base_type = object_type_by_name(options[:extends])
        base_type.instance_variable_set("@parent", nil)
        object_type = Marshal.load(Marshal.dump(base_type))
        base_type.instance_variable_set("@parent", self)
        object_type.instance_variable_set("@abstract", nil)
        object_type.instance_variable_set("@final", nil)
        object_type.instance_variable_set("@parent", self)
        object_type.instance_variable_set("@direct_subtypes", [])
        object_type.instance_variable_set("@name", name)
        object_type.options = options

        object_type.attributes.each { |a| a.mark_as_inherited }
        object_type.unique_constraints.each { |a| a.mark_as_inherited }
        object_type.codependent_constraints.each { |a| a.mark_as_inherited }
        object_type.incompatible_constraints.each { |a| a.mark_as_inherited }
        object_type.dependency_constraints.each { |a| a.mark_as_inherited }
        object_type.relationship_constraints.each { |a| a.mark_as_inherited }
        object_type.cycle_constraints.each { |a| a.mark_as_inherited }
        object_type.extension_point(:post_inherited)
        base_type.direct_subtypes << object_type
        register_object_type(name, object_type)
        yield object_type if block_given?
      else
        object_type = ObjectType.new(self, name, options, &block)
      end
      post_object_type_create(name, object_type)
    end

    def object_type_by_name(name)
      name_parts = name.to_s.split('.')
      error("Name should have 0 or 1 '.' separators") if (name_parts.size != 1 && name_parts.size != 2)
      name_parts = [self.name] + name_parts if name_parts.size == 1
      repository.data_module_by_name(name_parts[0]).local_object_type_by_name(name_parts[1])
    end

    def local_object_type_by_name(name)
      object_type = @object_types[name.to_s]
      error("Unable to locate local object_type #{name} in #{self.name}") unless object_type
      object_type
    end

    private

    def pre_object_type_create(name)
      error("Attempting to redefine Object Type '#{name}'") if @object_types[name.to_s]
      Logger.debug "Object Type '#{name}' definition started"
    end

    def post_object_type_create(name, object_type)
      Logger.debug "Object Type '#{name}' definition completed"
    end

    def register_object_type(name, object_type)
      @object_types[name.to_s] = object_type
    end
  end

  class ModelCheck < BaseConfigElement
    attr_reader :repository
    attr_reader :name
    attr_accessor :check

    def initialize(repository, name, options = {}, &block)
      @repository = repository
      repository.send :register_model_check, name, self
      @name = name
      Logger.info "Model Check '#{name}' definition started"
      super(options, &block)
      raise "Model Check '#{name}' defines no check." unless @check
      Logger.info "Model Check '#{name}' definition completed"
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

  class Repository < BaseGeneratableElement
    attr_reader :name

    def initialize(name, options = {}, &block)
      @name = name
      @data_modules = Domgen::OrderedHash.new
      @model_checks = Domgen::OrderedHash.new
      Domgen.send :register_repository, name, self
      Logger.info "Repository definition started"
      super(nil, options, &block)
      post_repository_definition
      Logger.info "Model Checking started."
      @model_checks.values.each do |model_check|
        model_check.check_model
      end
      Logger.info "Model Checking completed."
      Logger.info "Repository definition completed"
      Domgen.repositorys << self
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

    private

    def register_data_module(name, data_module)
      @data_modules[name.to_s] = data_module
    end

    def register_model_check(name, model_check)
      @model_checks[name.to_s] = model_check
    end

    def post_repository_definition
      # Add back links for all references
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
      self.data_modules.each do |data_module|
        data_module.object_types.each do |object_type|
          object_type.verify
        end
      end
      extension_point(:post_repository_definition)
    end
  end
end
