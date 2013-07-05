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
  module JPA
    class JPAQueryParameter < Domgen.ParentedElement(:parameter)
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    class JPAQuery < Domgen.ParentedElement(:query)
      def post_verify
        query_parameters = self.ql.nil? ? [] : self.ql.scan(/:[^\W]+/).collect { |s| s[1..-1] }

        expected_parameters = query_parameters.uniq.sort
        expected_parameters.each do |parameter_name|
          if !query.parameter_exists?(parameter_name) && query.entity.attribute_exists?(parameter_name)
            attribute = query.entity.attribute_by_name(parameter_name)
            characteristic_options = {}
            characteristic_options[:enumeration] = attribute.enumeration if attribute.attribute_type == :enumeration
            query.parameter(attribute.name, attribute.attribute_type, characteristic_options)
          end
        end

        actual_parameters = query.parameters.collect{|p|p.name.to_s}.sort
        if expected_parameters != actual_parameters
          Domgen.error("Actual parameters for query #{query.qualified_name} (#{actual_parameters.inspect}) do not match expected parameters #{expected_parameters.inspect}")
        end
      end

      def query_spec=(query_spec)
        Domgen.error("query_spec #{query_spec} is invalid") unless self.class.valid_query_specs.include?(query_spec)
        @query_spec = query_spec
      end

      def query_spec
        @query_spec || :criteria
      end

      def self.valid_query_specs
        [:statement, :criteria]
      end

      attr_writer :native

      def native?
        @native.nil? ? false : @native
      end

      attr_accessor :limit

      attr_accessor :offset

      attr_accessor :order_by

      def ql
        @ql
      end

      def no_ql?
        @ql.nil?
      end

      def jpql=(ql)
        @native = false
        self.ql = ql
      end

      def jpql
        Domgen.error("Called jpql for native query") if self.native?
        @ql
      end

      def sql=(ql)
        @native = true
        self.ql = ql
      end

      def sql
        Domgen.error("Called sql for non-native query") unless self.native?
        @ql
      end

      # An array of parameters ordered as they appear in query and with possible duplicates
      def query_ordered_parameters
        unless @query_ordered_parameters
          query_parameters = self.ql.nil? ? [] : self.ql.scan(/:[^\W]+/).collect { |s| s[1..-1] }
          @query_ordered_parameters = []
          query_parameters.each do |query_parameter|
            @query_ordered_parameters << query.parameter_by_name(query_parameter)
          end
        end
        @query_ordered_parameters
      end

      def query_string
        table_name = self.native? ? query.entity.sql.table_name : query.entity.jpa.jpql_name
        order_by_clause = order_by ? " ORDER BY #{order_by}" : ""
        criteria_clause = "#{no_ql? ? '' : "WHERE "}#{ql}"
        q = nil
        if self.query_spec == :statement
          q = self.ql
        elsif self.query_spec == :criteria
          if query.query_type == :select
            if self.native?
              q = "SELECT O.* FROM #{table_name} O #{criteria_clause}#{order_by_clause}"
            else
              q = "SELECT O FROM #{table_name} O #{criteria_clause}#{order_by_clause}"
            end
          elsif query.query_type == :update
            Domgen.error("The combination of query.query_type == :update and query_spec == :criteria is not supported")
          elsif query.query_type == :insert
            Domgen.error("The combination of query.query_type == :insert and query_spec == :criteria is not supported")
          elsif query.query_type == :delete
            if self.native?
              q = "DELETE FROM #{table_name} FROM #{table_name} O #{criteria_clause}"
            else
              q = "DELETE FROM #{table_name} O #{criteria_clause}"
            end
          else
            Domgen.error("Unknown query type #{query.query_type}")
          end
        else
          Domgen.error("Unknown query spec #{self.query_spec}")
        end
        q = q.gsub(/:[^\W]+/,'?') if self.native?
        q.gsub(/[\s]+/, ' ').strip
      end

      protected

      def ql=(ql)
        @ql = ql
        self.query_spec = (ql =~ /\sFROM\s/ix) ? :statement : :criteria
      end
    end

    class BaseJpaField < Domgen.ParentedElement(:parent)
      def cascade
        @cascade || []
      end

      def cascade=(value)
        value = value.is_a?(Array) ? value : [value]
        invalid_cascades = value.select { |v| !self.class.cascade_types.include?(v) }
        unless invalid_cascades.empty?
          Domgen.error("cascade_type must be one of #{self.class.cascade_types.join(", ")}, not #{invalid_cascades.join(", ")}")
        end
        @cascade = value
      end

      def self.cascade_types
        [:all, :persist, :merge, :remove, :refresh, :detach]
      end

      def fetch_type
        @fetch_type || :lazy
      end

      def fetch_type=(fetch_type)
        Domgen.error("fetch_type #{fetch_type} is not recognized") unless self.class.fetch_types.include?(fetch_type)
        @fetch_type = fetch_type
      end

      def self.fetch_types
        [:eager, :lazy]
      end

      attr_reader :fetch_mode

      def fetch_mode=(fetch_mode)
        Domgen.error("fetch_mode #{fetch_mode} is not recognized") unless self.class.fetch_modes.include?(fetch_mode)
        @fetch_mode = fetch_mode
      end

      def self.fetch_modes
        [:select, :join, :subselect]
      end
    end

    class JpaFieldInverse < BaseJpaField
      attr_writer :orphan_removal

      def orphan_removal?
        !!@orphan_removal
      end

      def inverse
        self.parent
      end

      def traversable=(traversable)
        Domgen.error("traversable #{traversable} is invalid") unless inverse.class.inverse_traversable_types.include?(traversable)
        @traversable = traversable
      end

      def traversable?
        @traversable.nil? ? (self.inverse.traversable? && self.inverse.attribute.referenced_entity.jpa?) : @traversable
      end
    end

    class JpaField < BaseJpaField
      attr_writer :persistent

      def persistent?
        @persistent.nil? ? !attribute.abstract? : @persistent
      end

      def attribute
        self.parent
      end

      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        attribute
      end
    end

    class JpaClass < Domgen.ParentedElement(:entity)
      attr_writer :table_name

      def table_name
        @table_name || entity.sql.table_name
      end

      attr_writer :jpql_name

      def jpql_name
        @jpql_name || entity.qualified_name.gsub('.','_')
      end

      attr_writer :name

      def name
        @name || entity.name
      end

      def qualified_name
        "#{entity.data_module.jpa.entity_package}.#{name}"
      end

      def metamodel_name
        "#{name}_"
      end

      def qualified_metamodel_name
        "#{entity.data_module.jpa.entity_package}.#{metamodel_name}"
      end

      attr_writer :dao_service_name

      def dao_service_name
        @dao_service_name || "#{entity.name}Repository"
      end

      def qualified_dao_service_name
        "#{entity.data_module.jpa.dao_package}.#{dao_service_name}"
      end

      attr_writer :dao_name

      def dao_name
        @dao_name || "#{dao_service_name}EJB"
      end

      def qualified_dao_name
        "#{entity.data_module.jpa.dao_package}.#{dao_name}"
      end

      attr_writer :cacheable

      def cacheable?
        @cacheable.nil? ? false : @cacheable
      end

      attr_writer :detachable

      def detachable?
        @detachable.nil? ? false : @detachable
      end

      def pre_verify
        entity.query('findAll')
        entity.query("findBy#{entity.primary_key.name}")
        entity.query("getBy#{entity.primary_key.name}")
        entity.queries.select { |query| query.jpa? && query.jpa.no_ql? }.each do |query|
          jpql = ''
          query_text = nil
          query_text = $1 if query.name =~ /^findAllBy(.+)$/
          query_text = $1 if query.name =~ /^findBy(.+)$/
          query_text = $1 if query.name =~ /^getBy(.+)$/
          next unless query_text

          entity_prefix = "O."

          while true
            if query_text =~ /(.+)(And|Or)(.+)/
              parameter_name = $1
              query_text = $3
              if !entity.attribute_exists?(parameter_name)
                jpql = nil
                break
              end
              operation = $2.upcase
              jpql = "#{jpql}#{entity_prefix}#{parameter_name} = :#{parameter_name} #{operation} "
            else
              parameter_name = query_text
              if !entity.attribute_exists?(parameter_name)
                jpql = nil
                break
              end
              jpql = "#{jpql}#{entity_prefix}#{parameter_name} = :#{parameter_name}"
              break
            end
          end
          query.jpa.jpql = jpql if jpql
        end
      end
    end

    class JpaPackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::EEJavaPackage

      attr_writer :catalog_name

      def catalog_name
        @catalog_name || "#{data_module.name}Catalog"
      end

      def qualified_catalog_name
        "#{entity_package}.#{catalog_name}"
      end

      attr_writer :dao_package

      def dao_package
        @dao_package || "#{entity_package}.dao"
      end
    end

    class PersistenceUnit < Domgen.ParentedElement(:repository)
      attr_writer :unit_name

      def unit_name
        @unit_name || repository.name
      end

      include Domgen::Java::ServerJavaApplication

      attr_writer :properties

      def properties
        @properties ||= {"eclipselink.logging.logger" => "JavaLogger",
                         #"eclipselink.logging.level" => "FINE",
                         "eclipselink.temporal.mutable" => "false"}
      end

      attr_writer :ejb_module_name

      def ejb_module_name
        @ejb_module_name || "#{repository.name}RepositoryModule"
      end

      def qualified_ejb_module_name
        "#{package}.#{ejb_module_name}"
      end

      attr_writer :data_source

      def data_source
        @data_source || "jdbc/#{repository.name}"
      end

      attr_writer :exclude_unlisted_classes

      def exclude_unlisted_classes?
        @exclude_unlisted_classes.nil? ? true : @exclude_unlisted_classes
      end

      attr_accessor :provider

      def provider_class
        return "org.eclipse.persistence.jpa.PersistenceProvider" if provider == :eclipselink
        return "org.hibernate.ejb.HibernatePersistence" if provider == :hibernate
        return nil if provider.nil?

      end
    end
  end

  FacetManager.define_facet(:jpa,
                            {
                              QueryParameter => Domgen::JPA::JPAQueryParameter,
                              Query => Domgen::JPA::JPAQuery,
                              Attribute => Domgen::JPA::JpaField,
                              InverseElement => Domgen::JPA::JpaFieldInverse,
                              Entity => Domgen::JPA::JpaClass,
                              DataModule => Domgen::JPA::JpaPackage,
                              Repository => Domgen::JPA::PersistenceUnit
                            },
                            [:sql, :ee])
end
