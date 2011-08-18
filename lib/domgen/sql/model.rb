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

      TYPE_MAP = {"string" => "varchar",
                  "integer" => "integer",
                  "real" => "double precision",
                  "datetime" => "timestamp",
                  "boolean" => "bit",
                  "i_enum" => "integer",
                  "s_enum" => "varchar"}


      def column_type(column)
        if column.calculation
          raise "Unsupported column type - calculation"
        elsif :reference == column.attribute.attribute_type
          return column.attribute.referenced_object.primary_key.sql.sql_type
        elsif column.attribute.attribute_type.to_s == 'text'
          return "text"
        else
          return TYPE_MAP[column.attribute.attribute_type.to_s] + (column.attribute.length.nil? ? '' : "(#{column.attribute.length})")
        end
      end

      #def quote_value(value)
      #  if value.is_a? TrueClass
      #    '1'
      #  elsif value.is_a? FalseClass
      #    '0'
      #  elsif value.is_a? String
      #    "'#{value}'"
      #  elsif value.is_a? Numeric
      #    "(#{value})"
      #  end
      #end
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

      TYPE_MAP = {"string" => "VARCHAR",
                  "integer" => "INT",
                  "real" => "FLOAT",
                  "datetime" => "DATETIME",
                  "boolean" => "BIT",
                  "i_enum" => "INT",
                  "s_enum" => "VARCHAR"}

      def column_type(column)
        if column.calculation
          sql_type = "AS #{@calculation}"
          if persistent_calculation?
            sql_type += " PERSISTED"
          end
          return sql_type
        elsif :reference == column.attribute.attribute_type
          return column.attribute.referenced_object.primary_key.sql.sql_type
        elsif column.attribute.attribute_type.to_s == 'text'
          return "[VARCHAR](MAX)"
        else
          return quote(TYPE_MAP[column.attribute.attribute_type.to_s]) + (column.attribute.length.nil? ? '' : "(#{column.attribute.length})")
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

    class SqlSchema < BaseParentedElement
      attr_writer :schema

      def schema
        @schema || data_module.name
      end

      def data_module
        self.parent
      end

      def quoted_schema
        Domgen::Sql.dialect.quote(self.schema)
      end
    end

    class Index < BaseConfigElement
      attr_reader :table
      attr_accessor :attribute_names
      attr_accessor :include_attribute_names
      attr_accessor :filter

      def initialize(table, attribute_names, options, &block)
        @table = table
        @attribute_names = attribute_names
        @include_attribute_names = []
        super(options, &block)
      end

      attr_writer :index_name

      def index_name
        if @index_name.nil?
          prefix = cluster? ? 'CL' : unique? ? 'UQ' : 'IX'
          suffix = attribute_names.join('_')
          @index_name = "#{prefix}_#{table.object_type.name}_#{suffix}"
        end
        @index_name
      end

      def quoted_index_name
        Domgen::Sql.dialect.quote(self.index_name)
      end

      def qualified_index_name
        "#{table.object_type.data_module.sql.quoted_schema}.#{quoted_index_name}"
      end

      attr_writer :cluster

      def cluster?
        @cluster.nil? ? false : @cluster
      end

      attr_writer :unique

      def unique?
        @unique.nil? ? false : @unique
      end

      def partial?
        !self.filter.nil?
      end
    end

    class ForeignKey < BaseConfigElement
      ACTION_MAP =
        {
          :cascade => "CASCADE",
          :restrict => "RESTRICT",
          :set_null => "SET NULL",
          :set_default => "SET DEFAULT",
          :no_action => "NO ACTION"
        }.freeze

      attr_reader :table
      attr_accessor :attribute_names
      attr_accessor :referenced_object_type_name
      attr_accessor :referenced_attribute_names

      def initialize(table, attribute_names, referenced_object_type_name, referenced_attribute_names, options, &block)
        @table, @attribute_names, @referenced_object_type_name, @referenced_attribute_names =
          table, attribute_names, referenced_object_type_name, referenced_attribute_names
        super(options, &block)
        # Ensure that the attributes exist
        attribute_names.each { |a| table.object_type.attribute_by_name(a) }
        # Ensure that the remote attributes exist on remote type
        referenced_attribute_names.each { |a| referenced_object_type.attribute_by_name(a) }
      end

      attr_writer :name

      def name
        if @name.nil?
          @name = "#{attribute_names.join('_')}"
        end
        @name
      end

      def referenced_object_type
        table.object_type.data_module.object_type_by_name(referenced_object_type_name)
      end

      def on_update=(on_update)
        error("on_update #{on_update} on #{name} is invalid") unless ACTION_MAP.keys.include?(on_update)
        @on_update = on_update
      end

      def on_update
        @on_update || :no_action
      end

      def on_delete=(on_delete)
        error("on_delete #{on_delete} on #{name} is invalid") unless ACTION_MAP.keys.include?(on_delete)
        @on_delete = on_delete
      end

      def on_delete
        @on_delete || :no_action
      end

      def foreign_key_name
        "FK_#{s(table.object_type.name)}_#{s(name)}"
      end

      def quoted_foreign_key_name
        Domgen::Sql.dialect.quote(self.foreign_key_name)
      end

      def qualified_foreign_key_name
        "#{table.object_type.data_module.sql.quoted_schema}.#{quoted_foreign_key_name}"
      end

      def constraint_name
        foreign_key_name
      end

      def quoted_constraint_name
        quoted_foreign_key_name
      end
    end

    class Constraint < BaseParentedElement
      attr_reader :name
      attr_accessor :sql

      def initialize(parent, name, options = {}, &block)
        @name = name
        super(parent, options, &block)
      end

      def table
        self.parent
      end

      attr_writer :invariant

      # Return true if this constraint should always be true, not just on insert or update.
      def invariant?
        @invariant.nil? ? true : @invariant
      end

      def constraint_name
        "CK_#{s(table.object_type.name)}_#{s(name)}"
      end

      def quoted_constraint_name
        Domgen::Sql.dialect.quote(self.constraint_name)
      end

      def qualified_constraint_name
        "#{table.object_type.data_module.sql.quoted_schema}.#{self.quoted_constraint_name}"
      end
    end

    class FunctionConstraint < BaseParentedElement
      attr_reader :name
      # The SQL that is part of function invoked
      attr_accessor :positive_sql
      attr_accessor :parameters
      attr_accessor :common_table_expression
      attr_accessor :or_conditions

      def initialize(parent, name, parameters, options = {}, & block)
        @name = name
        @parameters = parameters
        @or_conditions = []
        super(parent, options, & block)
      end

      def table
        self.parent
      end

      attr_writer :invariant

      # Return true if this constraint should always be true, not just on insert or update.
      def invariant?
        @invariant.nil? ? true : @invariant
      end

      def constraint_name
        "CK_#{s(table.object_type.name)}_#{s(name)}"
      end

      def quoted_constraint_name
        Domgen::Sql.dialect.quote(self.constraint_name)
      end

      def qualified_constraint_name
        "#{table.object_type.data_module.sql.quoted_schema}.#{self.quoted_constraint_name}"
      end

      def function_name
        "#{table.object_type.name}_#{name}"
      end

      def quoted_function_name
        Domgen::Sql.dialect.quote(self.function_name)
      end

      def qualified_function_name
        "#{table.object_type.data_module.sql.quoted_schema}.#{self.quoted_function_name}"
      end

      # The SQL generated in constraint
      def constraint_sql
        parameter_string = parameters.collect{|parameter_name| "  #{table.object_type.attribute_by_name(parameter_name).sql.column_name}"}.join(",")
        function_call = "#{self.qualified_function_name}(#{parameter_string}) = 1"
        (self.or_conditions + [function_call]).join(" OR ")
      end
    end

    class SequencedSqlElement < BaseParentedElement
      VALID_AFTER = [:insert, :update, :delete]

      attr_reader :name
      attr_reader :after
      attr_reader :instead_of

      def initialize(parent, name, options = {}, & block)
        @name = name
        @after = [:insert, :update]
        @instead_of = []
        super(parent, options, & block)
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
          raise "Unknown #{label} specififier #{a}" unless VALID_AFTER.include?(a)
        end
        scope
      end
    end

    class Validation < SequencedSqlElement
      attr_accessor :negative_sql
      attr_accessor :invariant_negative_sql
      attr_accessor :common_table_expression
      attr_accessor :guard
      attr_accessor :priority

      def initialize(parent, name, options = {}, &block)
        @priority = 1
        super(parent, name, options, &block)
      end

      def table
        self.parent
      end
    end

    class Action < SequencedSqlElement
      attr_accessor :sql
      attr_accessor :guard
      attr_accessor :priority

      def initialize(parent, name, options = {}, &block)
        @priority = 1
        super(parent, name, options, &block)
      end
    end

    class Trigger < SequencedSqlElement
      attr_accessor :sql

      def initialize(parent, name, options = {}, &block)
        super(parent, name, options, &block)
      end

      def table
        self.parent
      end

      def trigger_name
        @trigger_name ||= sql_name(:trigger, "#{table.object_type.name}#{self.name}")
      end

      def quoted_trigger_name
        Domgen::Sql.dialect.quote(self.trigger_name)
      end

      def qualified_trigger_name
        "#{table.object_type.data_module.sql.quoted_schema}.#{self.quoted_trigger_name}"
      end
    end

    class Table < BaseParentedElement
      attr_writer :table_name
      attr_accessor :partition_scheme

      #+force_overflow_for_large_objects+ if set to true will force the native *VARCHAR(max) and XML datatypes (i.e.
      # text attributes to always be stored in overflow page by database engine. Otherwise they will be stored inline
      # as long as the data fits into a 8,060 byte row. It is a performance hit to access the overflow table so this
      # should be set to false unless the data columns are infrequently accessed relative to the other columns
      # TODO: MSSQL Specific
      attr_accessor :force_overflow_for_large_objects

      def initialize(parent, options = {}, &block)
        @indexes = Domgen::OrderedHash.new
        @constraints = Domgen::OrderedHash.new
        @function_constraints = Domgen::OrderedHash.new
        @validations = Domgen::OrderedHash.new
        @actions = Domgen::OrderedHash.new
        @triggers = Domgen::OrderedHash.new
        @foreign_keys = Domgen::OrderedHash.new
        super(parent, options, &block)
      end

      def object_type
        self.parent
      end

      def table_name
        @table_name ||= sql_name(:table, object_type.name)
      end

      def quoted_table_name
        Domgen::Sql.dialect.quote(table_name)
      end

      def qualified_table_name
        "#{object_type.data_module.sql.quoted_schema}.#{quoted_table_name}"
      end

      def constraints
        @constraints.values
      end

      def constraint_by_name(name)
        @constraints[name.to_s]
      end

      def constraint(name, options = {}, &block)
        existing = constraint_by_name(name)
        error("Constraint named #{name} already defined on table #{qualified_table_name}") if (existing && !existing.inherited?)
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
        error("Function Constraint named #{name} already defined on table #{qualified_table_name}") if (existing && !existing.inherited?)
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
        error("Validation named #{name} already defined on table #{qualified_table_name}") if (existing && !existing.inherited?)
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
        error("Action named #{name} already defined on table #{qualified_table_name}") if (existing && !existing.inherited?)
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
        error("Trigger named #{name} already defined on table #{qualified_table_name}") if (existing && !existing.inherited?)
        trigger = Trigger.new(self, name, options, &block)
        @triggers[name.to_s] = trigger
        trigger
      end

      def cluster(attribute_names, options = {}, &block)
        index(attribute_names, options.merge(:cluster => true), &block)
      end

      def indexes
        @indexes.values
      end

      def index(attribute_names, options = {}, skip_if_present = false, &block)
        index = Index.new(self, attribute_names, options, &block)
        return if @indexes[index.index_name] && skip_if_present
        error("Index named #{index.index_name} already defined on table #{qualified_table_name}") if @indexes[index.index_name]
        @indexes[index.index_name] = index
        index
      end

      def foreign_keys
        @foreign_keys.values
      end

      def foreign_key(attribute_names, referrenced_object_type_name, referrenced_attribute_names, options = {}, skip_if_present = false, &block)
        foreign_key = ForeignKey.new(self, attribute_names, referrenced_object_type_name, referrenced_attribute_names, options, &block)
        return if @indexes[foreign_key.name] && skip_if_present
        error("Foreign Key named #{foreign_key.name} already defined on table #{table_name}") if @indexes[foreign_key.name]
        @foreign_keys[foreign_key.name] = foreign_key
        foreign_key
      end

      def post_verify
        if self.partition_scheme && indexes.select{|index|index.cluster?}.empty?
          error("Must specify a clustered index if using a partition scheme")
        end

        self.indexes.each do |index|
          if index.cluster? && index.partial?
            error("Must not specify a partial clustered index. Index = #{index.qualified_index_name}")
          end
        end

        if indexes.select { |i| i.cluster? }.size > 1
          error("#{qualified_table_name} defines multiple clustering indexes")
        end

        object_type.unique_constraints.each do |c|
          index(c.attribute_names, {:unique => true}, true)
        end

        object_type.relationship_constraints.each do |c|
          lhs = object_type.attribute_by_name(c.lhs_operand)
          rhs = object_type.attribute_by_name(c.rhs_operand)
          op = c.class.operators[c.operator]
          constraint_sql = []
          constraint_sql << "#{lhs.sql.quoted_column_name} IS NULL" if lhs.nullable?
          constraint_sql << "#{rhs.sql.quoted_column_name} IS NULL" if rhs.nullable?
          constraint_sql << "#{lhs.sql.quoted_column_name} #{op} #{rhs.sql.quoted_column_name}"
          constraint(c.name, :sql => constraint_sql.join(" OR ")) unless constraint_by_name(c.name)
          copy_tags(c, constraint_by_name(c.name))
        end

        object_type.codependent_constraints.each do |c|
          constraint(c.name, :sql => <<SQL) unless constraint_by_name(c.name)
