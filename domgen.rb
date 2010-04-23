require 'yaml'
require 'erb'
require 'fileutils'

# banner in sql generation
def banner(title)
  <<SQL
--
-- #{title}
--
SQL
end

# clean up string so it can be a sql identifier
def s(string)
  string.to_s.gsub('[].:', '')
end

# quote string using database rules
def q(string)
  "[#{string.to_s}]"
end

module Domgen
  module Java
    class JavaElement
      attr_reader :parent

      def initialize(parent, options = {})
        @parent = parent
        options.each_pair do |k, v|
          self.send "#{k}=", v
        end
        yield self if block_given?
      end
    end

    class JavaClass < JavaElement
      attr_writer :classname

      def classname
        @classname = parent.name unless @classname
        @classname
      end

      def fully_qualified_name
        "#{parent.schema.java.package}.#{classname}"
      end
    end

    class JavaField < JavaElement
      TYPE_MAP = {"string" => "java.lang.String",
                  "integer" => "java.lang.Integer",
                  "i_enum" => "java.lang.Integer",
                  "List" => "java.util.List"}
      attr_writer :field_name

      def field_name
        @field_name = parent.name unless @field_name
        @field_name
      end

      attr_writer :java_type

      def java_type
        unless @java_type
          if :reference == parent.attribute_type
            @java_type = parent.object_type.schema.object_type_by_name(parent.name).java.classname
          else
            @java_type = TYPE_MAP[parent.attribute_type.to_s]
          end
          raise "Unknown type #{parent.attribute_type}" unless @java_type
        end
        @java_type
      end
    end    

    class JavaPackage < JavaElement
      attr_writer :package

      def package
        @package = parent.name unless @package
        @package
      end
    end
  end

  class Constraint
    attr_reader :name
    attr_accessor :sql

    def initialize(name, options = {})
      @name = name
      @name.freeze
      options.each_pair do |k, v|
        self.send "#{k}=", v
      end
      yield self if block_given?
    end
  end

  class AttributeSetConstraint
    attr_reader :name
    attr_accessor :attribute_names

    def initialize(name, attribute_names, options)
      @name, @attribute_names = name, attribute_names
      options.each_pair do |k, v|
        self.send "#{k}=", v
      end
      yield self if block_given?
    end
  end

  class Validation
    attr_reader :name
    attr_accessor :sql

    def initialize(name, options = {})
      @name = name
      @name.freeze
      options.each_pair do |k, v|
        self.send "#{k}=", v
      end
      yield self if block_given?
    end
  end

  class Attribute
    attr_reader :object_type
    attr_reader :name
    attr_reader :attribute_type

    def initialize(object_type, name, attribute_type, options = {})
      @object_type = object_type
      @name = name
      @attribute_type = attribute_type
      options.each_pair do |k, v|
        self.send "#{k}=", v
      end
      yield self if block_given?
      raise "Invalid type #{attribute_type} for persistent attribute #{name}" if persistent? && !self.class.persistent_types.include?(attribute_type)
      raise "non persistent attributes have no column_name" if !persistent? && !@column_name.nil?
    end


    def reverse(relationship, options = {})
      raise "reverse on #{name} is invalid as attribute is not a reference" unless self.attribute_type == :reference
      self
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

    attr_writer :column_name

    def column_name
      raise "non persistent attributes have no column_name" unless persistent?
      @column_name = q(name) if @column_name.nil?
      @column_name
    end

    def java
      @java = Domgen::Java::JavaField.new(self) unless @java
      @java
    end

    def self.persistent_types
      [:string, :reference, :integer, :i_enum]
    end
  end

  class ObjectType
    attr_reader :schema
    attr_reader :name
    attr_reader :options
    attr_reader :attributes
    attr_reader :constraints
    attr_reader :validations
    attr_reader :codependent_constraints
    attr_reader :incompatible_constraints

    def initialize(schema, name, options = {})
      @schema, @name = schema, name
      @options = options
      @attributes = []
      @constraints = []
      @validations = []
      @codependent_constraints = []
      @incompatible_constraints = []
      yield self if block_given?
    end

    def object_type
      self
    end

    def string(name, length, options = {}, &block)
      attribute(name, :string, options.merge({:length => length}), &block)
    end

    def integer(name, options = {}, &block)
      attribute(name, :integer, options, &block)
    end

    def reference(name, options = {}, &block)
      attribute(name, :reference, options, &block)
    end

    def i_enum(name, values, options = {}, &block)
      values.each_pair do |k, v|
        raise "Key #{k} of i_enum #{name} should be a string" unless k.instance_of?(String)
        raise "Value #{v} for key #{k} of i_enum #{name} should be an integer" unless v.instance_of?(Fixnum)
      end
      attribute(name, :i_enum, options.merge({:values => values}), &block)
    end

    def attribute(name, type, options = {}, &block)
      attribute = Attribute.new(self, name, type, options, &block)
      @attributes << attribute
      attribute
    end

    def constraint(name, options = {}, &block)
      constraint = Constraint.new(name, options, &block)
      @constraints << constraint
      constraint
    end

    def validation(name, options = {}, &block)
      validation = Validation.new(name, options, &block)
      @validations << validation
      validation
    end

    def codependent_constraint(name, attribute_names, options = {}, &block)
      codependent_constraint = AttributeSetConstraint.new(name, attribute_names, options, &block)
      @codependent_constraints << codependent_constraint
      codependent_constraint
    end

    def incompatible_constraint(name, attribute_names, options = {}, &block)
      incompatible_constraint = AttributeSetConstraint.new(name, attribute_names, options, &block)
      @incompatible_constraints << incompatible_constraint
      incompatible_constraint
    end

    def table_name
      schema.in_namespace("tbl#{name}")
    end

    # Assume single column pk
    def primary_key
      attributes.find {|a| a.primary_key? }
    end

    def cluster(attribute_names, options = {})

    end

    def index(name, attribute_names, options = {})

    end

    def java
      @java = Domgen::Java::JavaClass.new(self) unless @java
      @java
    end

    def attribute_by_name(name)
      attributes.find{|a| a.name.to_s == name.to_s}
    end
  end

  class Schema
    attr_reader :name
    attr_reader :object_types

    def initialize(name, options = {}, &block)
      @name = name
      @object_types = []
      options.each_pair do |k, v|
        self.send "#{k}=", v
      end
      yield self if block_given?
    end

    def schema
      self
    end

    attr_writer :database_schema

    def database_schema
      @database_schema ||= self.name
    end

    def in_namespace(element)
      self.database_schema.nil? ? q(element) : "#{q(self.database_schema)}.#{q(element)}"
    end

    def define_object_type(name, options = {}, &block)
      @object_types << ObjectType.new(self, name, options, &block)
    end

    def object_type_by_name(name)
      @object_types.find{|o|o.name.to_s == name.to_s}
    end

    def java
      @java = Domgen::Java::JavaPackage.new(self) unless @java
      @java
    end
  end

  module Generator
    class TemplateMap
      attr_reader :template_name
      attr_reader :output_filename_pattern
      attr_reader :basedir

      def initialize(template_name, output_filename_pattern, basedir)
        @template_name, @output_filename_pattern, @basedir = template_name, output_filename_pattern, basedir
      end

      def generate(basedir, context)
        context_binding = context.send :binding
        output_filename = eval("\"#{output_filename_pattern}\"", context_binding)
        output_filename = File.join(basedir, self.basedir, output_filename)
        result = template.result(context_binding)
        FileUtils.mkdir_p File.dirname(output_filename)
        File.open(output_filename, 'w') do |f|
          f.write(result)
        end
      end

      protected

      def template
        unless @template
          filename = "#{File.dirname(__FILE__)}/templates/#{template_name}.erb"
          @template = ERB.new(IO.read(filename))
        end
        @template
      end
    end
  end
