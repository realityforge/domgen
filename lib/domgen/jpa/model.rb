module Domgen
  module JPA
    DEFAULT_ENTITY_PACKAGE_SUFFIX = "entity"

    class Query < Domgen.ParentedElement(:jpa_class)
      attr_reader :name
      attr_accessor :parameter_types

      def initialize(jpa_class, name, ql, options = {}, & block)
        @name = name
        @ql = ql
        super(jpa_class, options, & block)
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

      def populate_parameters
        @parameter_types = {} unless @parameter_types
        parameters.each do |p|
          @parameter_types[p] = jpa_class.object_type.attribute_by_name(p).jpa.java_type if @parameter_types[p].nil?
        end
      end

      def parameters
        return [] if self.ql.nil?
        self.ql.scan(/:[^\W]+/).collect { |s| s[1..-1] }.uniq
      end

      def qualified_name
        "#{jpa_class.object_type.qualified_name}.#{local_name}"
      end

      def local_name
        "#{name_prefix}#{name_suffix}"
      end

      attr_writer :query_type

      def query_type
        @query_type || :selector
      end

      def multiplicity
        @multiplicity || :many
      end

      def multiplicity=(multiplicity)
        error("multiplicity #{multiplicity} is invalid") unless Domgen::InverseElement.inverse_multiplicity_types.include?(multiplicity)
        @multiplicity = multiplicity
      end

      def query_string
        if self.query_type == :full
          query = self.ql
        elsif self.query_type == :selector
          if self.native?
            query = "SELECT O.* FROM #{jpa_class.object_type.sql.table_name} O #{no_ql? ? '' : "WHERE "}#{sql}"
          else
            query = "SELECT O FROM #{jpa_class.object_type.jpa.jpql_name} O #{no_ql? ? '' : "WHERE "}#{jpql}"
          end
        else
          error("Unknown query type #{query_type}")
        end
        query.gsub("\n", ' ')
      end

      private

      def name_prefix
        if self.multiplicity == :many
          "findAll"
        elsif self.multiplicity == :zero_or_one
          "find"
        else
          "get"
        end
      end

      def name_suffix
        no_ql? ? '' : "By#{name}"
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
    end

    class JpaField < BaseJpaField
      attr_writer :persistent

      def persistent?
        @persistent.nil? ? (!attribute.abstract? && attribute.persistent?) : @persistent
      end

      def name
        attribute.name
      end

      def attribute
        self.parent
      end

      include Domgen::Java::JavaCharacteristic

      protected

      def characteristic
        attribute
      end

      def object_type_to_classname(object_type)
        object_type.jpa.qualified_entity_name
      end

      def enumeration_to_classname(enumeration)
        enumeration.jpa.qualified_enumeration_name
      end
    end

    class JpaEnumeration < Domgen.ParentedElement(:enumeration)
      def enumeration_name
        "#{enumeration.name}"
      end

      def qualified_enumeration_name
        "#{enumeration.data_module.jpa.entity_package}.#{enumeration.name}"
      end
    end

    class JpaClass < Domgen.ParentedElement(:object_type)
      attr_writer :table_name

      def table_name
        @table_name || object_type.sql.table_name
      end

      attr_writer :jpql_name

      def jpql_name
        @jpql_name || object_type.qualified_name.gsub('.','_')
      end

      attr_writer :entity_name

      def entity_name
        @entity_name || object_type.name
      end

      def qualified_entity_name
        "#{object_type.data_module.jpa.entity_package}.#{entity_name}"
      end

      def metamodel_name
        "#{entity_name}_"
      end

      def qualified_metamodel_name
        "#{object_type.data_module.jpa.entity_package}.#{metamodel_name}"
      end

      attr_writer :dao_name

      def dao_name
        @dao_name || "#{object_type.name}DAO"
      end

      def qualified_dao_name
        "#{object_type.data_module.jpa.dao_package}.#{dao_name}"
      end

      attr_writer :persistent

      def persistent?
        @persistent.nil? ? true : @persistent
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
        self.query(object_type.primary_key.name,
                   "O.#{object_type.primary_key.jpa.name} = :#{object_type.primary_key.jpa.name}",
                   :multiplicity => :one)
        self.query(object_type.primary_key.name,
                   "O.#{object_type.primary_key.jpa.name} = :#{object_type.primary_key.jpa.name}",
                   :multiplicity => :zero_or_one)
        self.queries.each do |q|
          q.populate_parameters
        end
      end
    end

    class JpaPackage < Domgen.ParentedElement(:data_module)
      attr_writer :entity_package

      def entity_package
        @entity_package || "#{data_module.repository.jpa.entity_package}.#{Domgen::Naming.underscore(data_module.name)}"
      end

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
      attr_accessor :unit_name

      attr_writer :entity_package

      def entity_package
        @entity_package || "#{Domgen::Naming.underscore(repository.name)}.#{DEFAULT_ENTITY_PACKAGE_SUFFIX}"
      end
    end
  end

  FacetManager.define_facet(:jpa,
                            EnumerationSet => Domgen::JPA::JpaEnumeration,
                            Attribute => Domgen::JPA::JpaField,
                            InverseElement => Domgen::JPA::JpaFieldInverse,
                            ObjectType => Domgen::JPA::JpaClass,
                            DataModule => Domgen::JPA::JpaPackage,
                            Repository => Domgen::JPA::PersistenceUnit)
end