( #{c.attribute_names.collect { |name| "#{object_type.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL" }.join(" AND ")} ) OR
( #{c.attribute_names.collect { |name| "#{object_type.attribute_by_name(name).sql.quoted_column_name} IS NULL" }.join(" AND ") } )
SQL
          copy_tags(c, constraint_by_name(c.name))
        end
        object_type.dependency_constraints.each do |c|
          constraint(c.name, :sql => <<SQL) unless constraint_by_name(c.name)
#{object_type.attribute_by_name(c.attribute_name).sql.quoted_column_name} IS NULL OR
( #{c.dependent_attribute_names.collect { |name| "#{object_type.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL" }.join(" AND ") } )
SQL
          copy_tags(c, constraint_by_name(c.name))
        end
        object_type.incompatible_constraints.each do |c|
          sql = (0..(c.attribute_names.size)).collect do |i|
            candidate = c.attribute_names[i]
            str = c.attribute_names.collect { |name| "#{object_type.attribute_by_name(name).sql.quoted_column_name} IS#{(candidate == name) ? ' NOT' : ''} NULL" }.join(' AND ')
            "(#{str})"
          end.join(" OR ")
          constraint(c.name, :sql => sql) unless constraint_by_name(c.name)
          copy_tags(c, constraint_by_name(c.name))
        end

        object_type.declared_attributes.select { |a| a.attribute_type == :i_enum }.each do |a|
          sorted_values = a.values.values.sort
          constraint_name = "#{a.name}_Enum"
          constraint(constraint_name, :sql => <<SQL) unless constraint_by_name(constraint_name)
#{a.sql.quoted_column_name} >= #{sorted_values[0]} AND
#{a.sql.quoted_column_name} <= #{sorted_values[sorted_values.size - 1]}
SQL
        end
        object_type.declared_attributes.select { |a| a.attribute_type == :s_enum }.each do |a|
          constraint_name = "#{a.name}_Enum"
          constraint(constraint_name, :sql => <<SQL) unless constraint_by_name(constraint_name)
#{a.sql.quoted_column_name} IN (#{a.values.values.collect { |v| "'#{v}'" }.join(',')})
SQL
        end
        object_type.declared_attributes.select{ |a| (a.attribute_type == :s_enum || a.attribute_type == :string) && a.persistent? && !a.allow_blank? }.each do |a|
          constraint_name = "#{a.name}_NotEmpty"
          sql = Domgen::Sql.dialect.disallow_blank_constraint(a.sql.column_name)
          constraint(constraint_name, :sql => sql ) unless constraint_by_name(constraint_name)
        end

        object_type.declared_attributes.select { |a| a.set_once? }.each do |a|
          validation_name = "#{a.name}_SetOnce"
          validation(validation_name, :negative_sql => <<SQL, :after => :update) unless validation_by_name(validation_name)
SELECT I.#{a.object_type.primary_key.sql.quoted_column_name}
FROM
inserted I
JOIN deleted D ON D.#{a.object_type.primary_key.sql.quoted_column_name} = I.#{a.object_type.primary_key.sql.quoted_column_name}
WHERE
  D.#{a.sql.quoted_column_name} IS NOT NULL AND
  (
    I.#{a.sql.quoted_column_name} IS NULL OR
    D.#{a.sql.quoted_column_name} != I.#{a.sql.quoted_column_name}
  )
SQL
        end

        object_type.cycle_constraints.each do |c|
          target_attribute = object_type.attribute_by_name(c.attribute_name)
          target_object_type = object_type.attribute_by_name(c.attribute_name).referenced_object
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
LEFT JOIN #{target_object_type.sql.qualified_table_name} C0 ON C0.#{target_object_type.primary_key.sql.quoted_column_name} = @#{self.object_type.attribute_by_name(c.attribute_name).sql.column_name}
#{joins.join("\n")}
WHERE @#{self.object_type.attribute_by_name(c.attribute_name).sql.column_name} IS NULL OR #{comparison_id} = #{next_id}
SQL
            end
            copy_tags(c, function_constraint_by_name(functional_constraint_name))
          end
        end

        immutable_attributes = self.object_type.attributes.select { |a| a.persistent? && a.immutable? && !a.primary_key? }
        if immutable_attributes.size > 0
          pk = self.object_type.primary_key

          validation_name = "Immuter"
          unless validation_by_name(validation_name)
            guard = immutable_attributes.collect { |a| "UPDATE(#{a.sql.column_name})" }.join(" OR ")
            validation(validation_name, :negative_sql => <<SQL, :after => :update, :guard => guard)
SELECT I.#{pk.sql.column_name}
FROM inserted I, deleted D
WHERE
  I.#{pk.sql.quoted_column_name} = D.#{pk.sql.quoted_column_name} AND
  (
#{immutable_attributes.collect {|a| "    (I.#{a.sql.quoted_column_name} != D.#{a.sql.quoted_column_name})" }.join(" OR\n") }
  )
SQL
         end
        end

        abstract_relationships = self.object_type.attributes.select { |a| a.reference? && a.referenced_object.abstract? }
        if abstract_relationships.size > 0
          abstract_relationships.each do |attribute|
            concrete_subtypes = {}
            attribute.referenced_object.subtypes.select { |subtype| !subtype.abstract? }.each_with_index do |subtype, index|
              concrete_subtypes["C#{index}"] = subtype
            end
            names = concrete_subtypes.keys
            validation_name = "#{attribute.name}ForeignKey"
            #TODO: Turn this into a functional validation
            if !validation_by_name(validation_name)
              guard = "UPDATE(#{attribute.sql.quoted_column_name})"
              sql = <<SQL
      SELECT I.#{self.object_type.primary_key.sql.column_name}
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

        if self.object_type.read_only?
          trigger_name = "ReadOnlyCheck"
          unless trigger_by_name(trigger_name)
            trigger(trigger_name) do |trigger|
              trigger.description("Ensure that #{self.object_type.name} is read only.")
              trigger.after = []
              trigger.instead_of = [:insert, :update, :delete]
              trigger.sql = self.object_type.data_module.repository.sql.emit_error("#{self.object_type.name} is read only")
            end
          end
        end

        Trigger::VALID_AFTER.each do |after|
          desc = "Trigger after #{after} on #{self.object_type.name}\n\n"
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
    #{self.object_type.data_module.repository.sql.emit_error("Failed to pass validation check #{validation.name}")}
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

        self.object_type.declared_attributes.select { |a| a.persistent? && a.reference? && !a.abstract? && !a.polymorphic? }.each do |a|
          foreign_key([a.name],
                      a.referenced_object.qualified_name,
                      [a.referenced_object.primary_key.name],
                      {:on_update => a.on_update, :on_delete => a.on_delete},
                      true)
        end
      end

      def copy_tags(from, to)
        from.tags.each_pair do |k, v|
          to.tags[k] = v
        end
      end

      def post_inherited
        indexes.each { |a| a.mark_as_inherited }
        constraints.each { |a| a.mark_as_inherited }
        function_constraints.each { |a| a.mark_as_inherited }
        validations.each { |a| a.mark_as_inherited }
        triggers.each { |a| a.mark_as_inherited }
        foreign_keys.each { |a| a.mark_as_inherited }
      end
    end

    class Column < BaseParentedElement
      def attribute
        self.parent
      end

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
        raise "Non calculated column can not be persistent" unless @calculation
        @persistent_calculation = persistent_calculation
      end

      def persistent_calculation?
        @persistent_calculation.nil? ? false : @persistent_calculation
      end

      attr_accessor :default_value
    end

    class Database < BaseParentedElement
      def initialize(parent, options = {}, &block)
        @error_handler = Proc.new do |error_message|
          "RAISERROR ('#{error_message}', 16, 1) WITH SETERROR"
        end
        super(parent, options, & block)
      end

      def repository
        self.parent
      end

      def define_error_handler(&block)
        @error_handler = block
      end

      def emit_error(error_message)
        @error_handler.call(error_message)
      end

      def pre_verify
        self.repository.data_modules.each do |dm|
          self.repository.data_modules.each do |other|
            if dm != other && dm.sql.schema.to_s == other.sql.schema.to_s
              raise "Multiple data modules (#{dm.name} && #{other.name}) are mapped to the same schema #{other.sql.schema}"
            end
          end
        end
      end
    end
  end

  Attribute.add_extension(:sql, Domgen::Sql::Column)
  ObjectType.add_extension(:sql, Domgen::Sql::Table)
  DataModule.add_extension(:sql, Domgen::Sql::SqlSchema)
  Repository.add_extension(:sql, Domgen::Sql::Database)
end
