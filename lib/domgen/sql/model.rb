#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Domgen::TypeDB.config_element(:"sql.mssql") do
  attr_accessor :sql_type
end

Domgen::TypeDB.config_element(:"sql.pgsql") do
  attr_accessor :sql_type
end

Domgen::TypeDB.enhance(:integer, 'sql.mssql.sql_type' => 'INT', 'sql.pgsql.sql_type' => 'integer')
Domgen::TypeDB.enhance(:real, 'sql.mssql.sql_type' => 'FLOAT', 'sql.pgsql.sql_type' => 'double precision')
Domgen::TypeDB.enhance(:date, 'sql.mssql.sql_type' => 'DATE', 'sql.pgsql.sql_type' => 'date')
Domgen::TypeDB.enhance(:datetime, 'sql.mssql.sql_type' => 'DATETIME', 'sql.pgsql.sql_type' => 'timestamp')
Domgen::TypeDB.enhance(:boolean, 'sql.mssql.sql_type' => 'BIT', 'sql.pgsql.sql_type' => 'boolean')

Domgen::TypeDB.enhance(:point, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'POINT')
Domgen::TypeDB.enhance(:multipoint, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'MULTIPOINT')
Domgen::TypeDB.enhance(:linestring, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'LINESTRING')
Domgen::TypeDB.enhance(:multilinestring, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'MULTILINESTRING')
Domgen::TypeDB.enhance(:polygon, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'POLYGON')
Domgen::TypeDB.enhance(:multipolygon, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'MULTIPOLYGON')
Domgen::TypeDB.enhance(:geometry, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:pointm, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'POINTM')
Domgen::TypeDB.enhance(:multipointm, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'MULTIPOINTM')
Domgen::TypeDB.enhance(:linestringm, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'LINESTRINGM')
Domgen::TypeDB.enhance(:multilinestringm, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'MULTILINESTRINGM')
Domgen::TypeDB.enhance(:polygonm, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'POLYGONM')
Domgen::TypeDB.enhance(:multipolygonm, 'sql.mssql.sql_type' => 'GEOMETRY', 'sql.pgsql.sql_type' => 'MULTIPOLYGONM')

