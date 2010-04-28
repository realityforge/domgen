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
  class BaseConfigElement
    def initialize(options = {})
      options.each_pair do |k, v|
        self.send "#{k}=", v
      end
      yield self if block_given?
    end
  end

  module Sql
    class SqlElement < BaseConfigElement
      attr_reader :parent

      def initialize(parent, options = {}, &block)
        @parent = parent
        super(options, &block)
      end
    end

    class SqlSchema < SqlElement
      PREFIX_MAP = {:table => 'tbl', :trigger => 'trg'}

      attr_writer :schema

      def schema
        @schema = 'dbo' unless @schema
        @schema
      end

      def qualify(type, name)
        "#{q(self.schema)}.#{q("#{PREFIX_MAP[type]}#{name}")}"
      end
    end

    class Table < SqlElement
      attr_writer :table_name

      def table_name
        @table_name = parent.schema.sql.qualify(:table,parent.name) unless @table_name
        @table_name
      end
    end

    class Column < SqlElement
      TYPE_MAP = {"string" => "VARCHAR",
                  "integer" => "INT",
                  "boolean" => "BIT",
                  "text" => "TEXT",
                  "i_enum" => "INT"}

      def column_name
        if @column_name.nil?
          if parent.reference?
            @column_name = "#{parent.name}#{parent.referenced_object.primary_key.sql.column_name}"
          else
            @column_name = parent.name
          end
        end
        @column_name
      end

      attr_writer :sql_type

      def sql_type
        unless @java_type
          if :reference == parent.attribute_type
            @java_type = parent.referenced_object.primary_key.sql.sql_type
          else
            @java_type = TYPE_MAP[parent.attribute_type.to_s]
          end
          raise "Unknown type #{parent.attribute_type}" unless @java_type
        end
        @java_type
      end

      attr_writer :identity

      def identity?
        @identity = parent.primary_key? && parent.attribute_type == :integer unless @identity
        !!@identity
      end
    end
  end

  module Java
    class JavaElement < BaseConfigElement
      attr_reader :parent

      def initialize(parent, options = {}, &block)
        @parent = parent
        super(options, &block)
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
                  "boolean" => "java.lang.Boolean",
                  "text" => "java.lang.String",
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
            @java_type = parent.referenced_object.java.classname
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

  class Constraint < BaseConfigElement
    attr_reader :name
    attr_accessor :sql

    def initialize(name, options = {}, &block)
      @name = name
      super(options, &block)
    end
  end

  class Query < BaseConfigElement
    attr_reader :object_type
    attr_reader :name
    attr_accessor :jpql

    def initialize(object_type, name, jpql, options = {}, &block)
      @object_type = object_type
      @name = name
      @jpql = jpql
      super(options, &block)
    end

    def qualified_name
      "#{object_type.name}#{name}"
    end

    attr_writer :query_type

    def query_type
      @query_type = :selector if @query_type.nil? 
      @query_type
    end

    def query_string
      if query_type == :full
        query = jpql
      elsif query_type == :selector
        query = "SELECT O FROM #{object_type.name} O WHERE #{jpql}"
      else
        raise "Unknown query type #{query_type}"
      end
      query.gsub("\n",' ')
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

  class Validation < BaseConfigElement
    attr_reader :name
    attr_accessor :sql

    def initialize(name, options = {}, &block)
      @name = name
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

    def reference?
      self.attribute_type == :reference
    end

    def reverse(relationship, options = {})
      raise "reverse on #{name} is invalid as attribute is not a reference" unless reference?
      raise "Not Implemented!"
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

    attr_reader :references

    def references=(references)
      raise "references on #{name} is invalid as attribute is not a reference" unless reference?
      @references = references
    end

    def referenced_object
      raise "referenced_object on #{name} is invalid as attribute is not a reference" unless reference?
      self.object_type.schema.object_type_by_name(self.references)
    end

    def java
      @java = Domgen::Java::JavaField.new(self) unless @java
      @java
    end

    def sql
      raise "Non persistent attributes should not invoke sql config method" unless persistent?
      @sql = Domgen::Sql::Column.new(self) unless @sql
      @sql
    end

    def self.persistent_types
      [:text, :string, :reference, :boolean, :integer, :i_enum]
    end
  end

  class ObjectType
    attr_reader :schema
    attr_reader :name
    attr_reader :options
    attr_reader :attributes
    attr_reader :constraints
    attr_reader :validations
    attr_reader :queries
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
      @queries = []
      yield self if block_given?
    end

    def object_type
      self
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

    def query(name, jpql, options = {}, &block)
      query = Query.new(self, name, jpql, options, &block)
      @queries << query
      query
    end

    # Assume single column pk
    def primary_key
      attributes.find {|a| a.primary_key? }
    end

    def cluster(attribute_names, options = {})
      raise "Not Implemented!"
    end

    def index(name, attribute_names, options = {})
      raise "Not Implemented!"
    end

    def java
      @java = Domgen::Java::JavaClass.new(self) unless @java
      @java
    end

    def sql
      @sql = Domgen::Sql::Table.new(self) unless @sql
      @sql
    end

    def attribute_by_name(name)
      attributes.find{|a| a.name.to_s == name.to_s}
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
      @object_types << ObjectType.new(self, name, options, &block)
    end

    def object_type_by_name(name)
      object_type = @object_types.find{|o|o.name.to_s == name.to_s}
      raise "Unable to locate object_type #{name}" unless object_type
      object_type
    end

    def java
      @java = Domgen::Java::JavaPackage.new(self) unless @java
      @java
    end

    def sql
      @sql = Domgen::Sql::SqlSchema.new(self) unless @sql
      @sql
    end
  end

  class SchemaSet < BaseConfigElement
    attr_reader :schemas

    def initialize(options = {}, &block)
      @schemas = []
      super(options, &block)
    end

    def schema_set
      self
    end

    def define_schema(name, options = {}, &block)
      @schemas << Domgen::Schema.new(self, name, options, &block)
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
        output_dir = eval("\"#{self.basedir}\"", context_binding)
        output_filename = File.join(basedir, output_dir, output_filename)
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

