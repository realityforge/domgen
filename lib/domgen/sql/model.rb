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

module Domgen
  module Sql
    class Sequence < Domgen.ParentedElement(:schema)
      def initialize(schema, name, options, &block)
        @name = name
        schema.send(:register_sequence, name, self)
        super(schema, options, &block)
      end

      attr_reader :name
      attr_accessor :sql_type

      def quoted_sequence_name
        schema.dialect.quote(self.name)
      end

      def qualified_sequence_name
        "#{schema.quoted_schema}.#{quoted_sequence_name}"
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
        self.attribute_names.each do |attribute_name|
          unless table.entity.attribute_by_name?(attribute_name)
            Domgen.error("#{self} supplied key '#{attribute_name}' in :attribute_names configuration but no such attribute exists on related entity")
          end
        end
        self.include_attribute_names.each do |attribute_name|
          unless table.entity.attribute_by_name?(attribute_name)
            Domgen.error("#{self} supplied key '#{attribute_name}' in :include_attribute_names configuration but no such attribute exists on related entity")
          end
          if self.attribute_names.include?(attribute_name)
            Domgen.error("#{self} supplied key '#{attribute_name}' in :include_attribute_names configuration but key is present in :attribute_names configuration")
          end
        end
        duplicate_attribute_names = self.attribute_names.detect{ |e| self.attribute_names.count(e) > 1 }
        if duplicate_attribute_names
          Domgen.error("#{self} supplied duplicate keys #{duplicate_attribute_names.inspect} in :attribute_names configuration")
        end
        duplicate_includes = self.include_attribute_names.detect{ |e| self.include_attribute_names.count(e) > 1 }
        if duplicate_includes
          Domgen.error("#{self} supplied duplicate keys #{duplicate_includes.inspect} in :include_attribute_names configuration")
        end
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
        table.dialect.quote(self.index_name)
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

      attr_writer :allow_page_locks

      def allow_page_locks?
        @allow_page_locks.nil? ? true : !!@allow_page_locks
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
          :cascade => 'CASCADE',
          :set_null => 'SET NULL',
          :set_default => 'SET DEFAULT',
          :no_action => 'NO ACTION'
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

      attr_writer :defer_creation

      def defer_creation?
        @defer_creation.nil? ? false : !!@defer_creation
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
        table.dialect.quote(self.foreign_key_name)
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

      attr_writer :standard

      # Return true if this was defined by domgen or is derivable via rules.
      # standard constraints do not typically need to be tested
      def standard?
        @standard.nil? ? false : @standard
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
        table.dialect.quote(self.constraint_name)
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

      attr_writer :standard

      # Return true if this was defined by domgen or is derivable via rules.
      # standard constraints do not typically need to be tested
      def standard?
        @standard.nil? ? false : @standard
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
        table.dialect.quote(self.constraint_name)
      end

      def qualified_constraint_name
        "#{table.entity.data_module.sql.quoted_schema}.#{self.quoted_constraint_name}"
      end

      def function_name
        "#{table.entity.name}_#{name}"
      end

      def quoted_function_name
        table.dialect.quote(self.function_name)
      end

      def qualified_function_name
        "#{table.entity.data_module.sql.quoted_schema}.#{self.quoted_function_name}"
      end

      # The SQL generated in constraint
      def constraint_sql
        parameter_string = parameters.collect { |parameter_name| "  #{table.entity.attribute_by_name(parameter_name).sql.column_name}" }.join(',')
        function_call = "#{self.qualified_function_name}(#{parameter_string}) = 1"
        (self.or_conditions + [function_call]).join(' OR ')
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
        @after = scope('after', after)
      end

      def instead_of=(instead_of)
        @instead_of = scope('instead_of', instead_of)
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
      attr_accessor :common_table_expression
      attr_writer :invariant_negative_sql
      attr_accessor :invariant_common_table_expression
      attr_accessor :guard
      attr_writer :priority

      attr_writer :standard

      # Return true if this was defined by domgen or is derivable via rules.
      # standard constraints do not typically need to be tested
      def standard?
        @standard.nil? ? false : @standard
      end

      def priority
        @priority || 1
      end

      attr_writer :invariant_derivable

      def invariant_derivable?
        @invariant_derivable.nil? ? true : !!@invariant_derivable
      end

      def invariant_negative_sql
        return @invariant_negative_sql unless @invariant_negative_sql.nil?
        return nil unless self.invariant_derivable? && !self.negative_sql.nil? && !self.negative_sql.include?(' deleted ')
        self.negative_sql.
          # For any line that ends in a single line sql server quote (i.e. " -- ...\n" )
          # try to convert it to multiline quote (i.e. " /* ... */ "). That way when we strip out
          # whitespace we do not end up with invalid sql
          gsub(/('[^']*'|"[^"]*")|--(.*)\n/) {|m| $1 || "/*#{$2} */"}.
          gsub(/([ \t\r\n])inserted([ \t\r\n])/, "\\1#{self.table.qualified_table_name}\\2")
      end

      def invariant_common_table_expression
        return @invariant_common_table_expression unless @invariant_common_table_expression.nil?
        return nil unless self.invariant_derivable? && !self.common_table_expression.nil? && !self.common_table_expression.include?(' deleted ')
        self.common_table_expression.gsub(/([ \t\r\n])inserted([ \t\r\n])/, "\\1#{self.table.qualified_table_name}\\2")
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
        table.dialect.quote(self.trigger_name)
      end

      def qualified_trigger_name
        "#{table.entity.data_module.sql.quoted_schema}.#{self.quoted_trigger_name}"
      end

      def to_s
        "Action[#{self.qualified_trigger_name}]"
      end
    end
  end

  FacetManager.facet(:sql) do |facet|
    facet.enhance(Repository) do

      def dialect
        @dialect ||= (repository.mssql? ? Domgen::Mssql::MssqlDialect.new : repository.pgsql? ? Domgen::Pgsql::PgsqlDialect.new : (Domgen.error('Unable to determine the dialect in use')))
      end

      def error_handler
        @error_handler ||= Proc.new do |error_message|
          self.dialect.raise_error_sql(error_message)
        end
      end

      def define_error_handler(&block)
        @error_handler = block
      end

      def emit_error(error_message)
        error_handler.call(error_message)
      end

      def pre_complete
        # TODO: This will re-enable disabled sql facets which seems sub-par
        self.repository.enable_facet(:mssql) if !self.repository.mssql? && !self.repository.pgsql?
      end

      def perform_verify
        self.repository.data_modules.select { |data_module| data_module.sql? }.each do |dm|
          self.repository.data_modules.select { |data_module| data_module.sql? }.each do |other|
            if dm != other && dm.sql.schema.to_s == other.sql.schema.to_s
              Domgen.error("Multiple data modules (#{dm.name} && #{other.name}) are mapped to the same schema #{other.sql.schema}")
            end
          end
        end
      end

      attr_writer :sql_driver

      def sql_driver
        if @sql_driver.nil?
          @sql_driver =
            if self.repository.pgsql?
              'org.postgresql.Driver'
            elsif self.repository.mssql?
              'net.sourceforge.jtds.jdbc.Driver'
            else
              Domgen.error('No default SQL driver available, specify one with repository.sql.sql_driver = "your.driver.here"')
            end
        end
        @sql_driver
      end
    end

    facet.enhance(DataModule) do
      attr_writer :allow_empty_schema

      def allow_empty_schema?
        @allow_empty_schema.nil? ? false : !!@allow_empty_schema
      end

      def dialect
        data_module.repository.sql.dialect
      end

      attr_writer :schema

      def schema
        @schema || data_module.name
      end

      def quoted_schema
        self.dialect.quote(self.schema)
      end

      def sequence(name, options = {}, &block)
        Domgen::Sql::Sequence.new(self, name, options, &block)
      end

      def sequences
        sequence_map.values
      end

      def sequence_by_name(name)
        sequence = sequence_map[name.to_s]
        Domgen.error("Unable to locate sequence #{name} in #{data_module.name}") unless sequence
        sequence
      end

      def sequence_by_name?(name)
        !!sequence_map[name.to_s]
      end

      def perform_verify
        if !data_module.entities.any?{|e|e.sql?} && !data_module.sql.allow_empty_schema?
          Domgen.error("Data module #{data_module.name} contains no entities/tables but has not configured data_module.sql.allow_empty_schema = true")
        end
      end

      protected

      def sequence_map
        @sequences ||= {}
      end

      def register_sequence(name, sequence)
        sequence_map[name.to_s] = sequence
      end
    end

    facet.enhance(Entity) do
      def dialect
        entity.data_module.sql.dialect
      end

      def load_from_fixture=(load_from_fixture)
        @load_from_fixture = load_from_fixture
      end

      def load_from_fixture?
        @load_from_fixture.nil? ? false : !!@load_from_fixture
      end

      def sequence_table=(sequence_table)
        @sequence_table = sequence_table
      end

      def sequence_table?
        @sequence_table.nil? ? false : !!@sequence_table
      end

      attr_accessor :partition_scheme

      #+force_overflow_for_large_objects+ if set to true will force the native *VARCHAR(max) and XML datatypes (i.e.
      # text attributes to always be stored in overflow page by database engine. Otherwise they will be stored inline
      # as long as the data fits into a 8,060 byte row. It is a performance hit to access the overflow table so this
      # should be set to false unless the data columns are infrequently accessed relative to the other columns
      # TODO: MSSQL Specific
      attr_accessor :force_overflow_for_large_objects

      def table_name=(table_name)
        Domgen.error("sql.table_name= invoked on abstract entity #{entity.qualified_name}") if entity.abstract?
        @table_name = table_name
      end

      def table_name
        Domgen.error("sql.table_name invoked on abstract entity #{entity.qualified_name}") if entity.abstract?
        @table_name || sql_name(:table, entity.name)
      end

      def quoted_table_name
        self.dialect.quote(table_name)
      end

      def qualified_table_name
        "#{entity.data_module.sql.quoted_schema}.#{quoted_table_name}"
      end

      def view?
        entity.direct_subtypes.size != 0
      end

      # A view is created for any entity that has subtypes, and the view abstracts over all subclasses
      def view_name=(view_name)
        Domgen.error("sql.view_name= invoked on entity #{entity.qualified_name} with no subtypes") if entity.direct_subtypes.size == 0
        @view_name = view_name
      end

      def view_name
        Domgen.error("sql.view_name invoked on entity #{entity.qualified_name} with no subtypes") if entity.direct_subtypes.size == 0
        @view_name || sql_name(:view, entity.name)
      end

      def view_insert_trigger
        Domgen.error("sql.view_insert_trigger invoked on entity #{entity.qualified_name} with no subtypes") if entity.direct_subtypes.size == 0
        sql_name(:trigger, "#{entity.name}Insert")
      end

      def quoted_view_insert_trigger
        self.dialect.quote(view_insert_trigger)
      end

      def qualified_view_insert_trigger
        "#{entity.data_module.sql.quoted_schema}.#{quoted_view_insert_trigger}"
      end

      def view_update_trigger
        Domgen.error("sql.view_update_trigger invoked on entity #{entity.qualified_name} with no subtypes") if entity.direct_subtypes.size == 0
        sql_name(:trigger, "#{entity.name}Update")
      end

      def quoted_view_update_trigger
        self.dialect.quote(view_update_trigger)
      end

      def qualified_view_update_trigger
        "#{entity.data_module.sql.quoted_schema}.#{quoted_view_update_trigger}"
      end

      def view_delete_trigger
        Domgen.error("sql.view_delete_trigger invoked on entity #{entity.qualified_name} with no subtypes") if entity.direct_subtypes.size == 0
        sql_name(:trigger, "#{entity.name}Delete")
      end

      def quoted_view_delete_trigger
        self.dialect.quote(view_delete_trigger)
      end

      def qualified_view_delete_trigger
        "#{entity.data_module.sql.quoted_schema}.#{quoted_view_delete_trigger}"
      end

      def quoted_view_name
        self.dialect.quote(view_name)
      end

      def qualified_view_name
        "#{entity.data_module.sql.quoted_schema}.#{quoted_view_name}"
      end

      def discriminator=(discriminator)
        Domgen.error("Attempted to call 'sql.discriminator=' on non-subclass #{entity.qualified_name}") if entity.extends.nil?
        @discriminator = discriminator
      end

      def discriminator
        Domgen.error("Attempted to call 'sql.discriminator' on non-subclass #{entity.qualified_name}") if entity.extends.nil?
        @discriminator || entity.qualified_name.to_s
      end

      def constraint_values
        @constraint_values ||= {}
      end

      def constraints
        constraint_values.values
      end

      def constraint_by_name(name)
        constraint_values[name.to_s]
      end

      def constraint(name, options = {}, &block)
        existing = constraint_by_name(name)
        Domgen.error("Constraint named #{name} already defined on table #{qualified_table_name}") if existing
        constraint = Domgen::Sql::Constraint.new(self, name, options, &block)
        constraint_values[name.to_s] = constraint
        constraint
      end

      def function_constraint_values
        @function_constraint_values ||= {}
      end

      def function_constraints
        function_constraint_values.values
      end

      def function_constraint_by_name(name)
        function_constraint = function_constraint_values[name.to_s]
        Domgen.error("No Function Constraint named #{name} defined on table #{qualified_table_name}") unless function_constraint
        function_constraint
      end

      def function_constraint?(name)
        !!function_constraint_values[name.to_s]
      end

      def function_constraint(name, parameters, options = {}, &block)
        Domgen.error("Function Constraint named #{name} already defined on table #{qualified_table_name}") if function_constraint?(name)
        function_constraint = Domgen::Sql::FunctionConstraint.new(self, name, parameters, options, &block)
        function_constraint_values[name.to_s] = function_constraint
        function_constraint
      end

      def validation_values
        @validation_values ||= {}
      end

      def validations
        validation_values.values
      end

      def validation_by_name(name)
        validation = validation_values[name.to_s]
        Domgen.error("No validation named #{name} defined on table #{qualified_table_name}") unless validation
        validation
      end

      def validation?(name)
        !!validation_values[name.to_s]
      end

      def validation(name, options = {}, &block)
        Domgen.error("Validation named #{name} already defined on table #{qualified_table_name}") if validation?(name)
        validation = Domgen::Sql::Validation.new(self, name, options, &block)
        validation_values[name.to_s] = validation
        validation
      end

      def action_values
        @action_values ||= {}
      end

      def actions
        action_values.values
      end

      def action_by_name(name)
        action = action_values[name.to_s]
        Domgen.error("No action named #{name} defined on table #{qualified_table_name}") unless action
        action
      end

      def action?(name)
        !!action_values[name.to_s]
      end

      def action(name, options = {}, &block)
        Domgen.error("Action named #{name} already defined on table #{qualified_table_name}") if action?(name)
        action = Action.new(self, name, options, &block)
        action_values[name.to_s] = action
        action
      end

      def trigger_values
        @trigger_values ||= {}
      end

      def triggers
        trigger_values.values
      end

      def trigger_by_name(name)
        trigger = trigger_values[name.to_s]
        Domgen.error("No trigger named #{name} on table #{qualified_table_name}") unless trigger
        trigger
      end

      def trigger?(name)
        !!trigger_values[name.to_s]
      end

      def trigger(name, options = {}, &block)
        Domgen.error("Trigger named #{name} already defined on table #{qualified_table_name}") if trigger?(name)
        trigger = Domgen::Sql::Trigger.new(self, name, options, &block)
        trigger_values[name.to_s] = trigger
        trigger
      end

      def cluster(attribute_names, options = {}, &block)
        index(attribute_names, options.merge(:index_type => :cluster), &block)
      end

      def index_values
        @index_values ||= {}
      end

      def indexes
        index_values.values
      end

      def index(attribute_names, options = {}, skip_if_present = false, &block)
        index = Domgen::Sql::Index.new(self, attribute_names, options, &block)
        return index_values[index.index_name] if index_values[index.index_name] && skip_if_present
        Domgen.error("Index named #{index.index_name} already defined on table #{qualified_table_name}") if index_values[index.index_name]
        attribute_names.each do |attribute_name|
          Domgen.error("Index named #{index.index_name} declares attribute name #{attribute_name} that does not exist on containing entity #{entity.qualified_name}") unless entity.attribute_by_name?(attribute_name)
        end
        index_values[index.index_name] = index
        index
      end

      def foreign_key_values
        @foreign_key_values ||= {}
      end

      def foreign_keys
        foreign_key_values.values
      end

      def foreign_key(attribute_names, referenced_entity_name, referenced_attribute_names, options = {}, skip_if_present = false, &block)
        foreign_key = Domgen::Sql::ForeignKey.new(self, attribute_names, referenced_entity_name, referenced_attribute_names, options, &block)
        return if foreign_key_values[foreign_key.name] && skip_if_present
        Domgen.error("Foreign Key named #{foreign_key.name} already defined on table #{table_name}") if foreign_key_values[foreign_key.name]
        foreign_key_values[foreign_key.name] = foreign_key
        foreign_key
      end

      def post_verify
        if self.partition_scheme && indexes.select { |index| index.cluster? }.empty?
          Domgen.error('Must specify a clustered index if using a partition scheme')
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
          options = { :unique => true }
          options[:filter] = "#{self.entity.sql.dialect.quote(:DeletedAt)} IS NULL" if self.entity.transaction_time?
          index(c.attribute_names, options, true)
        end

        entity.relationship_constraints.each do |c|
          lhs = entity.attribute_by_name(c.lhs_operand)
          rhs = entity.attribute_by_name(c.rhs_operand)
          op = c.class.operators[c.operator]
          constraint_sql = []
          constraint_sql << "#{lhs.sql.quoted_column_name} IS NULL" if lhs.nullable?
          constraint_sql << "#{rhs.sql.quoted_column_name} IS NULL" if rhs.nullable?
          constraint_sql << "#{lhs.sql.quoted_column_name} #{op} #{rhs.sql.quoted_column_name}"
          constraint(c.name, :standard => true, :sql => constraint_sql.join(' OR ')) unless constraint_by_name(c.name)
          copy_tags(c, constraint_by_name(c.name))
        end

        entity.xor_constraints.each do |c|
          unless constraint_by_name(c.name)
            sql = []
            c.attribute_names.each_with_index do |name, index|
              s = "#{entity.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL AND " +
                "#{c.attribute_names.select { |n| n != name }.collect do |n|
                  "#{entity.attribute_by_name(n).sql.quoted_column_name} IS NULL"
                end.join(' AND ')}"
              sql << "(#{s})"
            end
            constraint(c.name, :standard => true, :sql => sql.join(' OR '))
          end
          copy_tags(c, constraint_by_name(c.name))
        end
        entity.dependency_constraints.each do |c|
          constraint(c.name, :standard => true, :sql => <<SQL) unless constraint_by_name(c.name)
