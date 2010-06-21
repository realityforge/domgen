module Domgen
  Logger = ::Logger.new(STDOUT)
  Logger.level = ::Logger::WARN
  Logger.datetime_format = ''

  class << self
    attr_accessor :schema_sets
  end
  self.schema_sets = []

  class BaseConfigElement
    def initialize(options = {})
      self.options = options
      yield self if block_given?
    end

    def inherited?
      !!@inherited
    end

    def options=(options)
      options.each_pair do |k, v|
        self.send "#{k}=", v
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
  end

  class BaseGeneratableElement < BaseConfigElement
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

  class AttributeSetConstraint < BaseConfigElement
    attr_reader :name
    attr_accessor :attribute_names

    def initialize(name, attribute_names, options, &block)
      @name, @attribute_names = name, attribute_names
      super(options, &block)
    end
  end

  class DependencyConstraint < BaseConfigElement
    attr_reader :name
    attr_accessor :attribute_name
    attr_accessor :dependent_attribute_names

    def initialize(name, attribute_name, dependent_attribute_names, options, &block)
      @name, @attribute_name, @dependent_attribute_names = name, attribute_name, dependent_attribute_names
      super(options, &block)
    end
  end

  class ScopeConstraint < BaseConfigElement
    attr_reader :name
    attr_accessor :attribute_name
    attr_accessor :attribute_name_path

    def initialize(name, attribute_name, attribute_name_path, options, &block)
      @name, @attribute_name, @attribute_name_path = name, attribute_name, attribute_name_path
      super(options, &block)
    end

    # the attribute by which the related attribute is scoped
    attr_writer :scoping_attribute

    def scoping_attribute
      @scoping_attribute ||= @attribute_name_path.last
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
      raise "Invalid type #{attribute_type} for persistent attribute #{name}" if persistent? && !self.class.persistent_types.include?(attribute_type)
    end

    attr_writer :abstract

    def abstract?
      @abstract = false if @abstract.nil?
      @abstract
    end

    attr_writer :override

    def override?
      @override = false if @override.nil?
      @override
    end

    def reference?
      self.attribute_type == :reference
    end

    attr_writer :validate

    def validate?
      @validate = true if @validate.nil?
      @validate
    end

    attr_writer :unique

    def unique?
      @unique = false if @unique.nil?
      @unique
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
      @primary_key = false if @primary_key.nil?
      @primary_key
    end

    attr_reader :length

    def length=(length)
      raise "length on #{name} is invalid as attribute is not a string" unless self.attribute_type == :string || self.attribute_type == :s_enum
      @length = length
    end

    attr_writer :unique

    def unique?
      @unique = false if @unique.nil?
      @unique
    end

    attr_writer :nullable

    def nullable?
      @nullable = false if @nullable.nil?
      @nullable
    end

    attr_reader :values

    def values=(values)
      raise "values on #{name} is invalid as attribute is not an i_enum or s_enum" unless enum?
      @values = values
    end

    attr_writer :immutable

    def immutable?
      @immutable = false if @immutable.nil?
      @immutable
    end

    attr_writer :persistent

    def persistent?
      @persistent = true if @persistent.nil?
      @persistent
    end

    attr_reader :references

    def references=(references)
      raise "references on #{name} is invalid as attribute is not a reference" unless reference?
      @references = references
    end

    def referenced_object
      raise "referenced_object on #{name} is invalid as attribute is not a reference" unless reference?
      self.object_type.schema.object_type_by_name(self.references)
    end

    # The name of the local field appended with PK of foreign object
    def referencing_link_name
      raise "referencing_link_name on #{name} is invalid as attribute is not a reference" unless reference?
      "#{name}#{referenced_object.primary_key.name}"
    end

    attr_writer :inverse_relationship_type

    def inverse_relationship_type
      raise "inverse_relationship_type on #{name} is invalid as attribute is not a reference" unless reference?
      @inverse_relationship_type = :has_many if @inverse_relationship_type.nil?
      @inverse_relationship_type
    end

    attr_writer :inverse_relationship_name

    def inverse_relationship_name
      raise "inverse_relationship_name on #{name} is invalid as attribute is not a reference" unless reference?
      @inverse_relationship_name = object_type.name if @inverse_relationship_name.nil?
      @inverse_relationship_name
    end

    def self.persistent_types
      [:text, :string, :reference, :boolean, :datetime, :integer, :i_enum, :s_enum]
    end
  end

  class ObjectType < BaseGeneratableElement
    attr_reader :schema
    attr_reader :name
    attr_reader :unique_constraints
    attr_reader :codependent_constraints
    attr_reader :incompatible_constraints
    attr_reader :dependency_constraints
    attr_reader :scope_constraints
    attr_reader :referencing_attributes
    attr_accessor :extends
    attr_accessor :direct_subtypes
    attr_accessor :subtypes

    def initialize(schema, name, options = {}, &block)
      @schema = schema
      @name = name
      @attributes = Domgen::OrderedHash.new
      @unique_constraints = Domgen::OrderedHash.new
      @codependent_constraints = Domgen::OrderedHash.new
      @incompatible_constraints = Domgen::OrderedHash.new
      @dependency_constraints = Domgen::OrderedHash.new
      @scope_constraints = Domgen::OrderedHash.new
      @referencing_attributes = []
      @direct_subtypes = []
      @subtypes = []
      super(schema, options, &block)
    end

    def qualified_name
      "#{schema.name}.#{self.name}"
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

      raise "ObjectType #{name} must define exactly one primary key" if attributes.select {|a| a.primary_key?}.size != 1
      attributes.each do |a|
        raise "Abstract attribute #{a.name} on non abstract object type #{name}" if !abstract? && a.abstract?
      end
    end

    def non_abstract_superclass?
      extends.nil? ? false : !schema.object_type_by_name(extends).abstract?
    end

    attr_writer :abstract

    def abstract?
      @abstract = false if @abstract.nil?
      @abstract
    end

    attr_writer :final

    def final?
      @final = !abstract? if @final.nil?
      @final
    end

    def boolean(name, options = {}, &block)
      attribute(name, :boolean, options, &block)
    end

    def text(name, options = {}, &block)
      attribute(name, :text, options, &block)
    end

    def string(name, length, options = {}, &block)
      attribute(name, :string, options.merge({:length => length}), &block)
    end

    def integer(name, options = {}, &block)
      attribute(name, :integer, options, &block)
    end

    def datetime(name, options = {}, &block)
      attribute(name, :datetime, options, &block)
    end

    def reference(other_type, options = {}, &block)
      name = (options.delete(:name) || other_type).to_s.to_sym
      attribute(name, :reference, options.merge({:references => other_type}), &block)
    end

    def i_enum(name, values, options = {}, &block)
      raise "More than 0 values must be specified for i_enum #{name}" if values.size == 0
      values.each_pair do |k, v|
        raise "Key #{k} of i_enum #{name} should be a string" unless k.instance_of?(String)
        raise "Value #{v} for key #{k} of i_enum #{name} should be an integer" unless v.instance_of?(Fixnum)
      end
      raise "Duplicate keys detected for i_enum #{name}" if values.keys.uniq.size != values.size
      raise "Duplicate values detected for i_enum #{name}" if values.values.uniq.size != values.size
      sorted_values = values.values.sort

      if (sorted_values[sorted_values.size - 1] - sorted_values[0] + 1) != sorted_values.size
        raise "Non-continuous values detected for i_enum #{name}"
      end

      attribute(name, :i_enum, options.merge({:values => values}), &block)
    end

    def s_enum(name, values, options = {}, &block)
      raise "More than 0 values must be specified for s_enum #{name}" if values.size == 0
      values.each_pair do |k, v|
        raise "Key #{k} of s_enum #{name} should be a string" unless k.instance_of?(String)
        raise "Value #{v} for key #{k} of s_enum #{name} should be a string" unless v.instance_of?(String)
      end
      raise "Duplicate keys detected for s_enum #{name}" if values.keys.uniq.size != values.size
      raise "Duplicate values detected for s_enum #{name}" if values.values.uniq.size != values.size
      sorted_values = values.values.sort

      length = sorted_values.inject(0) {|max, value| max > value.length ? max : value.length }

      attribute(name, :s_enum, options.merge({:values => values, :length => length}), &block)
    end

    def declared_attributes
      @attributes.values.select{|a|!a.inherited?}
    end

    def attributes
      @attributes.values
    end

    def attribute(name, type, options = {}, &block)
      raise "Attempting to override non abstract attribute #{name} on #{self.name}" if @attributes[name.to_s] && !@attributes[name.to_s].abstract?
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
        raise "Candidate keys must consist of immutable attributes" unless attribute.immutable?
      end
      unique_constraint(attribute_names)
    end

    def unique_constraint(attribute_names, options = {}, &block)
      raise "Must have at least 1 or more attribute names for uniqueness constraint" if attribute_names.empty?
      name = attribute_names_to_key(attribute_names)
      raise "Only 1 unique constraint with name #{name} should be defined" if @unique_constraints[name]
      unique_constraint = AttributeSetConstraint.new(name, attribute_names, options, &block)
      @unique_constraints[name] = unique_constraint
      unique_constraint
    end

    def dependency_constraints
      @dependency_constraints.values
    end

    # Check that either the attribute is null or the attribute and all the dependents are not null
    def dependency_constraint(attribute_name, dependent_attribute_names, options = {}, &block)
      name = "#{attribute_name}_#{attribute_names_to_key(dependent_attribute_names)}"
      raise "Dependency constraint #{name} on #{self.name} has an illegal non nullable attribute" if !attribute_by_name(attribute_name).nullable?
      dependent_attribute_names.collect{|a|attribute_by_name(a)}.each do |a|
        raise "Dependency constraint #{name} on #{self.name} has an illegal non nullable dependent attribute" if !a.nullable?
      end
      dependency_constraint = DependencyConstraint.new(name, attribute_name, dependent_attribute_names, options, &block)
      @dependency_constraints[name] = dependency_constraint
      dependency_constraint
    end

    def codependent_constraints
      @codependent_constraints.values
    end

    # Check that either all attributes are null or all are not null
    def codependent_constraint(attribute_names, options = {}, &block)
      name = attribute_names_to_key(attribute_names)
      attribute_names.collect{|a|attribute_by_name(a)}.each do |a|
        raise "Codependent constraint #{name} on #{self.name} has an illegal non nullable attribute" if !a.nullable?
      end
      codependent_constraint = AttributeSetConstraint.new(name, attribute_names, options, &block)
      @codependent_constraints[name] = codependent_constraint
      codependent_constraint
    end

    def incompatible_constraints
      @incompatible_constraints.values
    end

    # Check that at most one of the attributes is not null
    def incompatible_constraint(attribute_names, options = {}, &block)
      name = attribute_names_to_key(attribute_names)
      attribute_names.collect{|a|attribute_by_name(a)}.each do |a|
        raise "Incompatible constraint #{name} on #{self.name} has an illegal non nullable attribute" if !a.nullable?
      end
      incompatible_constraint = AttributeSetConstraint.new(name, attribute_names, options, &block)
      @incompatible_constraints[name.to_s] = incompatible_constraint
      incompatible_constraint
    end

    def scope_constraints
      @scope_constraints.values
    end

    # Constraint that ensures that the value of a particular value is within a particular scope
    def scope_constraint(attribute_name, attribute_name_path, options = {}, &block)
      raise "Scope constraint must have a path of length 1 or more" if attribute_name_path.empty?
      name = ([attribute_name] + attribute_name_path).collect{|a|a.to_s}.sort.join('_')

      scope_constraint = ScopeConstraint.new(name, attribute_name, attribute_name_path, options, &block)

      object_type = self
      attribute_name_path.each do |attribute_name_path_element|
        other = object_type.attribute_by_name(attribute_name_path_element)
        raise "Path element #{attribute_name_path_element} is not immutable" if !other.immutable?
        raise "Path element #{attribute_name_path_element} is nullable" if other.nullable?
        raise "Path element #{attribute_name_path_element} is not a reference" if !other.reference?
        object_type = other.referenced_object
      end
      local_reference = attribute_by_name(attribute_name)
      raise "Attribute named #{attribute_name} is not a reference" if !local_reference.reference?
      scoping_attribute = local_reference.referenced_object.attribute_by_name(scope_constraint.scoping_attribute)
      raise "Scoping attribute references #{scoping_attribute.referenced_object.name} while last reference in path is #{object_type.name}" if object_type != scoping_attribute.referenced_object

      @scope_constraints[name.to_s] = scope_constraint
      scope_constraint
    end

    # Assume single column pk
    def primary_key
      primary_key = attributes.find {|a| a.primary_key? }
      raise "Unable to locate primary key for #{self.name}, attributes => #{attributes.collect{|a|a.name}}" unless primary_key
      primary_key
    end

    def attribute_by_name(name)
      attribute = @attributes[name.to_s]
      raise "Unable to find attribute named #{name} on type #{self.name}. Available attributes = #{attributes.collect{|a|a.name}.join(', ')}" unless attribute
      attribute
    end

    def attribute_exists?(name)
      !!@attributes[name.to_s]
    end

    private

    def attribute_names_to_key(attribute_names)
      attribute_names.collect{|a|attribute_by_name(a).name.to_s}.sort.join('_')
    end
  end

  class Schema < BaseGeneratableElement
    attr_reader :schema_set
    attr_reader :name

    def initialize(schema_set, name, options = {}, &block)
      @schema_set = schema_set
      schema_set.send :register_schema, name, self
      @name = name
      @object_types = Domgen::OrderedHash.new
      Logger.info "Schema '#{name}' definition started"
      super(schema_set, options, &block)
      Logger.info "Schema '#{name}' definition completed"
    end

    def object_types
      @object_types.values
    end

    def define_object_type(name, options = {}, &block)
      raise "Attempting to redefine Object Type '#{name}'" if @object_types[name.to_s]
      Logger.debug "Object Type '#{name}'  definition started"
      if options[:extends]
        base_type = object_type_by_name(options[:extends])
        base_type.instance_variable_set("@schema",nil)
        object_type = Marshal.load(Marshal.dump(base_type))
        base_type.instance_variable_set("@schema",self)
        object_type.instance_variable_set("@abstract",nil)
        object_type.instance_variable_set("@final",nil)
        object_type.instance_variable_set("@schema",self)
        object_type.instance_variable_set("@direct_subtypes",[])
        object_type.instance_variable_set("@name",name)
        object_type.options = options

        object_type.attributes.each {|a| a.instance_variable_set("@inherited",true)}
        object_type.unique_constraints.each {|a| a.instance_variable_set("@inherited",true)}
        object_type.codependent_constraints.each {|a| a.instance_variable_set("@inherited",true)}
        object_type.incompatible_constraints.each {|a| a.instance_variable_set("@inherited",true)}
        base_type.direct_subtypes << object_type

        yield object_type if block_given?
      else
        object_type = ObjectType.new(self, name, options, &block)
      end
      @object_types[name.to_s] = object_type
      object_type.verify
      Logger.debug "Object Type '#{name}' definition completed"
    end

    def object_type_by_name(name)
      name_parts = name.to_s.split('.')
      raise "Name should have 0 or 1 '.' separators" if (name_parts.size != 1 && name_parts.size != 2)
      name_parts = [self.name] + name_parts if name_parts.size == 1
      schema_set.schema_by_name(name_parts[0]).local_object_type_by_name(name_parts[1])
    end

    def local_object_type_by_name(name)
      object_type = @object_types[name.to_s]
      raise "Unable to locate local object_type #{name} in #{self.name}" unless object_type
      object_type
    end
  end

  class SchemaSet < BaseGeneratableElement
    def initialize(options = {}, &block)
      @schemas = Domgen::OrderedHash.new
      Logger.info "SchemaSet definition started"
      super(nil, options, &block)
      post_schema_set_definition
      Logger.info "SchemaSet definition completed"
      Domgen.schema_sets << self
    end

    def define_schema(name, options = {}, &block)
      Domgen::Schema.new(self, name, options, &block)
    end

    def schemas
      @schemas.values
    end

    def schema_by_name(name)
      schema = @schemas[name.to_s]
      raise "Unable to locate schema #{name}" unless schema
      schema
    end

    private

    def register_schema(name, schema)
      @schemas[name.to_s] = schema
    end

    def post_schema_set_definition
      # Add back links for all references
      self.schemas.each do |schema|
        schema.object_types.each do |object_type|
          object_type.attributes.each do |attribute|
            if attribute.reference? && !attribute.abstract? && !attribute.inherited?
              other_object_types = [attribute.referenced_object]
              while !other_object_types.empty?
                other_object_type = other_object_types.pop
                other_object_type.direct_subtypes.each {|st| other_object_types << st }
                other_object_type.referencing_attributes << attribute
              end
            end
          end
        end
      end
      # generate lists of subtypes for object types
      self.schemas.each do |schema|
        schema.object_types.select{|object_type| !object_type.final?}.each do |object_type|
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
      extension_point(:post_schema_set_definition)
    end
  end
end
