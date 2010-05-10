module Domgen
  module Sql
    class SqlElement < BaseConfigElement
      attr_reader :parent

      def initialize(parent, options = {}, &block)
        @parent = parent
        super(options, &block)
      end
    end

    class SqlSchema < SqlElement
      DEFAULT_SCHEMA = 'dbo'

      attr_writer :schema

      def schema
        @schema = DEFAULT_SCHEMA unless @schema
        @schema
      end

      def default_schema?
        DEFAULT_SCHEMA == schema
      end
    end

    class Index < BaseConfigElement
      attr_reader :table
      attr_accessor :attribute_names

      def initialize(table, attribute_names, options, &block)
        @table, @attribute_names = table, attribute_names
        super(options, &block)
      end

      attr_writer :name

      def name
        if @name.nil?
          prefix = cluster? ? 'CL' : unique? ? 'UQ' : 'IX'
          suffix = attribute_names.join('_')
          @name = "#{prefix}_#{table.parent.name}_#{suffix}"
        end
        @name
      end

      attr_writer :cluster

      def cluster?
        @cluster = false if @cluster.nil?
        @cluster
      end

      attr_writer :unique

      def unique?
        @unique = false if @unique.nil?
        @unique
      end
    end

    class Constraint < SqlElement
      attr_reader :name
      attr_accessor :sql

      def initialize(parent, name, options = {}, &block)
        @name = name
        super(parent, options, &block)
      end
    end

    class Validation < SqlElement
      attr_reader :name
      attr_accessor :sql

      def initialize(parent, name, options = {}, &block)
        @name = name
        super(parent, options, &block)
      end
    end

    class Table < SqlElement
      attr_writer :table_name

      def table_name
        @table_name = sql_name(:table,parent.name) unless @table_name
        @table_name
      end

      def constraints
        @constraints ||= []
      end

      def constraint(name, options = {}, &block)
        constraint = Constraint.new(self, name, options, &block)
        self.constraints << constraint
        constraint
      end

      def validations
        @validations ||= []
      end

      def validation(name, options = {}, &block)
        validation = Validation.new(self, name, options, &block)
        self.validations << validation
        validation
      end      

      def cluster(attribute_names, options = {}, &block)
        index(attribute_names, options.merge(:cluster => true), &block)
      end

      def index(attribute_names, options = {}, &block)
        index = Index.new(self, attribute_names, options, &block)
        indexes << index
        index
      end

      def indexes
        @indexes ||= []
      end

      def post_create
        parent.unique_constraints.each do |u|
          index(u.attribute_names, {:unique => true})
        end

        parent.attributes.select {|a| a.attribute_type == :i_enum }.each do |a|
          sorted_values = a.values.values.sort
          constraint(a.name, :sql => <<SQL)
#{a.sql.column_name} >= #{sorted_values[0]} AND
#{a.sql.column_name} <= #{sorted_values[sorted_values.size - 1]}
SQL
        end
        parent.attributes.select {|a| a.attribute_type == :S_enum }.each do |a|
          constraint(a.name, :sql => <<SQL)
#{a.sql.column_name} IN (#{a.values.values.collect{|v|"'#{v}'"}.join(',')})
SQL
        end
        raise "#{table_name} defines multiple clustering indexes" if indexes.select{|i| i.cluster?}.size > 1
      end
    end

    class Column < SqlElement
      TYPE_MAP = {"string" => "VARCHAR",
                  "integer" => "INT",
                  "datetime" => "DATETIME",
                  "boolean" => "BIT",
                  "text" => "TEXT",
                  "i_enum" => "INT",
                  "s_enum" => "VARCHAR"}

      def column_name
        if @column_name.nil?
          if parent.reference?
            @column_name = parent.referencing_link_name
          else
            @column_name = parent.name
          end
        end
        @column_name
      end

      attr_writer :sql_type

      def sql_type
        unless @sql_type
          if :reference == parent.attribute_type
            @sql_type = parent.referenced_object.primary_key.sql.sql_type
          else
            @sql_type = q(TYPE_MAP[parent.attribute_type.to_s]) + (parent.length.nil? ? '' : "(#{parent.length})")
          end
          raise "Unknown type #{parent.attribute_type}" unless @sql_type
        end
        @sql_type
      end

      attr_writer :identity

      def identity?
        @identity = parent.generated_value? unless @identity
        @identity
      end
    end
  end

  class Attribute
    def sql
      raise "Non persistent attributes should not invoke sql config method" unless persistent?
      @sql = Domgen::Sql::Column.new(self) unless @sql
      @sql
    end
  end

  class ObjectType
    self.extensions << :sql
    def sql
      @sql = Domgen::Sql::Table.new(self) unless @sql
      @sql
    end
  end

  class Schema
    def sql
      @sql = Domgen::Sql::SqlSchema.new(self) unless @sql
      @sql
    end
  end
end
