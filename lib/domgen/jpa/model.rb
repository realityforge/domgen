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

Domgen::TypeDB.config_element(:'jpa.mssql') do
  attr_accessor :converter
end

Domgen::TypeDB.config_element(:'jpa.pgsql') do
  attr_accessor :converter
end

Domgen::TypeDB.config_element(:'jpa') do
  attr_accessor :converter
end

[:point, :multipoint, :linestring, :multilinestring, :polygon, :multipolygon, :geometry,
 :pointm, :multipointm, :linestringm, :multilinestringm, :polygonm, :multipolygonm].each do |type_key|
  Domgen::TypeDB.enhance(type_key,
                         'jpa.pgsql.converter' => 'org.realityforge.jeo.geolatte.jpa.PostgisConverter',
                         'jpa.mssql.converter' => 'org.realityforge.jeo.geolatte.jpa.SqlServerConverter')
end

module Domgen
  module JPA
    module BaseJpaField
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
  end

  FacetManager.facet(:jpa => [:sql, :ee]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      def version
        @version || (repository.ee.version == '6' ? '2.0' : '2.1')
      end

      def version=(version)
        raise "Unknown version '#{version}'" unless ['2.0', '2.1'].include?(version)
        @version = version
      end

      attr_writer :unit_name

      def unit_name
        @unit_name || repository.name
      end

      attr_writer :properties

      def properties
        @properties ||= {
          "eclipselink.logging.logger" => "JavaLogger",
          "eclipselink.session-name" => repository.name,
          #"eclipselink.logging.level" => "FINE",
          "eclipselink.temporal.mutable" => "false"
        }
      end

      java_artifact :unit_descriptor, :entity, :server, :jpa, '#{repository.name}PersistenceUnit'
      java_artifact :ejb_module, nil, :server, :jpa, '#{repository.name}RepositoryModule'

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

      def persistence_file_fragments
        @persistence_file_fragments ||= []
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage

      def server_dao_entity_package
        "#{server_entity_package}.dao"
      end
    end

    facet.enhance(Entity) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :table_name

      def table_name
        @table_name || entity.sql.table_name
      end

      attr_writer :jpql_name

      def jpql_name
        @jpql_name || entity.qualified_name.gsub('.', '_')
      end

      java_artifact :name, :entity, :server, :jpa, '#{entity.name}'
      java_artifact :metamodel, :entity, :server, :jpa, '#{name}_'
      java_artifact :dao_service, :entity, :server, :jpa, '#{name}Repository', :sub_package => 'dao'
      java_artifact :dao, :entity, :server, :jpa, '#{dao_service_name}EJB', :sub_package => 'dao'

      attr_writer :cacheable

      def cacheable?
        @cacheable.nil? ? false : @cacheable
      end

      attr_writer :detachable

      def detachable?
        @detachable.nil? ? false : @detachable
      end

      def entity_listeners
        @entity_listeners ||= []
      end

      def pre_verify
        entity.query(:FindAll)
        entity.query(:"FindBy#{entity.primary_key.name}")
        entity.query(:"GetBy#{entity.primary_key.name}")
        entity.queries.select { |query| query.jpa? && query.jpa.no_ql? }.each do |query|
          jpql = ''
          query_text = nil
          query_text = $1 if query.name =~ /^[fF]indAllBy(.+)$/
          query_text = $1 if query.name =~ /^[fF]indBy(.+)$/
          query_text = $1 if query.name =~ /^[gG]etBy(.+)$/
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
              jpql = "#{jpql}#{entity_prefix}#{Domgen::Naming.camelize(parameter_name)} = :#{parameter_name} #{operation} "
            else
              parameter_name = query_text
              if !entity.attribute_exists?(parameter_name)
                jpql = nil
                break
              end
              jpql = "#{jpql}#{entity_prefix}#{Domgen::Naming.camelize(parameter_name)} = :#{parameter_name}"
              break
            end
          end
          query.jpa.jpql = jpql if jpql
        end
      end
    end

    facet.enhance(Attribute) do
      include Domgen::JPA::BaseJpaField

      attr_writer :persistent

      def persistent?
        @persistent.nil? ? !attribute.abstract? : @persistent
      end

      include Domgen::Java::EEJavaCharacteristic

      attr_writer :converter

      def converter
        return nil if attribute.reference?
        return nil if attribute.enumeration?
        @converter ||
          attribute.characteristic_type.jpa.converter ||
          (Domgen::Sql.dialect.is_a?(Domgen::Sql::MssqlDialect) ?
            attribute.characteristic_type.jpa.mssql.converter :
            attribute.characteristic_type.jpa.pgsql.converter)
      end

      def field_name
        Domgen::Naming.camelize(name)
      end

      protected

      def characteristic
        attribute
      end
    end

    facet.enhance(InverseElement) do
      include Domgen::JPA::BaseJpaField

      attr_writer :orphan_removal

      def orphan_removal?
        !!@orphan_removal
      end

      def traversable=(traversable)
        Domgen.error("traversable #{traversable} is invalid") unless inverse.class.inverse_traversable_types.include?(traversable)
        @traversable = traversable
      end

      def traversable?
        @traversable.nil? ? (self.inverse.traversable? && self.inverse.attribute.referenced_entity.jpa?) : @traversable
      end

      def java_traversable=(java_traversable)
        @java_traversable = java_traversable
      end

      def java_traversable?
        @java_traversable.nil? ? traversable? : @java_traversable
      end
    end

    facet.enhance(Query) do
      def post_verify
        query_parameters = self.ql.nil? ? [] : self.ql.scan(/:[^\W]+/).collect { |s| s[1..-1] }

        expected_parameters = query_parameters.uniq
        expected_parameters.each do |parameter_name|
          if !query.parameter_exists?(parameter_name) && query.entity.attribute_exists?(parameter_name)
            attribute = query.entity.attribute_by_name(parameter_name)
            characteristic_options = {}
            characteristic_options[:enumeration] = attribute.enumeration if attribute.enumeration?
            characteristic_options[:referenced_entity] = attribute.referenced_entity if attribute.reference?
            query.parameter(attribute.name, attribute.attribute_type, characteristic_options)
          end
        end

        actual_parameters = query.parameters.collect { |p| p.name.to_s }
        if expected_parameters.sort != actual_parameters.sort
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
        q = q.gsub(/:[^\W]+/, '?') if self.native?
        q.gsub(/[\s]+/, ' ').strip
      end

      protected

      def ql=(ql)
        @ql = ql
        self.query_spec = (ql =~ /\sFROM\s/ix) ? :statement : :criteria unless @query_spec
      end
    end

    facet.enhance(QueryParameter) do
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end
  end
end