#{entity.attribute_by_name(c.attribute_name).sql.quoted_column_name} IS NULL OR
( #{c.dependent_attribute_names.collect { |name| "#{entity.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL" }.join(' AND ') } )
SQL
          copy_tags(c, constraint_by_name(c.name))
        end

        entity.codependent_constraints.each do |c|
          constraint(c.name, :standard => true, :sql => <<SQL) unless constraint_by_name(c.name)
( #{c.attribute_names.collect { |name| "#{entity.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL" }.join(' AND ')} ) OR
( #{c.attribute_names.collect { |name| "#{entity.attribute_by_name(name).sql.quoted_column_name} IS NULL" }.join(' AND ') } )
SQL
          copy_tags(c, constraint_by_name(c.name))
        end
        entity.dependency_constraints.each do |c|
          constraint(c.name, :standard => true, :sql => <<SQL) unless constraint_by_name(c.name)
#{entity.attribute_by_name(c.attribute_name).sql.quoted_column_name} IS NULL OR
( #{c.dependent_attribute_names.collect { |name| "#{entity.attribute_by_name(name).sql.quoted_column_name} IS NOT NULL" }.join(' AND ') } )
SQL
          copy_tags(c, constraint_by_name(c.name))
        end
        entity.incompatible_constraints.each do |c|
          sql = (0..(c.attribute_names.size)).collect do |i|
            candidate = c.attribute_names[i]
            str = c.attribute_names.collect { |name| "#{entity.attribute_by_name(name).sql.quoted_column_name} IS#{(candidate == name) ? ' NOT' : ''} NULL" }.join(' AND ')
            "(#{str})"
          end.join(' OR ')
          constraint(c.name, :standard => true, :sql => sql) unless constraint_by_name(c.name)
          copy_tags(c, constraint_by_name(c.name))
        end

        entity.attributes.select { |a| a.enumeration? && a.enumeration.numeric_values? }.each do |a|
          sorted_values = (0..(a.enumeration.values.length)).collect { |v| v }
          constraint_name = "#{a.name}_Enum"
          constraint(constraint_name, :standard => true, :sql => <<SQL) unless constraint_by_name(constraint_name)
#{a.sql.quoted_column_name} >= #{sorted_values[0]} AND
#{a.sql.quoted_column_name} <= #{sorted_values[sorted_values.size - 1]}
SQL
        end
        entity.attributes.select { |a| a.attribute_type == :enumeration && a.enumeration.textual_values? }.each do |a|
          constraint_name = "#{a.name}_Enum"
          constraint(constraint_name, :standard => true, :sql => <<SQL) unless constraint_by_name(constraint_name)
#{a.sql.quoted_column_name} IN (#{a.enumeration.values.collect { |v| "'#{v.value}'" }.join(',')})
SQL
        end
        entity.attributes.select { |a| (a.allows_length?) && !a.allow_blank? }.each do |a|
          constraint_name = "#{a.name}_NotEmpty"
          sql = self.dialect.disallow_blank_constraint(a.sql.column_name)
          constraint(constraint_name, :standard => true, :sql => sql) unless constraint_by_name(constraint_name)
        end

        entity.attributes.select { |a| a.set_once? }.each do |a|
          validation_name = "#{a.name}_SetOnce"
          validation(validation_name, :standard => true, :negative_sql => self.dialect.set_once_sql(a), :after => :update) unless validation?(validation_name)
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
          last_name = '@'
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
          unless function_constraint?(functional_constraint_name)
            function_constraint(functional_constraint_name, [c.attribute_name, c.attribute_name_path[0]], :standard => true) do |constraint|
              constraint.invariant = true
              start_attribute = self.entity.attribute_by_name(c.attribute_name)
              sql = ''
              if start_attribute.nullable?
                sql += "SELECT 1 AS Result WHERE @#{start_attribute.sql.column_name} IS NULL\nUNION\n"
              end
              first_attribute_step = self.entity.attribute_by_name(c.attribute_name_path[0])
              if first_attribute_step.nullable?
                sql += "SELECT 1 AS Result WHERE @#{first_attribute_step.sql.column_name} IS NULL\nUNION\n"
              end

              sql += <<SQL
SELECT 1 AS Result
FROM
  #{target_entity.sql.qualified_table_name} C0
#{joins.join("\n")}
WHERE #{comparison_id} = #{next_id} AND C0.#{target_entity.primary_key.sql.quoted_column_name} = @#{start_attribute.sql.column_name}
SQL
              constraint.positive_sql = sql
            end
            copy_tags(c, function_constraint_by_name(functional_constraint_name))
          end
        end

        immutable_attributes = self.entity.attributes.select { |a| a.immutable? && !a.primary_key? }
        if immutable_attributes.size > 0
          validation_name = 'Immuter'
          unless validation?(validation_name)
            guard = self.dialect.immuter_guard(self.entity, immutable_attributes)
            guard_sql = self.dialect.immuter_sql(self.entity, immutable_attributes)
            validation(validation_name, :standard => true, :negative_sql => guard_sql, :after => :update, :guard => guard)
          end
        end

        abstract_relationships = self.entity.attributes.select { |a| a.reference? && a.referenced_entity.abstract? }
        if abstract_relationships.size > 0
          abstract_relationships.each do |attribute|
            pk_name = attribute.referenced_entity.primary_key.sql.column_name
            concrete_subtypes = {}
            attribute.referenced_entity.concrete_subtypes.each_with_index do |subtype, index|
              concrete_subtypes["C#{index}"] = subtype
            end
            names = concrete_subtypes.keys
            validation_name = "#{attribute.name}ForeignKey"
            #TODO: Turn this into a functional validation
            unless validation?(validation_name)
              guard = "UPDATE(#{attribute.sql.quoted_column_name})"
              sql = <<SQL
      SELECT I.#{self.entity.primary_key.sql.quoted_column_name}
      FROM
        inserted I
SQL
              concrete_subtypes.each_pair do |name, subtype|
                sql << "      LEFT JOIN #{subtype.sql.qualified_table_name} #{name} ON #{name}.#{self.dialect.quote(pk_name)} = I.#{attribute.sql.quoted_column_name}\n"
              end
              sql << "      WHERE (#{names.collect { |name| "#{name}.#{self.dialect.quote(pk_name)} IS NULL" }.join(' AND ') })"
              (0..(names.size - 2)).each do |index|
                sql << " OR\n (#{names[index] }.#{self.dialect.quote(pk_name)} IS NOT NULL AND (#{((index + 1)..(names.size - 1)).collect { |index2| "#{names[index2]}.#{self.dialect.quote(pk_name)} IS NOT NULL" }.join(' OR ') }))"
              end
              validation(validation_name, :negative_sql => sql, :guard => guard) unless validation?(validation_name)
            end
          end
        end

        if self.entity.read_only?
          trigger_name = 'ReadOnlyCheck'
          unless trigger?(trigger_name)
            trigger(trigger_name) do |trigger|
              trigger.description("Ensure that #{self.entity.name} is read only.")
              trigger.after = []
              trigger.instead_of = [:insert, :update, :delete]
              trigger.sql = self.entity.data_module.repository.sql.emit_error("#{self.entity.name} is read only")
            end
          end
        end

        Domgen::Sql::Trigger::VALID_AFTER.each do |after|
          desc = "Trigger after #{after} on #{self.entity.name}\n\n"
          validations = self.validations.select { |v| v.after.include?(after) }.sort { |a, b| b.priority <=> a.priority }
          actions = self.actions.select { |a| a.after.include?(after) }.sort { |a, b| b.priority <=> a.priority }
          if !validations.empty? || !actions.empty?
            trigger_name = "After#{after.to_s.capitalize}"
            trigger(trigger_name) do |trigger|
              sql = self.dialect.validations_trigger_sql(self.entity, validations, actions)

              if !validations.empty?
                desc += "Enforce following validations:\n"
                validations.each do |validation|
                  desc += "* #{validation.name}#{validation.tags[:Description] ? ': ' : ''}#{validation.tags[:Description]}\n"
                end
                desc += "\n"
              end

              if !actions.empty?
                desc += "Performing the following actions:\n"
                actions.each do |action|
                  desc += "* #{action.name}#{action.tags[:Description] ? ': ' : ''}#{action.tags[:Description]}\n"
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
                      { :on_update => a.sql.on_update, :on_delete => a.sql.on_delete, :defer_creation => a.sql.defer_creation? },
                      true)
        end

        self.dialect.post_verify_table_customization(self)
      end

      def copy_tags(from, to)
        from.tags.each_pair do |k, v|
          to.tags[k] = v
        end
      end
    end

    facet.enhance(Attribute) do
      def dialect
        attribute.entity.sql.dialect
      end

      attr_accessor :column_name

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
        self.dialect.quote(self.column_name)
      end

      attr_writer :sql_type

      def sql_type
        @sql_type ||= self.dialect.column_type(self)
      end

      def generator_type
        return :identity if @generator_type.nil? && attribute.generated_value? && attribute.primary_key?
        @generator_type || :none
      end

      def generator_type=(generator_type)
        Domgen.error("generator_type supplied #{generator_type} not valid") unless [:none, :identity, :sequence].include?(generator_type)
        attribute.generated_value = true
        @generator_type = generator_type
      end

      def sequence?
        self.generator_type == :sequence
      end

      def identity?
        self.generator_type == :identity
      end

      def sequence_name
        Domgen.error("sequence_name called on #{attribute.qualified_name} when not a sequence") unless self.sequence?
        @sequence_name || "#{attribute.entity.abstract? ? sql_name(:table, attribute.entity.name) : attribute.entity.sql.table_name}#{attribute.name}Seq"
      end

      def sequence_name=(sequence_name)
        Domgen.error("sequence_name= called on #{attribute.qualified_name} when not a sequence") if !@generator_type.nil? && !self.sequence?
        @sequence_name = sequence_name
      end

      def sequence
        Domgen.error("sequence called on #{attribute.qualified_name} when not a sequence") unless self.sequence?
        if attribute.entity.data_module.sql.sequence_by_name?(self.sequence_name)
          attribute.entity.data_module.sql.sequence_by_name(self.sequence_name)
        else
          attribute.entity.data_module.sql.sequence(self.sequence_name, 'sql_type' => self.sql_type)
        end
      end

      # TODO: MSSQL Specific
      attr_writer :sparse

      def sparse?
        @sparse.nil? ? false : @sparse
      end

      # The calculation to create column
      attr_accessor :calculation

      def persistent_calculation=(persistent_calculation)
        Domgen.error('Non calculated column can not be persistent') unless @calculation
        @persistent_calculation = persistent_calculation
      end

      def persistent_calculation?
        @persistent_calculation.nil? ? false : @persistent_calculation
      end

      def defer_creation=(defer_creation)
        Domgen.error("defer_creation on #{column_name} is invalid as attribute is not a reference") unless attribute.reference?
        @defer_creation = defer_creation
      end

      def defer_creation?
        @defer_creation.nil? ? false : !!@defer_creation
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
        [:cascade, :restrict, :set_null, :set_default, :no_action]
      end

      attr_accessor :default_value

      def perform_complete
        self.sequence if self.sequence?
      end
    end
  end
end
