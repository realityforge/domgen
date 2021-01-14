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

Domgen::TypeDB.config_element('sql.pgsql') do
  attr_accessor :sql_type
end

Domgen::TypeDB.enhance(:integer, 'sql.pgsql.sql_type' => 'integer')
Domgen::TypeDB.enhance(:long, 'sql.pgsql.sql_type' => 'bigint')
Domgen::TypeDB.enhance(:real, 'sql.pgsql.sql_type' => 'double precision')
Domgen::TypeDB.enhance(:date, 'sql.pgsql.sql_type' => 'date')
Domgen::TypeDB.enhance(:datetime, 'sql.pgsql.sql_type' => 'timestamp')
Domgen::TypeDB.enhance(:boolean, 'sql.pgsql.sql_type' => 'boolean')

Domgen::TypeDB.enhance(:point, 'sql.pgsql.sql_type' => 'POINT')
Domgen::TypeDB.enhance(:multipoint, 'sql.pgsql.sql_type' => 'MULTIPOINT')
Domgen::TypeDB.enhance(:linestring, 'sql.pgsql.sql_type' => 'LINESTRING')
Domgen::TypeDB.enhance(:multilinestring, 'sql.pgsql.sql_type' => 'MULTILINESTRING')
Domgen::TypeDB.enhance(:polygon, 'sql.pgsql.sql_type' => 'POLYGON')
Domgen::TypeDB.enhance(:multipolygon, 'sql.pgsql.sql_type' => 'MULTIPOLYGON')
Domgen::TypeDB.enhance(:geometry, 'sql.pgsql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:pointm, 'sql.pgsql.sql_type' => 'POINTM')
Domgen::TypeDB.enhance(:multipointm, 'sql.pgsql.sql_type' => 'MULTIPOINTM')
Domgen::TypeDB.enhance(:linestringm, 'sql.pgsql.sql_type' => 'LINESTRINGM')
Domgen::TypeDB.enhance(:multilinestringm, 'sql.pgsql.sql_type' => 'MULTILINESTRINGM')
Domgen::TypeDB.enhance(:polygonm, 'sql.pgsql.sql_type' => 'POLYGONM')
Domgen::TypeDB.enhance(:multipolygonm, 'sql.pgsql.sql_type' => 'MULTIPOLYGONM')

module Domgen
  module Pgsql
    class PgsqlDialect
      # Quote identifier
      def quote(column_name)
        # Postgres seems to have a maximum size of 64 characters in identifier
        # so lets just shorten the names and hope we never clash
        "\"#{column_name[0, 63]}\""
      end

      def quote_string(string)
        string.gsub("\'", "''")
      end

      def disallow_blank_constraint(column_name)
        "char_length(trim(both from #{quote(column_name)} )) > 0"
      end

      def column_type(column)
        if column.calculation
          Domgen.error('Unsupported column type - calculation')
        elsif column.attribute.reference?
          return column.attribute.referenced_entity.primary_key.sql.sql_type
        elsif column.attribute.text?
          if column.attribute.length.nil?
            return 'text'
          else
            return "varchar(#{column.attribute.length})"
          end
        elsif column.attribute.geometry?
          spatial_reference_id = column.attribute.geometry.srid || 0
          if column.attribute.geometry.geometry_type == :geometry
            return 'GEOMETRY'
          else
            return "GEOMETRY(#{column.attribute.geometry.geometry_type},#{spatial_reference_id})"
          end
        elsif column.attribute.enumeration?
          column.attribute.enumeration.textual_values? ? "varchar(#{column.attribute.length})" : 'integer'
        else
          return column.attribute.characteristic_type.sql.pgsql.sql_type
        end
      end

      def post_verify_table_customization(table)
        table.entity.attributes.select { |a| a.sql? && a.geometry? }.each do |a|
          constraint_name = "#{a.name}_ValidGeometry"
          table.constraint(constraint_name, :sql => "#{quote(a.sql.column_name)} IS NULL OR ST_IsValid(#{quote(a.sql.column_name)})") unless table.constraint_by_name(constraint_name)

          if a.geometry.geometry_type == :geometry
            if a.geometry.dimensions
              constraint_name = "#{a.name}_ValidDimensions"
              table.constraint(constraint_name, :sql => "#{quote(a.sql.column_name)} IS NULL OR ST_ndims(#{quote(a.sql.column_name)}) = #{a.geometry.dimensions}") unless table.constraint_by_name(constraint_name)
            end
            if a.geometry.srid
              constraint_name = "#{a.name}_ValidSpatialReferenceID"
              table.constraint(constraint_name, :sql => "#{quote(a.sql.column_name)} IS NULL OR ST_srid(#{quote(a.sql.column_name)}) = #{a.geometry.srid}") unless table.constraint_by_name(constraint_name)
            end
          end
        end
      end

      def raise_error_sql(error_message)
        "RAISE EXCEPTION '#{error_message}';"
      end

      def true_sql
        'true'
      end

      def false_sql
        'false'
      end

      # Specifies if this database requires the table name to be specified in the UPDATE statement as well as the alias.
      def requires_table_name_for_update
        true
      end

      def immuter_guard(entity, immutable_attributes)
        nil
      end

      def immuter_sql(entity, immutable_attributes)
        <<-SQL
        SELECT 1
        WHERE
          (
          #{immutable_attributes.collect do |a|
          if a.geometry?
            "            ST_Equals((NEW.#{a.sql.quoted_column_name}, OLD.#{a.sql.quoted_column_name}) = 0)"
          else
            "            (NEW.#{a.sql.quoted_column_name} != OLD.#{a.sql.quoted_column_name})"
          end
        end.join(" OR\n") }
          )
        SQL
      end

      def execute_sql
        'SELECT'
      end

      def wrap_store_proc_params(params)
        "(#{params})"
      end

      def set_once_sql(attribute)
        <<-SQL
SELECT 1
WHERE
  OLD.#{attribute.sql.quoted_column_name} IS NOT NULL AND
  (
    NEW.#{attribute.sql.quoted_column_name} IS NULL OR
    OLD.#{attribute.sql.quoted_column_name} != NEW.#{attribute.sql.quoted_column_name}
  )
        SQL
      end

      def validations_trigger_sql(entity, validations, actions)
        sql = ''
        if !validations.empty?
          validations.each do |validation|
            sql += <<SQL
#{validation.guard.nil? ? '' : "IF #{validation.guard}\nBEGIN\n" }
            #{validation.common_table_expression} IF EXISTS (#{validation.negative_sql}) THEN
    ROLLBACK;
    #{entity.data_module.repository.sql.emit_error("Failed to pass validation check #{validation.name}")}
  END IF;
#{validation.guard.nil? ? '' : 'END' }
SQL
          end
        end

        unless actions.empty?
          actions.each do |action|
            sql += "\n#{action.sql};\n"
          end
        end
        sql
      end
    end
  end

  FacetManager.facet(:pgsql => [:sql]) do |facet|
    facet.enhance(Repository) do
      def pre_complete
        if repository.ee?
          repository.ee.cdi_scan_excludes << 'org.postgresql.**'

          # Just in case some attributes use spatial types
          repository.ee.cdi_scan_excludes << 'org.postgis.**'
        end
      end
    end
  end
end