end

# Standard schema keys
#

# Standard type keys
# :table


# Standard attribute keys
# :unique, :primary_key, :nullable, :immutable

schemas = []

schemas << Domgen::Schema.new("core", :database_schema => 'dbo') do |s|

  s.java.package = 'iris.model.core'

  s.define_object_type(:AttributeType, :table => :tblAttributeType, :metadataThatCanChange => true) do |t|
    t.string(:ID, 50, :primary_key => true)
    t.string(:DisplayString, 255, :unique => true)
    t.string(:Code, 50, :unique => true)
    t.string(:UnitOfMeasure, 50, :nullable => true)
    t.i_enum(:DataType, {"STRING" => 1,
                         "TEXT" => 2,
                         "NUMBER" => 3,
                         "DATE" => 4,
                         "CODE_SET_VALUE" => 5,
                         "COMPARABLE_CODE_SET_VALUE" => 6,
                         "CAPABILITY" => 7,
                         "URL" => 8,
                         "BOOLEAN" => 9})
    t.attribute(:IsAsGoodAsCache, "List", :nullable => true, :persistent => false)
    t.attribute(:SubstituteCache, "List", :nullable => true, :persistent => false)

    t.constraint(:DataType, :sql => "DataType IN (1, 2, 3, 4, 5, 6, 7, 8, 9)")
  end

  s.define_object_type(:CodeSetValue) do |t|
    t.string(:ID, 50, :primary_key => true)
    t.string(:DisplayString, 50)
    t.integer(:DisplayRank)
    t.reference(:AttributeType, :immutable => true).reverse(:has_many, :name => 'PossibleValues')
  end

  s.define_object_type(:Attribute) do |t|
    t.string(:ID, 50, :primary_key => true)
    t.integer(:Category)
    t.reference(:AttributeType, :immutable => true)
    t.reference(:CodeSetValue, :nullable => true)
    t.string(:Value, 50, :nullable => true)
    t.string(:ValueDesc, 50, :nullable => true)

    t.codependent_constraint("value", [:Value, :ValueDesc])
    t.incompatible_constraint("value", [:Value, :CodeSetValue])

    t.validation(:PositionIsUnique, :sql => <<SQL)
/*
  Each tblPosition should be associated with 0 or 1 tblActsIn rows.
  Thus each tblPosition is effectively immutable. (Historically this
  has not been true but it is now.)
*/
SELECT Other.PositionID
FROM inserted I, tblActsIn Other
WHERE
  I.ID <> Other.ID AND
	Other.PositionID = I.PositionID
GROUP BY Other.PositionID
HAVING COUNT(*) > 0
SQL
  end
end

require 'erb'

per_schema_mapping = [Domgen::Generator::TemplateMap.new('constraints', '#{schema.name}_constraints.sql', 'sql')]
per_type_mapping = [Domgen::Generator::TemplateMap.new('hibernate_model', '#{object_type.java.fully_qualified_name.gsub(".","/")}.java', 'java')]

per_schema_mapping.each do |template_map|
  schemas.each do |schema|
    template_map.generate('generated',schema)
  end
end

per_type_mapping.each do |template_map|
  schemas.each do |schema|
    schema.object_types.each do |object_type|
      template_map.generate('generated',object_type)
    end
  end
end