module Domgen
  module Sql
    class PgDialect
      # Quote identifier
      def quote(column_name)
        "\"#{column_name}\""
      end

      def quote_string(string)
        string.gsub("\'","''")
      end

      def disallow_blank_constraint(column_name)
        "char_length(trim(both from #{quote(column_name)} )) > 0"
      end

      def column_type(column)
        if column.calculation
          Domgen.error("Unsupported column type - calculation")
        elsif column.attribute.reference?
          return column.attribute.referenced_entity.primary_key.sql.sql_type
        elsif column.attribute.text?
          if column.attribute.length.nil?
            return "text"
          else
            return "varchar(#{column.attribute.length})"
          end
        elsif column.attribute.geometry?
          spatial_reference_id = column.attribute.geometry.srid || -1
          if column.attribute.geometry.geometry_type == :geometry
            return "GEOMETRY"
          else
            return "GEOMETRY(#{column.attribute.geometry.geometry_type},#{spatial_reference_id})"
          end
        elsif column.attribute.enumeration?
          column.attribute.enumeration.textual_values? ? "varchar(#{column.attribute.length})" : "integer"
        else
          return column.attribute.characteristic_type.sql.pgsql.sql_type
        end
      end

      def post_verify_table_customization(table)
        table.entity.attributes.select{ |a| a.sql? && a.geometry? }.each do |a|
          constraint_name = "#{a.name}_ValidGeometry"
          table.constraint(constraint_name, :sql => "ST_IsValid(#{quote(a.sql.column_name)})" ) unless table.constraint_by_name(constraint_name)

          if a.geometry.geometry_type == :geometry
            if a.geometry.dimensions
              constraint_name = "#{a.name}_ValidDimensions"
              table.constraint(constraint_name, :sql => "ST_ndims(#{quote(a.sql.column_name)}) = #{a.geometry.dimensions}") unless table.constraint_by_name(constraint_name)
            end
            if a.geometry.srid
              constraint_name = "#{a.name}_ValidSpatialReferenceID"
              table.constraint(constraint_name, :sql => "ST_srid(#{quote(a.sql.column_name)}) = #{a.geometry.srid}") unless table.constraint_by_name(constraint_name)
            end
          end
        end
      end
    end

    class MssqlDialect
      def quote(column_name)
        "[#{column_name}]"
      end

      def quote_string(string)
        string.gsub("\'","''")
      end

      def disallow_blank_constraint(column_name)
        "LEN( #{quote(column_name)} ) > 0"
      end

      def column_type(column)
        if column.calculation
          sql_type = "AS #{@calculation}"
          if column.persistent_calculation?
            sql_type += " PERSISTED"
          end
          return sql_type
        elsif :reference == column.attribute.attribute_type
          return column.attribute.referenced_entity.primary_key.sql.sql_type
        elsif column.attribute.attribute_type.to_s == 'text'
          if column.attribute.length.nil?
            return "[VARCHAR](MAX)"
          else
            return "[VARCHAR](#{column.attribute.length})"
          end
        elsif column.attribute.enumeration?
          column.attribute.enumeration.textual_values? ? "VARCHAR(#{column.attribute.length})" : "INT"
        else
          return quote(column.attribute.characteristic_type.sql.mssql.sql_type)
        end
      end

      def post_verify_table_customization(table)
        table.entity.attributes.select{ |a| a.sql? && a.geometry? }.each do |a|
          constraint_name = "#{a.name}_ValidGeometry"
          table.constraint(constraint_name, :sql => "#{quote(a.sql.column_name)}.STIsValid() = 1" ) unless table.constraint_by_name(constraint_name)

          if a.geometry.geometry_type != :geometry
            label = {
              :point => 'Point',
              :multipoint => 'MultiPoint',
              :linestring => 'LineString',
              :multilinestring => 'MultiLineString',
              :polygon => 'Polygon',
              :multipolygon => 'MultiPolygon',
            }[a.geometry.geometry_type]

            constraint_name = "#{a.name}_CorrectType"
            table.constraint(constraint_name, :sql => "#{quote(a.sql.column_name)}.STGeometryType() = '#{label}'") unless table.constraint_by_name(constraint_name)
          end

          if a.geometry.dimensions
            constraint_name = "#{a.name}_ValidDimensions"
            constraint =
              if 2 == a.geometry.dimensions
                "#{quote(a.sql.column_name)}.HasZ = 0 AND #{quote(a.sql.column_name)}.HasM = 0"
              elsif 3 == a.geometry.dimensions
                "#{quote(a.sql.column_name)}.HasZ = 1 AND #{quote(a.sql.column_name)}.HasM = 0"
              else
                "#{quote(a.sql.column_name)}.HasZ = 1 AND #{quote(a.sql.column_name)}.HasM = 1"
              end
            table.constraint(constraint_name, :sql => constraint) unless table.constraint_by_name(constraint_name)
          end
          if a.geometry.srid
            constraint_name = "#{a.name}_ValidSpatialReferenceID"
            table.constraint(constraint_name, :sql => "#{quote(a.sql.column_name)}.STSrid = #{a.geometry.srid}") unless table.constraint_by_name(constraint_name)
          end
        end
      end
    end

    @@dialect = nil

    def self.dialect
      @@dialect ||= MssqlDialect.new
    end

    def self.dialect=(dialect)
      @@dialect = dialect.new
    end

    class SqlSchema < Domgen.ParentedElement(:data_module)
      attr_writer :schema

      def schema
        @schema || data_module.name
      end

      def quoted_schema
        Domgen::Sql.dialect.quote(self.schema)
      end
    end

    class Index < Domgen.ParentedElement(:table)
      attr_accessor :attribute_names
      attr_accessor :include_attribute_names
      attr_accessor :filter

      def initialize(table, attribute_names, options, &block)
        @attribute_names = attribute_names
        @include_attribute_names = []
        super(table, options, &block)
      end

      def to_s
        "Index[#{self.qualified_index_name}]"
      end

      attr_reader :index_type

      def index_type=(index_type)
        Domgen.error("index_type #{index_type} on #{qualified_index_name} is invalid") unless self.class.valid_index_types.include?(index_type)
        @index_type = index_type
      end

      attr_writer :index_name

      def index_name
        if @index_name.nil?
          prefix = cluster? ? 'CL' : unique? ? 'UQ' : gist? ? 'GS' : 'IX'
          suffix = attribute_names.join('_')
          @index_name = "#{prefix}_#{table.entity.name}_#{suffix}"
        end
        @index_name
      end

      def quoted_index_name
        Domgen::Sql.dialect.quote(self.index_name)
      end

      def qualified_index_name
        "#{table.entity.data_module.sql.quoted_schema}.#{quoted_index_name}"
      end

      def ordered?
        !gist?
      end

      def cluster?
        index_type == :cluster
      end

      def gist?
        index_type == :gist
      end

      def normal?
        index_type == :normal
      end

      attr_writer :unique

      def unique?
        @unique.nil? ? false : @unique
      end

      def partial?
        !self.filter.nil?
      end

      private

      def self.valid_index_types
        [:cluster, :gist, :normal]
      end
    end

    class ForeignKey < Domgen.ParentedElement(:table)
      ACTION_MAP =
        {
          :cascade => "CASCADE",
          :restrict => "RESTRICT",
          :set_null => "SET NULL",
          :set_default => "SET DEFAULT",
          :no_action => "NO ACTION"
        }.freeze

      attr_accessor :attribute_names
      attr_accessor :referenced_entity_name
      attr_accessor :referenced_attribute_names

      def initialize(table, attribute_names, referenced_entity_name, referenced_attribute_names, options, &block)
        @attribute_names, @referenced_entity_name, @referenced_attribute_names =
          attribute_names, referenced_entity_name, referenced_attribute_names
        super(table, options, &block)
        # Ensure that the attributes exist
        attribute_names.each { |a| table.entity.attribute_by_name(a) }
        # Ensure that the remote attributes exist on remote type
        referenced_attribute_names.each { |a| referenced_entity.attribute_by_name(a) }
      end

      attr_writer :name

      def name
        if @name.nil?
          @name = "#{attribute_names.join('_')}"
        end
        @name
      end

      def referenced_entity
        table.entity.data_module.entity_by_name(referenced_entity_name)
      end

      def on_update=(on_update)
        Domgen.error("on_update #{on_update} on #{name} is invalid") unless ACTION_MAP.keys.include?(on_update)
        @on_update = on_update
      end

      def on_update
        @on_update || :no_action
      end

      def on_delete=(on_delete)
        Domgen.error("on_delete #{on_delete} on #{name} is invalid") unless ACTION_MAP.keys.include?(on_delete)
        @on_delete = on_delete
      end

      def on_delete
        @on_delete || :no_action
      end

      def foreign_key_name
        "FK_#{s(table.entity.name)}_#{s(name)}"
      end

      def quoted_foreign_key_name
        Domgen::Sql.dialect.quote(self.foreign_key_name)
      end

      def qualified_foreign_key_name
        "#{table.entity.data_module.sql.quoted_schema}.#{quoted_foreign_key_name}"
      end

      def constraint_name
        foreign_key_name
      end

      def quoted_constraint_name
        quoted_foreign_key_name
      end

      def to_s
        "ForeignKey[#{self.qualified_foreign_key_name}]"
      end
    end

    class Constraint < Domgen.ParentedElement(:table)
      attr_reader :name
      attr_accessor :sql

      def initialize(table, name, options = {}, &block)
        @name = name
        super(table, options, &block)
      end

      attr_writer :invariant

      # Return true if this constraint should always be true, not just on insert or update.
      def invariant?
        @invariant.nil? ? true : @invariant
      end

      def constraint_name
        "CK_#{s(table.entity.name)}_#{s(name)}"
      end

      def quoted_constraint_name
        Domgen::Sql.dialect.quote(self.constraint_name)
      end

      def qualified_constraint_name
        "#{table.entity.data_module.sql.quoted_schema}.#{self.quoted_constraint_name}"
      end

      def to_s
        "Constraint[#{self.qualified_constraint_name}]"
      end

      def constraint_sql
        @sql
      end
    end

    class FunctionConstraint < Domgen.ParentedElement(:table)
      attr_reader :name
      # The SQL that is part of function invoked
      attr_accessor :positive_sql
      attr_accessor :parameters
      attr_accessor :common_table_expression
      attr_accessor :or_conditions

      def initialize(table, name, parameters, options = {}, & block)
        @name = name
        @parameters = parameters
        @or_conditions = []
        super(table, options, & block)
      end

      attr_writer :invariant

      # Return true if this constraint should always be true, not just on insert or update.
      def invariant?
        @invariant.nil? ? true : @invariant
      end

      def constraint_name
        "CK_#{s(table.entity.name)}_#{s(name)}"
      end

      def quoted_constraint_name
        Domgen::Sql.dialect.quote(self.constraint_name)
      end

      def qualified_constraint_name
        "#{table.entity.data_module.sql.quoted_schema}.#{self.quoted_constraint_name}"
      end

      def function_name
        "#{table.entity.name}_#{name}"
      end

      def quoted_function_name
        Domgen::Sql.dialect.quote(self.function_name)
      end

      def qualified_function_name
        "#{table.entity.data_module.sql.quoted_schema}.#{self.quoted_function_name}"
      end

      # The SQL generated in constraint
      def constraint_sql
        parameter_string = parameters.collect{|parameter_name| "  #{table.entity.attribute_by_name(parameter_name).sql.column_name}"}.join(",")
        function_call = "#{self.qualified_function_name}(#{parameter_string}) = 1"
        (self.or_conditions + [function_call]).join(" OR ")
      end

      def to_s
        "FunctionConstraint[#{self.qualified_constraint_name}]"
      end
    end

    class SequencedSqlElement < Domgen.ParentedElement(:table)
      VALID_AFTER = [:insert, :update, :delete]

      attr_reader :name
      attr_reader :after
      attr_reader :instead_of

      def initialize(table, name, options = {}, & block)
        @name = name
        @after = [:insert, :update]
        @instead_of = []
        super(table, options, & block)
      end

      def after=(after)
        @after = scope("after", after)
      end

      def instead_of=(instead_of)
        @instead_of = scope("instead_of", instead_of)
      end

      private

      def scope(label, scope)
        if scope.nil?
          scope = []
        elsif !scope.is_a?(Array)
          scope = [scope]
        end
        scope.each do |a|
          Domgen.error("Unknown #{label} specififier #{a}") unless VALID_AFTER.include?(a)
        end
        scope
      end
    end

    class Validation < SequencedSqlElement
      attr_accessor :negative_sql
      attr_accessor :invariant_negative_sql
      attr_accessor :common_table_expression
      attr_accessor :guard
      attr_writer :priority

      def priority
        @priority || 1
      end

      def to_s
        "Validation[#{self.name}]"
      end
    end

    class Action < SequencedSqlElement
      attr_accessor :sql
      attr_accessor :guard
      attr_writer :priority

      def priority
        @priority || 1
      end

      def to_s
        "Action[#{self.name}]"
      end
    end

    class Trigger < SequencedSqlElement
      attr_accessor :sql

      def trigger_name
        @trigger_name ||= sql_name(:trigger, "#{table.entity.name}#{self.name}")
      end

      def quoted_trigger_name
        Domgen::Sql.dialect.quote(self.trigger_name)
      end

      def qualified_trigger_name
        "#{table.entity.data_module.sql.quoted_schema}.#{self.quoted_trigger_name}"
      end

      def to_s
        "Action[#{self.qualified_trigger_name}]"
      end
    end

    class Table < Domgen.ParentedElement(:entity)
      attr_writer :table_name
      attr_accessor :partition_scheme

      #+force_overflow_for_large_objects+ if set to true will force the native *VARCHAR(max) and XML datatypes (i.e.
      # text attributes to always be stored in overflow page by database engine. Otherwise they will be stored inline
      # as long as the data fits into a 8,060 byte row. It is a performance hit to access the overflow table so this
      # should be set to false unless the data columns are infrequently accessed relative to the other columns
      # TODO: MSSQL Specific
      attr_accessor :force_overflow_for_large_objects

      def initialize(entity, options = {}, &block)
        @indexes = Domgen::OrderedHash.new
        @constraints = Domgen::OrderedHash.new
        @function_constraints = Domgen::OrderedHash.new
        @validations = Domgen::OrderedHash.new
        @actions = Domgen::OrderedHash.new
        @triggers = Domgen::OrderedHash.new
        @foreign_keys = Domgen::OrderedHash.new
        super(entity, options, &block)
      end

      def table_name
        @table_name ||= sql_name(:table, entity.name)
      end

      def quoted_table_name
        Domgen::Sql.dialect.quote(table_name)
      end

      def qualified_table_name
        "#{entity.data_module.sql.quoted_schema}.#{quoted_table_name}"
      end

      def constraints
        @constraints.values
      end

      def constraint_by_name(name)
        @constraints[name.to_s]
      end

      def constraint(name, options = {}, &block)
        existing = constraint_by_name(name)
        Domgen.error("Constraint named #{name} already defined on table #{qualified_table_name}") if existing
        constraint = Constraint.new(self, name, options, &block)
        @constraints[name.to_s] = constraint
        constraint
      end

      def function_constraints
        @function_constraints.values
      end

      def function_constraint_by_name(name)
        @function_constraints[name.to_s]
      end

      def function_constraint(name, parameters, options = {}, &block)
        existing = function_constraint_by_name(name)
        Domgen.error("Function Constraint named #{name} already defined on table #{qualified_table_name}") if existing
        function_constraint = FunctionConstraint.new(self, name, parameters, options, &block)
        @function_constraints[name.to_s] = function_constraint
        function_constraint
      end

      def validations
        @validations.values
      end

      def validation_by_name(name)
        @validations[name.to_s]
      end

      def validation(name, options = {}, &block)
        existing = validation_by_name(name)
        Domgen.error("Validation named #{name} already defined on table #{qualified_table_name}") if existing
        validation = Validation.new(self, name, options, &block)
        @validations[name.to_s] = validation
        validation
      end

      def actions
        @actions.values
      end

      def action_by_name(name)
        @actions[name.to_s]
      end

      def action(name, options = {}, &block)
        existing = action_by_name(name)
        Domgen.error("Action named #{name} already defined on table #{qualified_table_name}") if existing
        action = Action.new(self, name, options, &block)
        @actions[name.to_s] = action
        action
      end

      def triggers
        @triggers.values
      end

      def trigger_by_name(name)
        @triggers[name.to_s]
      end

      def trigger(name, options = {}, &block)
        existing = trigger_by_name(name)
        Domgen.error("Trigger named #{name} already defined on table #{qualified_table_name}") if existing
        trigger = Trigger.new(self, name, options, &block)
        @triggers[name.to_s] = trigger
        trigger
      end

      def cluster(attribute_names, options = {}, &block)
        index(attribute_names, options.merge(:index_type => :cluster), &block)
      end

      def indexes
        @indexes.values
      end

      def index(attribute_names, options = {}, skip_if_present = false, &block)
        index = Index.new(self, attribute_names, options, &block)
        return if @indexes[index.index_name] && skip_if_present
        Domgen.error("Index named #{index.index_name} already defined on table #{qualified_table_name}") if @indexes[index.index_name]
        @indexes[index.index_name] = index
        index
      end

      def foreign_keys
        @foreign_keys.values
      end

      def foreign_key(attribute_names, referenced_entity_name, referenced_attribute_names, options = {}, skip_if_present = false, &block)
        foreign_key = ForeignKey.new(self, attribute_names, referenced_entity_name, referenced_attribute_names, options, &block)
        return if @indexes[foreign_key.name] && skip_if_present
        Domgen.error("Foreign Key named #{foreign_key.name} already defined on table #{table_name}") if @indexes[foreign_key.name]
        @foreign_keys[foreign_key.name] = foreign_key
        foreign_key
      end

      def post_verify
        if self.partition_scheme && indexes.select{|index|index.cluster?}.empty?
          Domgen.error("Must specify a clustered index if using a partition scheme")
        end

        self.indexes.each do |index|
          if index.cluster? && index.partial?
            Domgen.error("Must not specify a partial clustered index. Index = #{index.qualified_index_name}")
          end
        end

        if indexes.select { |i| i.cluster? }.size > 1
          Domgen.error("#{qualified_table_name} defines multiple clustering indexes")
        end

        entity.unique_constraints.each do |c|
          index(c.attribute_names, {:unique => true}, true)
        end

        entity.relationship_constraints.each do |c|
          lhs = entity.attribute_by_name(c.lhs_operand)
          rhs = entity.attribute_by_name(c.rhs_operand)
          op = c.class.operators[c.operator]
          constraint_sql = []
          constraint_sql << "#{lhs.sql.quoted_column_name} IS NULL" if lhs.nullable?
          constraint_sql << "#{rhs.sql.quoted_column_name} IS NULL" if rhs.nullable?
          constraint_sql << "#{lhs.sql.quoted_column_name} #{op} #{rhs.sql.quoted_column_name}"
          constraint(c.name, :sql => constraint_sql.join(" OR ")) unless constraint_by_name(c.name)
          copy_tags(c, constraint_by_name(c.name))
        end

        entity.codependent_constraints.each do |c|
          constraint(c.name, :sql => <<SQL) unless constraint_by_name(c.name)
