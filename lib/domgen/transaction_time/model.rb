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

# Transaction time facet
module Domgen
  FacetManager.facet(:transaction_time) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      attr_writer :base_entity_validation_exception_name

      def base_entity_validation_exception_name
        @base_entity_validation_exception_name || "#{repository.name}.#{repository.name}"
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::EEClientServerJavaPackage

      attr_writer :base_entity_validation_exception_name

      def base_entity_validation_exception_name
        @base_entity_validation_exception_name || self.data_module.repository.transaction_time.base_entity_validation_exception_name
      end
    end

    facet.enhance(Entity) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :jpa_model_extension, :entity, :server, :jpa, '#{entity.name}TransactionTimeExtension'

      def qualified_jpa_exception_name
        self.entity.data_module.exception_by_name("#{self.entity.name}InPast").ee.qualified_name
      end

      def pre_pre_complete
        attribute =
          self.entity.attribute_by_name?(:CreatedAt) ?
            self.entity.attribute_by_name(:CreatedAt) :
            self.entity.datetime(:CreatedAt, :immutable => true)

        attribute.disable_facet(:sync) if attribute.sync?

        attribute =
          self.entity.attribute_by_name?(:DeletedAt) ?
            self.entity.attribute_by_name(:DeletedAt) :
            self.entity.datetime(:DeletedAt, :set_once => true, :nullable => true)
        attribute.disable_facet(:sync) if attribute.sync?
      end

      def pre_complete
        exception_name = "#{self.entity.name}InPast"
        exception =
          self.entity.data_module.exception_by_name?(exception_name) ?
            self.entity.data_module.exception_by_name(exception_name) :
            self.entity.data_module.exception(exception_name)
        unless exception.extends
          exception.extends = self.entity.data_module.repository.transaction_time.base_entity_validation_exception_name
        end
        if exception.parameters.empty?
          exception.description = "Attempted an operation on an instance of #{self.entity.qualified_name} that is deleted"
          exception.reference(self.entity.name)
        end

        self.entity.jpa.interfaces << self.qualified_jpa_model_extension_name if self.entity.jpa?
      end

      def post_complete
        self.entity.unique_constraints.each do |constraint|
          # Force the creation of the index with filter specified. Parallels behaviours in sql facet.
          index = self.entity.sql.index(constraint.attribute_names, :unique => true)
          index.filter = "#{self.entity.sql.dialect.quote(:DeletedAt)} IS NULL"
        end if self.entity.sql?
        if self.entity.jpa?
          self.entity.jpa.default_jpql_criterion = 'O.deletedAt IS NULL'
          self.entity.jpa.create_default(:CreatedAt => 'now()', :DeletedAt => 'null')
          self.entity.jpa.update_default(:DeletedAt => nil)
          self.entity.jpa.update_defaults.each do |defaults|
            self.entity.jpa.update_default(defaults.values.merge(:DeletedAt => nil)) do |new_default|
              new_default.factory_method_name = defaults.factory_method_name
            end
            self.entity.jpa.remove_update_default(defaults)
          end
        end
        if self.entity.graphql? && self.entity.dao.graphql?
          self.entity.attribute_by_name(:CreatedAt).graphql.initial_value = 'new java.util.Date()'
          self.entity.attribute_by_name(:DeletedAt).graphql.initial_value = 'null'
          self.entity.attribute_by_name(:CreatedAt).graphql.updateable = false
          self.entity.attribute_by_name(:DeletedAt).graphql.updateable = false
        end
        if self.entity.imit?
          attributes = self.entity.attributes.select {|a| %w(CreatedAt DeletedAt).include?(a.name.to_s) && a.imit?}.collect {|a| a.name.to_s}
          if attributes.size > 0
            defaults = {}
            defaults[:CreatedAt] = 'org.realityforge.guiceyloops.shared.ValueUtil.now()' if attributes.include?('CreatedAt')
            defaults[:DeletedAt] = 'null' if attributes.include?('DeletedAt')
            self.entity.imit.test_create_default(defaults)
          end
        end
      end
    end
  end
end
