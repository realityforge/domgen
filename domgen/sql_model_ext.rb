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
        @table_name = parent.schema.sql.qualify(:table,parent.name) unless @table_name
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
        # Add unique indexes on all unique attributes unless covered by existing index
        parent.attributes.each do |a|
          if a.unique?
            existing_index = indexes.find do |i|
              i.unique? && i.attribute_names.length == 1 && i.attribute_names[0].to_s = a.name.to_s
            end
            index([a.name], {:unique => true}) if existing_index.nil?
          end
        end

        raise "#{table_name} defines multiple clustering indexes" if indexes.select{|i| i.cluster?}.size > 1
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
        unless @sql_type
          if :reference == parent.attribute_type
            @sql_type = parent.referenced_object.primary_key.sql.sql_type
          else
            @sql_type = TYPE_MAP[parent.attribute_type.to_s]
          end
          raise "Unknown type #{parent.attribute_type}" unless @sql_type
        end
        @sql_type
      end

      attr_writer :identity

      def identity?
        @identity = parent.primary_key? && parent.attribute_type == :integer unless @identity
        !!@identity
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