( #{c.attribute_names.collect { |name| "#{entity.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL" }.join(" AND ")} ) OR
( #{c.attribute_names.collect { |name| "#{entity.attribute_by_name(name).sql.quoted_column_name} IS NULL" }.join(" AND ") } )
SQL
          copy_tags(c, constraint_by_name(c.name))
        end
        entity.dependency_constraints.each do |c|
          constraint(c.name, :sql => <<SQL) unless constraint_by_name(c.name)
#{entity.attribute_by_name(c.attribute_name).sql.quoted_column_name} IS NULL OR
( #{c.dependent_attribute_names.collect { |name| "#{entity.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL" }.join(" AND ") } )
SQL
          copy_tags(c, constraint_by_name(c.name))
        end
        entity.incompatible_constraints.each do |c|
          sql = (0..(c.attribute_names.size)).collect do |i|
            candidate = c.attribute_names[i]
            str = c.attribute_names.collect { |name| "#{entity.attribute_by_name(name).sql.quoted_column_name} IS#{(candidate == name) ? ' NOT' : ''} NULL" }.join(' AND ')
            "(#{str})"
          end.join(" OR ")
          constraint(c.name, :sql => sql) unless constraint_by_name(c.name)
          copy_tags(c, constraint_by_name(c.name))
        end

        entity.attributes.select { |a| a.enumeration? && a.enumeration.numeric_values? }.each do |a|
          sorted_values = (0..(a.enumeration.values.length)).collect{|v|v}
          constraint_name = "#{a.name}_Enum"
          constraint(constraint_name, :sql => <<SQL) unless constraint_by_name(constraint_name)
#{a.sql.quoted_column_name} >= #{sorted_values[0]} AND
#{a.sql.quoted_column_name} <= #{sorted_values[sorted_values.size - 1]}
SQL
        end
        entity.attributes.select { |a| a.attribute_type == :enumeration && a.enumeration.textual_values? }.each do |a|
          constraint_name = "#{a.name}_Enum"
          constraint(constraint_name, :sql => <<SQL) unless constraint_by_name(constraint_name)
#{a.sql.quoted_column_name} IN (#{a.enumeration.values.collect { |v| "'#{v}'" }.join(',')})
SQL
        end
        entity.attributes.select{ |a| (a.allows_length?) && !a.allow_blank? }.each do |a|
          constraint_name = "#{a.name}_NotEmpty"
          sql = Domgen::Sql.dialect.disallow_blank_constraint(a.sql.column_name)
          constraint(constraint_name, :sql => sql ) unless constraint_by_name(constraint_name)
        end

        entity.attributes.select { |a| a.set_once? }.each do |a|
          validation_name = "#{a.name}_SetOnce"
          validation(validation_name, :negative_sql => <<SQL, :after => :update) unless validation_by_name(validation_name)
SELECT I.#{a.entity.primary_key.sql.quoted_column_name}
FROM
inserted I
JOIN deleted D ON D.#{a.entity.primary_key.sql.quoted_column_name} = I.#{a.entity.primary_key.sql.quoted_column_name}
WHERE
  D.#{a.sql.quoted_column_name} IS NOT NULL AND
  (
    I.#{a.sql.quoted_column_name} IS NULL OR
    D.#{a.sql.quoted_column_name} != I.#{a.sql.quoted_column_name}
  )
SQL
        end

        entity.cycle_constraints.each do |c|
          target_attribute = entity.attribute_by_name(c.attribute_name)
          target_entity = entity.attribute_by_name(c.attribute_name).referenced_entity
          scoping_attribute = target_entity.attribute_by_name(c.scoping_attribute)

          attribute_name_path = c.attribute_name_path
          object_path = []

          entity = self.entity
          attribute_name_path.each do |attribute_name_path_element|
            object_path << entity
            other = entity.attribute_by_name(attribute_name_path_element)
            entity = other.referenced_entity
          end

          joins = []
          next_id = "@#{target_attribute.sql.column_name}"
          last_name = "@"
          attribute_name_path.each_with_index do |attribute_name, index|
            ot = object_path[index]
            name = "C#{index}"
            if index != 0
              joins << "LEFT JOIN #{ot.sql.qualified_table_name} #{name} ON #{last_name}#{object_path[index - 1].attribute_by_name(attribute_name_path[index - 1]).sql.column_name} = #{name}.#{ot.primary_key.sql.column_name}"
              last_name = "#{name}."
            end
            next_id = "#{last_name}#{ot.attribute_by_name(attribute_name).sql.column_name}"
          end

          comparison_id = "C0.#{scoping_attribute.sql.column_name}"

          functional_constraint_name = "#{c.name}_Scope"
          if !function_constraint_by_name(functional_constraint_name)
            function_constraint(functional_constraint_name, [c.attribute_name, c.attribute_name_path[0]]) do |constraint|
              constraint.invariant = true
              constraint.positive_sql = <<SQL
SELECT 1 AS Result
FROM
  (SELECT '1' AS IgnoreMe) I
LEFT JOIN #{target_entity.sql.qualified_table_name} C0 ON C0.#{target_entity.primary_key.sql.quoted_column_name} = @#{self.entity.attribute_by_name(c.attribute_name).sql.column_name}
#{joins.join("\n")}
WHERE @#{self.entity.attribute_by_name(c.attribute_name).sql.column_name} IS NULL OR #{comparison_id} = #{next_id}
SQL
            end
            copy_tags(c, function_constraint_by_name(functional_constraint_name))
          end
        end

        immutable_attributes = self.entity.attributes.select { |a| a.immutable? && !a.primary_key? }
        if immutable_attributes.size > 0
          pk = self.entity.primary_key

          validation_name = "Immuter"
          unless validation_by_name(validation_name)
            guard = immutable_attributes.collect { |a| "UPDATE(#{a.sql.column_name})" }.join(" OR ")
            validation(validation_name, :negative_sql => <<SQL, :after => :update, :guard => guard)
SELECT I.#{pk.sql.column_name}
FROM inserted I, deleted D
WHERE
  I.#{pk.sql.quoted_column_name} = D.#{pk.sql.quoted_column_name} AND
  (
#{immutable_attributes.collect do |a|
  if a.geometry?
    "    (I.#{a.sql.quoted_column_name}.STEquals(D.#{a.sql.quoted_column_name}) = 0)"
  else
    "    (I.#{a.sql.quoted_column_name} != D.#{a.sql.quoted_column_name})"
  end
end.join(" OR\n") }
  )
SQL
         end
        end

        abstract_relationships = self.entity.attributes.select { |a| a.reference? && a.referenced_entity.abstract? }
        if abstract_relationships.size > 0
          abstract_relationships.each do |attribute|
            concrete_subtypes = {}
            attribute.referenced_entity.subtypes.select { |subtype| !subtype.abstract? }.each_with_index do |subtype, index|
              concrete_subtypes["C#{index}"] = subtype
            end
            names = concrete_subtypes.keys
            validation_name = "#{attribute.name}ForeignKey"
            #TODO: Turn this into a functional validation
            if !validation_by_name(validation_name)
              guard = "UPDATE(#{attribute.sql.quoted_column_name})"
              sql = <<SQL
      SELECT I.#{self.entity.primary_key.sql.column_name}
      FROM
        inserted I
SQL
              concrete_subtypes.each_pair do |name, subtype|
                sql << "      LEFT JOIN #{subtype.sql.qualified_table_name} #{name} ON #{name}.#{Domgen::Sql.dialect.quote("ID")} = I.#{attribute.sql.quoted_column_name}"
              end
              sql << "      WHERE (#{names.collect { |name| "#{name}.#{Domgen::Sql.dialect.quote("ID")} IS NULL" }.join(' AND ') })"
              (0..(names.size - 2)).each do |index|
                sql << " OR\n (#{names[index] }.#{Domgen::Sql.dialect.quote("ID")} IS NOT NULL AND (#{((index + 1)..(names.size - 1)).collect { |index2| "#{names[index2]}.#{Domgen::Sql.dialect.quote("ID")} IS NOT NULL" }.join(' OR ') }))"
              end
              validation(validation_name, :negative_sql => sql, :guard => guard) unless validation_by_name(validation_name)
            end
          end
        end

        if self.entity.read_only?
          trigger_name = "ReadOnlyCheck"
          unless trigger_by_name(trigger_name)
            trigger(trigger_name) do |trigger|
              trigger.description("Ensure that #{self.entity.name} is read only.")
              trigger.after = []
              trigger.instead_of = [:insert, :update, :delete]
              trigger.sql = self.entity.data_module.repository.sql.emit_error("#{self.entity.name} is read only")
            end
          end
        end

        Trigger::VALID_AFTER.each do |after|
          desc = "Trigger after #{after} on #{self.entity.name}\n\n"
          sql = ""
          validations = self.validations.select {|v| v.after.include?(after)}.sort { |a, b| b.priority <=> a.priority }
          actions = self.actions.select {|a| a.after.include?(after)}.sort { |a, b| b.priority <=> a.priority }
          if !validations.empty? || !actions.empty?
            trigger_name = "After#{after.to_s.capitalize}"
            trigger(trigger_name) do |trigger|

              if !validations.empty?
                desc += "Enforce following validations:\n"
                sql += "DECLARE @Ignored INT\n"
                validations.each do |validation|
                  sql += <<SQL
;
#{validation.guard.nil? ? '' : "IF #{validation.guard}\nBEGIN\n" }
#{validation.common_table_expression} SELECT @Ignored = 1 WHERE EXISTS (#{validation.negative_sql})
  IF (@@ERROR != 0 OR @@ROWCOUNT != 0)
  BEGIN
    ROLLBACK
    #{self.entity.data_module.repository.sql.emit_error("Failed to pass validation check #{validation.name}")}
    RETURN
  END
#{validation.guard.nil? ? '' : "END" }
SQL
                  desc += "* #{validation.name}#{validation.tags[:Description] ? ": " : ""}#{validation.tags[:Description]}\n"
                end
                desc += "\n"
              end

              if !actions.empty?
                desc += "Performing the following actions:\n"
                actions.each do |action|
                  sql += "\n#{action.sql};\n"
                  desc += "* #{action.name}#{action.tags[:Description] ? ": " : ""}#{action.tags[:Description]}\n"
                end
              end

              trigger.description(desc)
              trigger.sql = sql
              trigger.after = after
            end
          end
        end

        self.entity.attributes.select { |a| a.reference? && !a.abstract? && !a.polymorphic? }.each do |a|
          foreign_key([a.name],
                      a.referenced_entity.qualified_name,
                      [a.referenced_entity.primary_key.name],
                      {:on_update => a.sql.on_update, :on_delete => a.sql.on_delete},
                      true)
        end

        Domgen::Sql.dialect.post_verify_table_customization(self)
      end

      def copy_tags(from, to)
        from.tags.each_pair do |k, v|
          to.tags[k] = v
        end
      end

      def to_s
        "Table[#{self.qualified_table_name}]"
      end
    end

    class Column < Domgen.ParentedElement(:attribute)
      def column_name
        if @column_name.nil?
          if attribute.reference?
            @column_name = attribute.referencing_link_name
          else
            @column_name = attribute.name
          end
        end
        @column_name
      end

      def quoted_column_name
        Domgen::Sql.dialect.quote(self.column_name)
      end

      attr_writer :sql_type

      def sql_type
        @sql_type ||= Domgen::Sql.dialect.column_type(self)
      end

      attr_writer :identity

      def identity?
        @identity.nil? ? attribute.generated_value? && attribute.primary_key?  : @identity
      end

      # TODO: MSSQL Specific
      attr_writer :sparse

      def sparse?
        @sparse.nil? ? false : @sparse
      end

      # The calculation to create column
      attr_accessor :calculation

      def persistent_calculation=(persistent_calculation)
        Domgen.error("Non calculated column can not be persistent") unless @calculation
        @persistent_calculation = persistent_calculation
      end

      def persistent_calculation?
        @persistent_calculation.nil? ? false : @persistent_calculation
      end

      def on_update=(on_update)
        Domgen.error("on_update on #{column_name} is invalid as attribute is not a reference") unless attribute.reference?
        Domgen.error("on_update #{on_update} on #{column_name} is invalid") unless self.class.change_actions.include?(on_update)
        @on_update = on_update
      end

      def on_update
        Domgen.error("on_update on #{name} is invalid as attribute is not a reference") unless attribute.reference?
        @on_update.nil? ? :no_action : @on_update
      end

      def on_delete=(on_delete)
        Domgen.error("on_delete on #{column_name} is invalid as attribute is not a reference") unless attribute.reference?
        Domgen.error("on_delete #{on_delete} on #{column_name} is invalid") unless self.class.change_actions.include?(on_delete)
        @on_delete = on_delete
      end

      def on_delete
        Domgen.error("on_delete on #{name} is invalid as attribute is not a reference") unless attribute.reference?
        @on_delete.nil? ? :no_action : @on_delete
      end

      def self.change_actions
        #{ :cascade => "CASCADE", :restrict => "RESTRICT", :set_null => "SET NULL", :set_default => "SET DEFAULT", :no_action => "NO ACTION" }.freeze
        [:cascade, :restrict, :set_null, :set_default, :no_action]
      end

      attr_accessor :default_value

      def to_s
        "Column[#{self.quoted_column_name}]"
      end
    end

    class Database < Domgen.ParentedElement(:repository)
      def initialize(repository, options = {}, &block)
        @error_handler = Proc.new do |error_message|
          "RAISERROR ('#{error_message}', 16, 1) WITH SETERROR"
        end
        super(repository, options, & block)
      end

      def define_error_handler(&block)
        @error_handler = block
      end

      def emit_error(error_message)
        @error_handler.call(error_message)
      end

      def pre_verify
        self.repository.data_modules.select{|data_module| data_module.sql?}.each do |dm|
          self.repository.data_modules.select{|data_module| data_module.sql?}.each do |other|
            if dm != other && dm.sql.schema.to_s == other.sql.schema.to_s
              Domgen.error("Multiple data modules (#{dm.name} && #{other.name}) are mapped to the same schema #{other.sql.schema}")
            end
          end
        end
      end

      def to_s
        "Database[#{self.repository.name}]"
      end
    end
  end

  FacetManager.define_facet(:sql,
                            Attribute => Domgen::Sql::Column,
                            Entity => Domgen::Sql::Table,
                            DataModule => Domgen::Sql::SqlSchema,
                            Repository => Domgen::Sql::Database)
end
