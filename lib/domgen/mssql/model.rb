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

Domgen::TypeDB.config_element('sql.mssql') do
  attr_accessor :sql_type
end

Domgen::TypeDB.enhance(:integer, 'sql.mssql.sql_type' => 'INT')
Domgen::TypeDB.enhance(:long, 'sql.mssql.sql_type' => 'BIGINT')
Domgen::TypeDB.enhance(:real, 'sql.mssql.sql_type' => 'FLOAT')
Domgen::TypeDB.enhance(:date, 'sql.mssql.sql_type' => 'DATE')
Domgen::TypeDB.enhance(:datetime, 'sql.mssql.sql_type' => 'DATETIME')
Domgen::TypeDB.enhance(:boolean, 'sql.mssql.sql_type' => 'BIT')

Domgen::TypeDB.enhance(:point, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:multipoint, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:linestring, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:multilinestring, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:polygon, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:multipolygon, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:geometry, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:pointm, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:multipointm, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:linestringm, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:multilinestringm, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:polygonm, 'sql.mssql.sql_type' => 'GEOMETRY')
Domgen::TypeDB.enhance(:multipolygonm, 'sql.mssql.sql_type' => 'GEOMETRY')

module Domgen
  module Mssql
    class MssqlDialect
      def quote(column_name)
        "[#{column_name}]"
      end

      def quote_string(string)
        string.gsub("\'", "''")
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
        table.entity.attributes.select { |a| a.sql? && a.geometry? }.each do |a|
          constraint_name = "#{a.name}_ValidGeometry"
          table.constraint(constraint_name, :sql => "#{quote(a.sql.column_name)}.STIsValid() = 1") unless table.constraint_by_name(constraint_name)

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

      def raise_error_sql(error_message)
        "RAISERROR ('#{error_message}', 16, 1) WITH SETERROR"
      end

      def immuter_guard(entity, immutable_attributes)
        immutable_attributes.collect { |a| "UPDATE(#{a.sql.quoted_column_name})" }.join(" OR ")
      end

      def immuter_sql(entity, immutable_attributes)
        pk = entity.primary_key
        <<-SQL
        SELECT I.#{pk.sql.quoted_column_name}
        FROM inserted I, deleted D
        WHERE
          I.#{pk.sql.quoted_column_name} = D.#{pk.sql.quoted_column_name} AND
          (
          #{immutable_attributes.collect do |a|
                      if a.geometry?
                        "            (I.#{a.sql.quoted_column_name}.STEquals(D.#{a.sql.quoted_column_name}) = 0)"
                      else
                        "            (I.#{a.sql.quoted_column_name} != D.#{a.sql.quoted_column_name})"
                      end
                    end.join(" OR\n") }
          )
        SQL
      end

      def set_once_sql(attribute)
        <<-SQL
          SELECT 1
          FROM
          inserted I
          JOIN deleted D ON D.#{attribute.entity.primary_key.sql.quoted_column_name} = I.#{attribute.entity.primary_key.sql.quoted_column_name}
          WHERE
            D.#{attribute.sql.quoted_column_name} IS NOT NULL AND
            (
              I.#{attribute.sql.quoted_column_name} IS NULL OR
              D.#{attribute.sql.quoted_column_name} != I.#{attribute.sql.quoted_column_name}
            )
        SQL
      end

      def validations_trigger_sql(entity, validations, actions)
        sql =''
        if !validations.empty?
          sql += "DECLARE @Ignored INT\n"
          validations.each do |validation|
            sql += <<SQL
;
#{validation.guard.nil? ? '' : "IF #{validation.guard}\nBEGIN\n" }
            #{validation.common_table_expression} SELECT @Ignored = 1 WHERE EXISTS (#{validation.negative_sql})
  IF (@@ERROR != 0 OR @@ROWCOUNT != 0)
  BEGIN
    ROLLBACK
    #{entity.data_module.repository.sql.emit_error("Failed to pass validation check #{validation.name}")}
    RETURN
  END
#{validation.guard.nil? ? '' : "END" }
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

  FacetManager.facet(:mssql) do |facet|
    facet.enhance(Repository) do
      def version=(version)
        @version = version
      end

      def version
        @version || ''
      end
    end
  end
end
