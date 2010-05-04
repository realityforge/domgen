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

      def populate_parameters
        @parameter_types = {} unless @parameter_types
        parameters.each do |p|
          if @parameter_types[p].nil?
            attribute = parent.parent.attribute_by_name(p)
            raise "Unknown parameter type for #{p}" unless attribute
            @parameter_types[p] = attribute.java.java_type
          end
        end
      end

      def parameters
        return [] if jpql.nil?
        jpql.scan(/:[^\W]+/).collect { |s| s[1..-1] }
      end

      def fully_qualified_name
        if singular?
          type_spec = parent.parent.name
        else
          type_spec = pluralize(parent.parent.name)
        end
        "#{name_prefix}#{type_spec}#{name_suffix}"
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
          query = "SELECT O FROM #{parent.parent.name} O #{jpql.nil? ? '' : "WHERE "}#{jpql}"
        else
          raise "Unknown query type #{query_type}"
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

    class JpaClass < JpaElement
      def queries
        @queries ||= []
      end

      def query(name, jpql, options = {}, &block)
        query = Query.new(self, name, jpql, options, &block)
        self.queries << query
        query
      end

      def post_create
        self.query('All', nil, :singular => false)
        self.query(parent.primary_key.name,
                   "#{parent.primary_key.java.field_name} = :#{parent.primary_key.java.field_name}",
                   :singular => true)
        self.queries.each do |q|
          q.populate_parameters
        end
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
end