schema_set = Domgen::SchemaSet.new do |ss|
  ss.define_schema("core") do |s|

  s.java.package = 'epwp.model'
  s.sql.schema = 'dbo'

  s.define_object_type(:CodeSetValue) do |t|
    t.integer(:ID, :primary_key => true)
    t.string(:AttributeName, 255)
    t.string(:Value, 255)
    t.string(:ParentAttributeValue, 255, :nullable => true)

    t.query("ByAttributeName",
            "SELECT C FROM CodeSetValue C WHERE C.AttributeName = :AttributeName",
            :query_type => :full)
    t.query("ByAttributeNameAndParentAttributeValue3", <<JPQL)
AttributeName = :AttributeName AND
ParentAttributeValue = :ParentAttributeValue
JPQL
  end

  s.define_object_type(:FireDistrict) do |t|
    t.integer(:ID, :primary_key => true)
    t.string(:Name, 255)
  end

  s.define_object_type(:User) do |t|
    t.integer(:ID, :primary_key => true)
    t.boolean(:Active)
    t.string(:Password, 40)
    t.string(:Salt, 40)
    t.string(:Email, 255)
    t.string(:FirstName, 100)
    t.string(:LastName, 100)
    t.string(:PreferredName, 100)
  end

  s.define_object_type(:Submission) do |t|
    t.integer(:ID, :primary_key => true)
    t.reference(:User, :immutable => true)
    t.reference(:Submission, :name => 'PriorSubmission', :immutable => true)
    t.string(:Name, 255)
    t.string(:ABN, 255)
    t.text(:Notes)
    t.text(:Comment)
  end

  s.define_object_type(:Location) do |t|
    t.integer(:ID, :primary_key => true)
    t.reference(:Submission, :immutable => true)
    t.boolean(:IsPrimary)
    t.string(:PostalName, 255)
    t.string(:Address, 255)
    t.string(:Town, 100)
    t.string(:State, 30)
    t.string(:Postcode, 8)
    t.string(:Phone, 30)
    t.string(:DX, 30, :nullable => true)
  end

  s.define_object_type(:Backhoe) do |t|
    t.integer(:ID, :primary_key => true)
    t.string(:Registration, 50)
    t.integer(:YearOfManufacture)
    t.string(:BackhoeMake, 100)
    t.string(:BackhoeModel, 100)
    t.integer(:Weight)
    t.integer(:KwRating)
    t.boolean(:Lights)
    t.boolean(:ROPS)
    t.boolean(:OGP)
    t.text(:Comment)
    t.reference(:Resource)
  end

  s.define_object_type(:Resource) do |t|
    t.integer(:ID, :primary_key => true)
    t.reference(:Location, :nullable => true)
  end

  s.define_object_type(:Image) do |t|
    t.integer(:ID, :primary_key => true)
    t.reference(:Resource, :immutable => true)
    t.reference(:Image, :name => 'ParentID', :immutable => true)
    t.string(:ContentType, 20, :immutable => true)
    t.string(:Filename, 100, :immutable => true)
    t.string(:Thumbnail, 100, :immutable => true)
    t.integer(:Size, :immutable => true)
    t.integer(:Width, :immutable => true)
    t.integer(:Height, :immutable => true)
    t.string(:Description, 100, :nullable => true)    
  end

=begin
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
=end
  end
end

require 'erb'

per_schema_set_mapping = [Domgen::Generator::TemplateMap.new('persistence', 'META-INF/persistence.xml', 'resources')]
per_schema_mapping = [Domgen::Generator::TemplateMap.new('constraints', '#{schema.name}_constraints.sql', 'databases/#{schema.name}'),
                      Domgen::Generator::TemplateMap.new('ddl', 'schema.sql', 'databases/#{schema.name}')]
per_type_mapping = [Domgen::Generator::TemplateMap.new('hibernate_model', '#{object_type.java.fully_qualified_name.gsub(".","/")}.java', 'java')]

per_schema_set_mapping.each do |template_map|
  template_map.generate('target/generated', schema_set)
end

per_schema_mapping.each do |template_map|
  schema_set.schemas.each do |schema|
    template_map.generate('target/generated',schema)
  end
end

per_type_mapping.each do |template_map|
  schema_set.schemas.each do |schema|
    schema.object_types.each do |object_type|
      template_map.generate('target/generated',object_type)
    end
  end
end
