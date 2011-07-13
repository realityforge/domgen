module Domgen
  module JPA
    class JpaElement < BaseConfigElement
      attr_reader :parent

      def initialize(parent, options = {}, &block)
        @parent = parent
        super(options, &block)
      end
    end

    class Query < JpaElement
      attr_reader :name
      attr_accessor :jpql
      attr_accessor :parameter_types

      def initialize(parent, name, jpql, options = {}, & block)
        @parent = parent
        @name = name
        @jpql = jpql
        super(parent, options, & block)
      end

      def jpa_class
        self.parent
      end

      def populate_parameters
        @parameter_types = {} unless @parameter_types
        parameters.each do |p|
          @parameter_types[p] = jpa_class.object_type.attribute_by_name(p).java.java_type if @parameter_types[p].nil?
        end
      end

      def parameters
        return [] if jpql.nil?
        jpql.scan(/:[^\W]+/).collect { |s| s[1..-1] }.uniq
      end

      def qualified_name
        "#{jpa_class.object_type.java.qualified_name}.#{local_name}"
      end

      def local_name
        "#{name_prefix}#{name_suffix}"
      end

      attr_writer :query_type

      def query_type
        @query_type = :selector if @query_type.nil?
        @query_type
      end

      attr_writer :singular

      def singular?
        @singular = false if @singular.nil?
        @singular
      end

      def query_string
        if query_type == :full
          query = jpql
        elsif query_type == :selector
          query = "SELECT O FROM #{jpa_class.object_type.qualified_name} O #{jpql.nil? ? '' : "WHERE "}#{jpql}"
        else
          error("Unknown query type #{query_type}")
        end
        query.gsub("\n", ' ')
      end

      private

      def name_prefix
        "find#{singular? ? '' : 'All'}"
      end

      def name_suffix
        jpql.nil? ? '' : "By#{name}"
      end
    end

    class BaseJpaField < JpaElement
      def cascade
        @cascade || []
      end

      def cascade=(value)
        value = value.is_a?(Array) ? value : [value]
        invalid_cascades = value.select {|v| !self.class.cascade_types.include?(v)}
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

      def attribute
        self.parent
      end
    end

    class JpaClass < JpaElement
      attr_writer :table_name

      def table_name
        @table_name || object_type.sql.table_name
      end

      def object_type
        self.parent
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
        self.query('All', nil, :singular => false)
        self.query(object_type.primary_key.name,
                   "O.#{object_type.primary_key.java.field_name} = :#{object_type.primary_key.java.field_name}",
                   :singular => true)
        self.queries.each do |q|
          q.populate_parameters
        end
      end
    end

    class PersistenceUnit < JpaElement
      attr_accessor :provider
      attr_accessor :transaction_type
      attr_accessor :data_source_name

      attr_writer :name

      def name
        @name || repository.name
      end

      def repository
        self.parent
      end
    end
  end

  class ObjectType
    self.extensions << :jpa

    def jpa
      @jpa = Domgen::JPA::JpaClass.new(self) unless @jpa
      @jpa
    end
  end

  class InverseElement
    self.extensions << :jpa

    def jpa
      @jpa = Domgen::JPA::JpaFieldInverse.new(self) unless @jpa
      @jpa
    end
  end

  class Attribute
    self.extensions << :jpa

    def jpa
      @jpa = Domgen::JPA::JpaField.new(self) unless @jpa
      @jpa
    end
  end

  class Repository
    self.extensions << :jpa

    def jpa
      @jpa = Domgen::JPA::PersistenceUnit.new(self) unless @jpa
      @jpa
    end
  end
end
