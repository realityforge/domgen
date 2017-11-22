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

      java_artifact :root_repository, :entity, :client, :arez, '#{repository.name}RootRepository'
      java_artifact :entity_locator, :entity, :client, :arez, '#{repository.name}EntityLocator'
      java_artifact :dao_gin_module, :ioc, :client, :arez, '#{repository.name}ArezDaoGinModule'
      java_artifact :dao_dagger_module, :ioc, :client, :arez, '#{repository.name}ArezDao#{repository.dagger.module_suffix}'
      java_artifact :dao_test_module, :test, :client, :arez, '#{repository.name}ArezDaoTestModule', :sub_package => 'util'
      java_artifact :entity_complete_module, :test, :client, :arez, '#{repository.name}EntityModule', :sub_package => 'util'
      java_artifact :test_factory_module, :test, :client, :arez, '#{repository.name}FactorySetModule', :sub_package => 'util'

      def pre_verify
        if repository.imit?
          repository.imit.add_test_module(dao_test_module_name, qualified_dao_test_module_name)
          repository.imit.add_test_module(test_factory_module_name, qualified_test_factory_module_name)
        end
        if repository.gwt?
          repository.gwt.add_gin_module(dao_gin_module_name, qualified_dao_gin_module_name)
          repository.gwt.add_test_module(dao_test_module_name, qualified_dao_test_module_name)
          repository.gwt.add_test_module(test_factory_module_name, qualified_test_factory_module_name)
        end
      end

      def post_verify
        repository.data_modules.select {|data_module| data_module.arez?}.each do |data_module|
          repository.imit.add_test_factory(data_module.arez.short_test_code, data_module.arez.qualified_test_factory_name) if repository.imit?
          repository.gwt.add_test_factory(data_module.arez.short_test_code, data_module.arez.qualified_test_factory_name) if repository.gwt?
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

      java_artifact :abstract_test_factory, :entity, :client, :arez, 'Abstract#{data_module.name}Factory'
      java_artifact :data_module_repository, :entity, :client, :arez, '#{data_module.name}DataModuleRepository'

      attr_writer :test_factory_name

      def test_factory_name
        @test_factory_name || abstract_test_factory_name.gsub(/^Abstract/, '')
      end

      def qualified_test_factory_name
        "#{client_entity_package}.#{test_factory_name}"
      end
    end

    facet.enhance(DataAccessObject) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :repository, :entity, :client, :arez, '#{dao.entity.name}Repository'
      java_artifact :base_repository_extension, :entity, :client, :arez, '#{dao.entity.name}BaseRepositoryExtension'
      java_artifact :default_repository_extension, :entity, :client, :arez, '#{dao.entity.name}RepositoryExtension'
      java_artifact :domgen_repository_extension, :entity, :client, :arez, 'Domgen#{dao.name}Extension'

      def extensions
        @extensions ||= []
      end

      def pre_complete
        dao.disable_facet(:arez) if !dao.repository? || !dao.entity.arez?

        self.extensions << qualified_domgen_repository_extension_name if dao.arez?
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

    facet.enhance(RemoteEntity) do
      include Domgen::Java::BaseJavaGenerator

      def remote_datasource
        Domgen.error("Invoked remote_datasource on #{remote_entity.qualified_name} when value not set") unless @remote_datasource
        @remote_datasource
      end

      def remote_datasource=(remote_datasource)
        @remote_datasource = (remote_datasource.is_a?(Domgen::Imit::RemoteDatasource) ? remote_datasource : remote_entity.data_module.repository.imit.remote_datasource_by_name(remote_datasource))
      end

      attr_writer :qualified_name

      def qualified_name
        @qualified_name || "#{remote_datasource.base_package}.client.entity.#{remote_entity.name}"
      end
    end

    facet.enhance(RemoteEntityAttribute) do
      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        attribute
      end
    end

    facet.enhance(Entity) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :name, :entity, :client, :arez, '#{entity.name}'
      java_artifact :arez, :entity, :client, :arez, 'Arez_#{entity.name}'
      java_artifact :base_entity_extension, :entity, :client, :arez, 'Base#{entity.name}Extension'

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
    end

    facet.enhance(Attribute) do
      def eager?
        !lazy?
      end

      def lazy=(lazy)
        Domgen.error("Attempted to make non-reference #{attribute.qualified_name} lazy") if lazy && !(attribute.reference? || attribute.remote_reference?)
        @lazy = lazy
      end

      def lazy?
        (attribute.reference? || attribute.remote_reference?) && (@lazy.nil? ? false : @lazy)
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
    end
  end
end
