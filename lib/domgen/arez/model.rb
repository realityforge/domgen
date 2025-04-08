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
  module Arez
    class DefaultValues < Domgen.ParentedElement(:entity)
      def initialize(entity, defaults, options = {}, &block)
        raise "Attempted to define test_default on abstract entity #{entity.qualified_name}" if entity.abstract?
        raise "Attempted to define test_default on #{entity.qualified_name} with no values" if defaults.empty?
        defaults.keys.each do |key|
          raise "Attempted to define test_default on #{entity.qualified_name} with key '#{key}' that is not an attribute value" unless entity.attribute_by_name?(key)
          a = entity.attribute_by_name(key)
          raise "Attempted to define test_default on #{entity.qualified_name} for attribute '#{key}' when attribute has no arez facet defined. Defaults = #{defaults.inspect}" unless a.arez?
        end
        values = {}
        defaults.each_pair do |k, v|
          values[k.to_s] = v
        end
        @values = values

        super(entity, options, &block)
      end

      def has_attribute?(name)
        @values.keys.include?(name.to_s)
      end

      def value_for(name)
        @values[name.to_s]
      end

      def values
        @values.dup
      end
    end
  end

  FacetManager.facet(:arez => [:ce]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      def client_ioc_package
        repository.gwt.client_ioc_package
      end

      java_artifact :factory_set, :entity, :client, :arez, '#{repository.name}FactorySet'
      java_artifact :root_repository, :entity, :client, :arez, '#{repository.name}RootRepository'
      java_artifact :locator_factory, :entity, :client, :arez, '#{repository.name}LocatorFactory'
      java_artifact :locator_sting_fragment, :entity, :client, :arez, '#{repository.name}LocatorFragment'

      def pre_verify
        if repository.gwt?
          repository.gwt.sting_includes << qualified_locator_sting_fragment_name
        end
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::ImitJavaPackage

      attr_writer :short_test_code

      def short_test_code
        @short_test_code || Reality::Naming.split_into_words(data_module.name.to_s).collect {|w| w[0, 1]}.join.downcase
      end

      java_artifact :test_factory, :entity, :client, :arez, '#{data_module.name}Factory'
      java_artifact :test_factory_extension, :entity, :client, :arez, '#{data_module.name}FactoryExtension'

      def factory_required?
        data_module.daos.any?{|dao| dao.arez?} || data_module.entities.any?{|entity| entity.arez?}
      end
    end

    facet.enhance(DataAccessObject) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :repository, :entity, :client, :arez, '#{dao.entity.name}Repository'

      def extensions
        @extensions ||= []
      end

      def pre_complete
        dao.disable_facet(:arez) if !dao.repository? || !dao.entity.arez?
      end

      def post_verify
        # This is needed because sometimes dao construction is deferred until later
        dao.disable_facet(:arez) if !dao.repository? || !dao.entity.arez?
      end
    end

    facet.enhance(Query) do
      def disable_facet_unless_valid(verify_standard_query = false)
        disable = false
        disable = true if query.result_entity? && !query.entity.arez?
        disable = true unless query.query_type == :select
        disable = true if query.parameters.size != query.parameters.select {|p| p.arez?}.size
        entity = query.dao.repository? ? query.dao.entity : nil
        if verify_standard_query
          disable = true if entity && query.name.to_s == 'FindAll'
          disable = true if entity && query.name.to_s == "FindBy#{entity.primary_key.name}"
          disable = true if entity && query.name.to_s == "GetBy#{entity.primary_key.name}"
          disable = true unless query.standard_query?
        end

        query.disable_facet(:arez) if query.arez? && disable
      end

      def pre_complete
        disable_facet_unless_valid
      end

      def perform_complete
        disable_facet_unless_valid
      end

      def perform_verify
        disable_facet_unless_valid(true)
      end

      def post_verify
        disable_facet_unless_valid(true)
      end
    end

    facet.enhance(QueryParameter) do
      include Domgen::Java::ImitJavaCharacteristic

      def disable_facet_unless_valid
        disable = false
        disable = true if parameter.reference? && !parameter.referenced_entity.arez?
        parameter.disable_facet(:arez) if parameter.arez? && disable
      end

      def pre_complete
        disable_facet_unless_valid
      end

      def pre_verify
        disable_facet_unless_valid
      end

      protected

      def characteristic
        parameter
      end
    end

    facet.enhance(Entity) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :name, :entity, :client, :arez, '#{entity.name}'
      java_artifact :arez, :entity, :client, :arez, 'Arez_#{entity.name}'

      def access_entities_outside_transaction?
        @access_entities_outside_transaction.nil? ? false : !!@access_entities_outside_transaction
      end

      attr_writer :access_entities_outside_transaction

      def extensions
        @extensions ||= []
      end

      def test_create_default(defaults)
        (@test_create_defaults ||= []) << Domgen::Arez::DefaultValues.new(entity, defaults)
      end

      def test_create_defaults
        @test_create_defaults.nil? ? [] : @test_create_defaults.dup
      end

      def referencing_client_side_attributes
        entity.referencing_attributes.select do |attribute|
          attribute.entity.arez? &&
            attribute.inverse.arez? &&
            attribute.inverse.arez.traversable? &&
            entity == attribute.referenced_entity &&
            attribute.arez? &&
            attribute.referenced_entity.arez?
        end
      end

      def pre_complete
        if entity.data_module.repository.gwt? && entity.concrete?
          entity.data_module.repository.gwt.sting_includes << "#{qualified_name}Repository"
        end
      end
    end

    facet.enhance(Attribute) do
      def eager?
        !lazy?
      end

      def lazy=(lazy)
        Domgen.error("Attempted to make non-reference #{attribute.qualified_name} lazy") if lazy && !attribute.reference?
        @lazy = lazy
      end

      def lazy?
        attribute.reference? && (@lazy.nil? ? false : @lazy)
      end

      include Domgen::Java::ImitJavaCharacteristic

      def pre_complete
        attribute.disable_facet(:arez) if attribute.reference? && !attribute.referenced_entity.arez?
      end

      protected

      def characteristic
        attribute
      end
    end

    facet.enhance(InverseElement) do
      def traversable=(traversable)
        Domgen.error("traversable #{traversable} is invalid") unless inverse.class.inverse_traversable_types.include?(traversable)
        @traversable = traversable
      end

      def traversable?
        @traversable.nil? ? (self.inverse.traversable? && self.inverse.attribute.referenced_entity.arez?) : @traversable
      end

      def multiplicity
        return self.inverse.multiplicity if [:many, :zero_or_one].include?(self.inverse.multiplicity) || !self.inverse.imit?

        # If we get here then it is imit enabled. We check whether the other entity is always
        # part of the same graphs as this entity and if so then we can return false because
        # we have a :one multiplicity and they are always together on the client. If we potentially
        # do not have inverse entity because it is not in the same graph then we mark this as zero_or_one

        other_graphs = self.inverse.attribute.referenced_entity.imit.replication_graphs
        self_graphs = self.inverse.attribute.entity.imit.replication_graphs

        other_graphs.any?{|g|!self_graphs.include?(g)} ? :zero_or_one : :one
      end

      def nullable?
        return false if :many == self.inverse.multiplicity
        return true if :zero_or_one == self.inverse.multiplicity
        return false unless self.inverse.imit?

        # If we get here then it is imit enabled. We check whether the other entity is always
        # part of the same graphs as this entity and if so then we can return false because
        # we a :one multiplicity and they are always together on the client. If we potentially
        # do not have inverse entity because it is not in the same graph then we mark this as nullable

        other_graphs = self.inverse.attribute.referenced_entity.imit.replication_graphs
        self_graphs = self.inverse.attribute.entity.imit.replication_graphs

        other_graphs.any?{|g|!self_graphs.include?(g)}
      end
    end
  end
end
