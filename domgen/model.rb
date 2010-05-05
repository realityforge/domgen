require "#{File.dirname(__FILE__)}/orderedhash.rb"

module Domgen
  class BaseConfigElement
    def initialize(options = {})
      self.options = options
      yield self if block_given?
      extension_point(:post_create)
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

  class AttributeSetConstraint < BaseConfigElement
    attr_reader :name
    attr_accessor :attribute_names

    def initialize(name, attribute_names, options, &block)
      @name, @attribute_names = name, attribute_names
      super(options, &block)
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
        @generated_value =
                primary_key? && self.attribute_type == :integer && !object_type.abstract? && object_type.final?
      end
      @generated_value
    end

    attr_writer :primary_key

    def primary_key?
      @primary_key = false if @primary_key.nil?
      @primary_key
    end

    attr_reader :length

    def length=(length)
      raise "length on #{name} is invalid as attribute is not a string" unless self.attribute_type == :string
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
      raise "values on #{name} is invalid as attribute is not an i_enum" unless self.attribute_type == :i_enum
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
      [:text, :string, :reference, :boolean, :integer, :i_enum]
    end
  end

  class ObjectType < BaseConfigElement
    attr_reader :schema
    attr_reader :name
    attr_reader :unique_constraints
    attr_reader :codependent_constraints
    attr_reader :incompatible_constraints
    attr_reader :referencing_attributes
    attr_accessor :extends

    def initialize(schema, name, options = {}, &block)
      @schema, @name = schema, name
      @attributes = Domgen::OrderedHash.new
      @unique_constraints = Domgen::OrderedHash.new
      @codependent_constraints = Domgen::OrderedHash.new
      @incompatible_constraints = Domgen::OrderedHash.new
      @referencing_attributes = []
      super(options, &block)
      verify
    end

    def verify
      # Add unique constraints on all unique attributes unless covered by existing constraint
      self.attributes.each do |a|
        if a.unique?
          existing_constraint = unique_constraints.find do |uq|
            uq.unique? && uq.attribute_names.length == 1 && uq.attribute_names[0].to_s == a.name.to_s
          end
          unique_constraint([a.name]) if existing_constraint.nil?
        end
      end

      raise "ObjectType #{name} must define exactly one primary key" if attributes.select {|a| a.primary_key?}.size != 1
      attributes.each do |a|
        raise "Abstract attribute #{a.name} on non abstract object type #{name}" if !abstract? && a.abstract?
      end
    end

    def object_type
      self
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

    def reference(other_type, options = {}, &block)
      name = (options.delete(:name) || other_type).to_s.to_sym
      attribute(name, :reference, options.merge({:references => other_type}), &block)
    end

    def i_enum(name, values, options = {}, &block)
      values.each_pair do |k, v|
        raise "Key #{k} of i_enum #{name} should be a string" unless k.instance_of?(String)
        raise "Value #{v} for key #{k} of i_enum #{name} should be an integer" unless v.instance_of?(Fixnum)
      end
      attribute(name, :i_enum, options.merge({:values => values}), &block)
    end

    def declared_attributes
      @attributes.values.select{|a|!a.inherited?}
    end

    def attributes
      @attributes.values
    end

    def attribute(name, type, options = {}, &block)
      raise "Attempting to override non abstract attribute #{name} on #{self.name}" if @attributes[name.to_s] && !@attributes[name.to_s].abstract? 
      attribute = Attribute.new(self, name, type, options, &block)
      @attributes[name.to_s] = attribute
      attribute
    end

    def unique_constraints
      @unique_constraints.values
    end

    def unique_constraint(attribute_names, options = {}, &block)
      raise "Must have at least 1 or more attribute names for uniqueness constraint" if attribute_names.empty?
      name = attribute_names.join('_')
      raise "Only 1 unique constraint with name #{name} should be defined" if @unique_constraints[name]
      unique_constraint = AttributeSetConstraint.new(name, attribute_names, options, &block)
      @unique_constraints[name] = unique_constraint
      unique_constraint
    end

    def codependent_constraints
      @codependent_constraints.values
    end

    def codependent_constraint(name, attribute_names, options = {}, &block)
      codependent_constraint = AttributeSetConstraint.new(name, attribute_names, options, &block)
      @codependent_constraints[name.to_s] = codependent_constraint
      codependent_constraint
    end

    def incompatible_constraints
      @incompatible_constraints.values
    end

    def incompatible_constraint(name, attribute_names, options = {}, &block)
      incompatible_constraint = AttributeSetConstraint.new(name, attribute_names, options, &block)
      @incompatible_constraints[name.to_s] = incompatible_constraint
      incompatible_constraint
    end

    # Assume single column pk
    def primary_key
      primary_key = attributes.find {|a| a.primary_key? }
      raise "Unable to locate primary key for #{self.name}, attributes => #{attributes.collect{|a|a.name}}" unless primary_key
      primary_key
    end

    def attribute_by_name(name)
      attribute = @attributes[name.to_s]
      raise "Unable to find attribute named #{name} on type #{self.name}" unless attribute
      attribute
    end
  end

  class Schema < BaseConfigElement
    attr_reader :schema_set
    attr_reader :name
    attr_reader :object_types

    def initialize(schema_set, name, options = {}, &block)
      @schema_set = schema_set
      @name = name
      @object_types = []
      super(options, &block)
    end

    def schema
      self
    end

    def define_object_type(name, options = {}, &block)
      if options[:extends]
        base_type = object_type_by_name(options[:extends])
        base_type.instance_variable_set("@schema",nil)
        object_type = Marshal.load(Marshal.dump(base_type))
        base_type.instance_variable_set("@schema",self)
        object_type.instance_variable_set("@abstract",nil)
        object_type.instance_variable_set("@final",nil)
        object_type.instance_variable_set("@schema",self)
        object_type.instance_variable_set("@name",name)
        object_type.options = options

        object_type.attributes.each {|a| a.instance_variable_set("@inherited",true)}
        object_type.unique_constraints.each {|a| a.instance_variable_set("@inherited",true)}
        object_type.codependent_constraints.each {|a| a.instance_variable_set("@inherited",true)}
        object_type.incompatible_constraints.each {|a| a.instance_variable_set("@inherited",true)}

        yield object_type if block_given?

        object_type.verify
        @object_types << object_type
      else
        @object_types << ObjectType.new(self, name, options, &block)
      end
    end

    def object_type_by_name(name)
      object_type = @object_types.find{|o|o.name.to_s == name.to_s}
      raise "Unable to locate object_type #{name}" unless object_type
      object_type
    end
  end

  class SchemaSet < BaseConfigElement
    attr_reader :schemas

    def initialize(options = {}, &block)
      @schemas = []
      super(options, &block)
      self.schemas.each do |schema|
        schema.object_types.each do |object_type|
          object_type.attributes.each do |attribute|
            if attribute.reference?
              attribute.referenced_object.referencing_attributes << attribute
            end
          end
        end
      end
    end

    def schema_set
      self
    end

    def define_schema(name, options = {}, &block)
      @schemas << Domgen::Schema.new(self, name, options, &block)
    end
  end
end
