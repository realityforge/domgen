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

    class ForeignKey < BaseConfigElement
      attr_reader :table
      attr_accessor :attribute_names
      attr_accessor :referenced_object_type_name
      attr_accessor :referenced_attribute_names

      def initialize(table, attribute_names, referenced_object_type_name, referenced_attribute_names, options, &block)
        @table, @attribute_names, @referenced_object_type_name, @referenced_attribute_names =
          table, attribute_names, referenced_object_type_name, referenced_attribute_names
        super(options, &block)
        # Ensure that the attributes exist
        attribute_names.each{|a|table.parent.attribute_by_name(a)}
        # Ensure that the remote attributes exist on remote type
        referenced_attribute_names.each{|a|referenced_object_type.attribute_by_name(a)}
      end

      attr_writer :name

      def name
        if @name.nil?
          @name = "#{attribute_names.join('_')}"
        end
        @name
      end

      def referenced_object_type
        if @referenced_object_type.nil?
          @referenced_object_type = table.parent.schema.object_type_by_name(referenced_object_type_name)
        end
        @referenced_object_type
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

      def initialize(parent, options = {}, &block)
        @indexes = Domgen::OrderedHash.new
        @constraints = Domgen::OrderedHash.new
        @validations = Domgen::OrderedHash.new
        @foreign_keys = Domgen::OrderedHash.new
        super(parent, options, &block)
      end

      def table_name
        @table_name = sql_name(:table,parent.name) unless @table_name
        @table_name
      end

      def constraints
        @constraints.values
      end

      def constraint(name, options = {}, &block)
        raise "Constraint named #{name} already defined on table #{table_name}" if @constraints[name.to_s]
        constraint = Constraint.new(self, name, options, &block)
        @constraints[name.to_s] = constraint
        constraint
      end

      def validations
        @validations.values
      end

      def validation(name, options = {}, &block)
        raise "Validation named #{name} already defined on table #{table_name}" if @validations[name.to_s]
        validation = Validation.new(self, name, options, &block)
        @validations[name.to_s] = validation
        validation
      end

      def cluster(attribute_names, options = {}, &block)
        index(attribute_names, options.merge(:cluster => true), &block)
      end

      def indexes
        @indexes.values
      end

      def index(attribute_names, options = {}, &block)
        index = Index.new(self, attribute_names, options, &block)
        raise "Index named #{name} already defined on table #{table_name}" if @indexes[index.name]
        @indexes[index.name] = index
        index
      end

      def foreign_keys
        @foreign_keys.values
      end

      def foreign_key(attribute_names, referrenced_object_type_name, referrenced_attribute_names, options = {}, &block)
        foreign_key = ForeignKey.new(self, attribute_names, referrenced_object_type_name, referrenced_attribute_names, options, &block)
        raise "Foreign Key named #{foreign_key.name} already defined on table #{table_name}" if @indexes[foreign_key.name]
        @foreign_keys[foreign_key.name] = foreign_key
        foreign_key
      end

      def pre_verify
        parent.unique_constraints.each do |c|
          index(c.attribute_names, {:unique => true})
        end
        parent.codependent_constraints.each do |c|
          constraint("#{parent.name}_#{c.name}_CoDep", :sql => <<SQL)
( #{c.attribute_names.collect { |name| "#{parent.attribute_by_name(name).sql.column_name} IS NOT NULL" }.join(" AND ")} ) OR
( #{c.attribute_names.collect { |name| "#{parent.attribute_by_name(name).sql.column_name} IS NULL" }.join(" AND ") } )
SQL
        end
        parent.dependency_constraints.each do |c|
          constraint("#{parent.name}_#{c.name}_Dep", :sql => <<SQL)
#{parent.attribute_by_name(c.attribute_name).sql.column_name} IS NULL OR
( #{c.dependent_attribute_names.collect { |name| "#{parent.attribute_by_name(name).sql.column_name} IS NOT NULL" }.join(" AND ") } )
SQL
        end
        parent.incompatible_constraints.each do |c|
          sql = (0..(c.attribute_names.size)).collect do |i|
            candidate = c.attribute_names[i]
            str = c.attribute_names.collect { |name| "#{parent.attribute_by_name(name).sql.column_name} IS#{(candidate == name) ? ' NOT' : ''} NULL" }.join(' AND ')
            "(#{str})"
          end.join(" OR ")
          constraint("#{parent.name}_#{c.name}_Incompat", :sql => sql)
        end

        parent.declared_attributes.select {|a| a.attribute_type == :i_enum }.each do |a|
          sorted_values = a.values.values.sort
          constraint("#{a.name}_Enum", :sql => <<SQL)
#{a.sql.column_name} >= #{sorted_values[0]} AND
#{a.sql.column_name} <= #{sorted_values[sorted_values.size - 1]}
SQL
        end
        parent.declared_attributes.select {|a| a.attribute_type == :s_enum }.each do |a|
          constraint("#{a.name}_Enum", :sql => <<SQL)
#{a.sql.column_name} IN (#{a.values.values.collect{|v|"'#{v}'"}.join(',')})
SQL
        end

        parent.scope_constraints.each do |c|
          target_attribute = parent.attribute_by_name(c.attribute_name)
          target_object_type = parent.attribute_by_name(c.attribute_name).referenced_object
          scoping_attribute = target_object_type.attribute_by_name(c.scoping_attribute)

          attribute_name_path = c.attribute_name_path
          object_path = []

          object_type = parent
          attribute_name_path.each do |attribute_name_path_element|
            object_path << object_type
            other = object_type.attribute_by_name(attribute_name_path_element)
            object_type = other.referenced_object
          end

          joins = []
          next_id = "I.#{target_attribute.sql.column_name}"
          last_name = "I"
          attribute_name_path.each_with_index do |attribute_name, index|
            ot = object_path[index]
            name = "C#{index}"
            if index != 0
              joins << "JOIN #{ot.sql.table_name} #{name} ON #{last_name}.#{object_path[index - 1].attribute_by_name(attribute_name_path[index - 1]).sql.column_name} = #{name}.#{ot.primary_key.sql.column_name}"
              last_name = name
            end
            next_id = "#{last_name}.#{ot.attribute_by_name(attribute_name).sql.column_name}"
          end

          validation("#{c.name}_Scope", :sql => <<SQL)

SELECT I.#{parent.attribute_by_name(c.attribute_name).sql.column_name}
FROM
  inserted I
JOIN #{target_object_type.sql.table_name} C0 ON C0.#{target_object_type.primary_key.sql.column_name} = I.#{parent.attribute_by_name(c.attribute_name).sql.column_name}
#{joins.join("\n")}
WHERE C0.#{scoping_attribute.sql.column_name} != #{next_id}
GROUP BY I.#{parent.attribute_by_name(c.attribute_name).sql.column_name}
HAVING COUNT(*) > 0
SQL
        end

        parent.declared_attributes.select {|a| a.persistent? && a.reference? && !a.abstract? && a.referenced_object.final? }.each do |a|
          foreign_key([a.name], a.referenced_object.name, [a.referenced_object.primary_key.name] )
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
