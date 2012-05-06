module Domgen
  module JPA
    class QueryParameter < Domgen.ParentedElement(:query)
      include Characteristic
      include Domgen::Java::EEJavaCharacteristic

      attr_reader :parameter_type
      attr_reader :name

      def initialize(message, name, parameter_type, options, &block)
        @name = name
        @parameter_type = parameter_type
        super(message, options, &block)
      end

      def qualified_name
        "#{query.qualified_name}$#{self.name}"
      end

      def to_s
        "QueryParameter[#{self.qualified_name}]"
      end

      def characteristic_type
        parameter_type
      end

      def characteristic
        self
      end

      def characteristic_kind
        "parameter"
      end
    end

    class Query < Domgen.ParentedElement(:jpa_class)
      include Domgen::CharacteristicContainer

      attr_reader :name

      def initialize(jpa_class, name, ql, options = {}, & block)
        @name = name
        @ql = ql
        super(jpa_class, options, & block)

        query_parameters = self.ql.nil? ? [] : self.ql.scan(/:[^\W]+/).collect { |s| s[1..-1] }

        expected_parameters = query_parameters.uniq.sort

        expected_parameters.each do |parameter_name|
          if !characteristic_exists?(parameter_name) && jpa_class.entity.attribute_exists?(parameter_name)
            attribute = jpa_class.entity.attribute_by_name(parameter_name)
            characteristic_options = {}
            if attribute.attribute_type == :enumeration
              characteristic_options[:enumeration] = attribute.enumeration
            end
            characteristic(attribute.name, attribute.attribute_type, characteristic_options)
          end
        end

        actual_parameters = parameters.collect{|p|p.name.to_s}.sort
        if expected_parameters != actual_parameters
          raise "Actual parameters for query #{self.qualified_name} (#{actual_parameters.inspect}) do not match expected parameters #{expected_parameters.inspect}"
        end

        @query_ordered_parameters = []
        query_parameters.each do |query_parameter|
          @query_ordered_parameters << characteristic_by_name(query_parameter)
        end
      end

      attr_writer :native

      def native?
        @native.nil? ? false : @native
      end

      def ql
        @ql
      end

      def no_ql?
        @ql.nil?
      end

      def jpql=(ql)
        @native = false
        @ql = ql
      end

      def jpql
        raise "Called jpql for native query" if self.native?
        @ql
      end

      def sql=(ql)
        @native = false
        @ql = ql
      end

      def sql
        raise "Called sql for non-native query" unless self.native?
        @ql
      end

      # An array of parameters ordered as they appear in query and with possible duplicates
      def query_ordered_parameters
        @query_ordered_parameters
      end

      def parameters
        characteristics
      end

      def qualified_name
        "#{jpa_class.entity.qualified_name}.#{local_name}"
      end

      def local_name
        if self.query_type == :select
          suffix = no_ql? ? '' : "By#{name}"
          if self.multiplicity == :many
            "findAll#{suffix}"
          elsif self.multiplicity == :zero_or_one
            "find#{suffix}"
          else
            "get#{suffix}"
          end
        elsif self.query_type == :update
          "update#{name}"
        elsif self.query_type == :delete
          "delete#{name}"
        elsif self.query_type == :insert
          "insert#{name}"
        end
      end

      def query_type=(query_type)
        error("query_type #{query_type} is invalid") unless self.class.valid_query_types.include?(query_type)
        @query_type = query_type
      end

      def query_type
        @query_type || :select
      end

      def query_spec=(query_spec)
        error("query_spec #{query_spec} is invalid") unless self.class.valid_query_specs.include?(query_spec)
        @query_spec = query_spec
      end

      def query_spec
        @query_spec || (ql =~ /\sFROM\s/ix) ? :statement : :criteria
      end

      def multiplicity
        @multiplicity || :many
      end

      def multiplicity=(multiplicity)
        error("multiplicity #{multiplicity} is invalid") unless Domgen::InverseElement.inverse_multiplicity_types.include?(multiplicity)
        @multiplicity = multiplicity
      end

      def query_string
        table_name = self.native? ? jpa_class.entity.sql.table_name : jpa_class.entity.jpa.jpql_name
        criteria_clause = "#{no_ql? ? '' : "WHERE "}#{ql}"
        if self.query_spec == :statement
          query = self.ql
        elsif self.query_spec == :criteria
          if self.query_type == :select
            if self.native?
              query = "SELECT O.* FROM #{table_name} O #{criteria_clause}"
            else
              query = "SELECT O FROM #{table_name} O #{criteria_clause}"
            end
          elsif self.query_type == :update
            raise "The combination of query_type == :update and query_spec == :criteria is not supported"
          elsif self.query_type == :insert
            raise "The combination of query_type == :insert and query_spec == :criteria is not supported"
          elsif self.query_type == :delete
            if self.native?
              query = "DELETE FROM #{table_name} FROM #{table_name} O #{criteria_clause}"
            else
              query = "DELETE FROM #{table_name} O #{criteria_clause}"
            end
          else
            error("Unknown query type #{query_type}")
          end
        else
          error("Unknown query spec #{query_spec}")
        end
        query = query.gsub(/:[^\W]+/,'?') if self.native?
        query.gsub(/[\s]+/, ' ').strip
      end

      def self.valid_query_specs
        [:statement, :criteria]
      end

      def self.valid_query_types
        [:select, :update, :delete, :insert]
      end

      def to_s
        "Query[#{self.qualified_name}]"
      end

      protected

      def characteristic_kind
        raise "parameter"
      end

      def data_module
        jpa_class.entity.data_module
      end

      def new_characteristic(name, type, options, &block)
        QueryParameter.new(self, name, type, options, &block)
      end

      def perform_verify
        verify_characteristics
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
          error("cascade_type must be one of #{self.class.cascade_types.join(", ")}, not #{invalid_cascades.join(", ")}")
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
        error("fetch_type #{fetch_type} is not recorgnized") unless self.class.fetch_types.include?(fetch_type)
        @fetch_type = fetch_type
      end

      def self.fetch_types
        [:eager, :lazy]
      end

      attr_reader :fetch_mode

      def fetch_mode=(fetch_mode)
        error("fetch_mode #{fetch_mode} is not recorgnized") unless self.class.fetch_modes.include?(fetch_mode)
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
        error("traversable #{traversable} is invalid") unless inverse.class.inverse_traversable_types.include?(traversable)
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

      attr_writer :dao_name

      def dao_name
        @dao_name || "#{entity.name}DAO"
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

      def queries
        @queries ||= []
      end

      def query(name, jpql, options = {}, &block)
        query = Query.new(self, name, jpql, options, &block)
        self.queries << query
        query
      end

      def post_verify
        self.query('All', nil, :multiplicity => :many)
        self.query(entity.primary_key.name,
                   "O.#{entity.primary_key.jpa.name} = :#{entity.primary_key.jpa.name}",
                   :multiplicity => :one)
        self.query(entity.primary_key.name,
                   "O.#{entity.primary_key.jpa.name} = :#{entity.primary_key.jpa.name}",
                   :multiplicity => :zero_or_one)
      end
    end

    class JpaPackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::JavaPackage

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

      protected

      def facet_key
        :ee
      end
    end

    class PersistenceUnit < Domgen.ParentedElement(:repository)
      attr_writer :unit_name

      def unit_name
        @unit_name || repository.name
      end

      include Domgen::Java::ServerJavaApplication

      attr_writer :data_source

      def data_source
        @data_source || "jdbc/#{repository.name}DS"
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
                              Attribute => Domgen::JPA::JpaField,
                              InverseElement => Domgen::JPA::JpaFieldInverse,
                              Entity => Domgen::JPA::JpaClass,
                              DataModule => Domgen::JPA::JpaPackage,
                              Repository => Domgen::JPA::PersistenceUnit
                            },
                            [:sql, :ee])
end
