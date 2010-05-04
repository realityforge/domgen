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

def pluralize(string)
  "#{string}s"
end

def underscore(camel_cased_word)
  camel_cased_word.to_s.gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
          gsub(/([a-z\d])([A-Z])/, '\1_\2').
          tr("-", "_").
          downcase
end

def java_accessors(name,type)
  <<JAVA
  public #{type} get#{name}()
  {
     return #{name};
  }

  public void set#{name}( final #{type} value )
  {
     #{name} = value;
  }
JAVA
end

module Domgen
  class BaseConfigElement
    def initialize(options = {})
      options.each_pair do |k, v|
        self.send "#{k}=", v
      end
      yield self if block_given?
      extension_point(:post_create)
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
    attr_reader :attributes
    attr_reader :validations
    attr_reader :queries
    attr_reader :codependent_constraints
    attr_reader :incompatible_constraints
    attr_reader :referencing_attributes

    def initialize(schema, name, options = {}, &block)
      @schema, @name = schema, name
      @attributes = []
      @validations = []
      @codependent_constraints = []
      @incompatible_constraints = []
      @queries = []
      @referencing_attributes = []
      super(options, &block)
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

    # Assume single column pk
    def primary_key
      attributes.find {|a| a.primary_key? }
    end

    def attribute_by_name(name)
      attribute = attributes.find{|a| a.name.to_s == name.to_s}
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
      @object_types << ObjectType.new(self, name, options, &block)
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

  module Generator
    DEFAULT_ARTIFACTS = [:jpa, :active_record, :sql]

    def self.generate(schema_set, directory, artifacts = nil)
      artifacts = DEFAULT_ARTIFACTS unless artifacts
      template_set = TemplateSet.new

      artifacts.each do |artifact|
        method_name = "define_#{artifact}_templates".to_sym
        if self.respond_to? method_name
          self.send method_name, template_set
        end
      end

      template_set.per_schema_set.each do |template_map|
        template_map.generate(directory, schema_set)
      end

      template_set.per_schema.each do |template_map|
        schema_set.schemas.each do |schema|
          template_map.generate(directory, schema)
        end
      end

      template_set.per_object_type.each do |template_map|
        schema_set.schemas.each do |schema|
          schema.object_types.each do |object_type|
            template_map.generate(directory, object_type)
          end
        end
      end
    end

    def self.define_jpa_templates(template_set)
      template_set.per_schema_set << Template.new('jpa/persistence', 'META-INF/persistence.xml', 'resources')
      template_set.per_schema << Template.new('jpa/entity_manager',
                                              '#{schema.java.package.gsub(".","/")}/SchemaEntityManager.java',
                                              'java')
      template_set.per_object_type << Template.new('jpa/model',
                                                   '#{object_type.java.fully_qualified_name.gsub(".","/")}.java',
                                                   'java')
      template_set.per_object_type << Template.new('jpa/dao',
                                                   '#{object_type.java.fully_qualified_name.gsub(".","/")}DAO.java',
                                                   'java')
    end

    def self.define_sql_templates(template_set)
      template_set.per_schema << Template.new('sql/ddl', 'schema.sql', 'databases/#{schema.name}')
      template_set.per_schema << Template.new('sql/constraints', '#{schema.name}_constraints.sql', 'databases/#{schema.name}')
    end

    def self.define_active_record_templates(template_set)
      template_set.per_object_type << Template.new('ar/model', '#{object_type.ruby.filename}.rb', 'ruby')
    end

    class TemplateSet
      attr_accessor :per_schema_set
      attr_accessor :per_schema
      attr_accessor :per_object_type

      def initialize
        self.per_schema_set = []
        self.per_schema = []
        self.per_object_type = []
      end
    end

    class Template
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
        result = erb_instance.result(context_binding)
        FileUtils.mkdir_p File.dirname(output_filename)
        File.open(output_filename, 'w') { |f| f.write(result) }
      end

      protected

      def erb_instance
        unless @template
          filename = "#{File.dirname(__FILE__)}/templates/#{template_name}.erb"
          @template = ERB.new(IO.read(filename))
        end
        @template
      end
    end
  end
end

require "#{File.dirname(__FILE__)}/java_model_ext.rb"
require "#{File.dirname(__FILE__)}/ruby_model_ext.rb"
require "#{File.dirname(__FILE__)}/sql_model_ext.rb"
require "#{File.dirname(__FILE__)}/jpa_model_ext.rb"
