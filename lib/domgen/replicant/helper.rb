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
  module Replicant
    module Helper

      def query_getter(a)
        getter_for(a)
      end

      def derive_dataset_key(dataset_link, source_dataset_variable, entity_id_variable)
        attribute = dataset_link.replicant_attribute.attribute
        entity = attribute.entity
        data_module = entity.data_module
        repository = data_module.repository
        target_dataset = repository.replicant.dataset_by_name(dataset_link.target_dataset)
        Domgen.error("derive_dataset_key(#{attribute.qualified_name}, #{dataset_link}) invoked but target Dataset is not keyed") unless target_dataset.keyed?

        # S3 (requires source Dataset & source Dataset is a Type Dataset)
        # S3.4 (requires source Dataset & source Dataset is an Instance Dataset)
        # E56.222 (requires source entity)
        # S3.4E56.222 (requires source Dataset & requires source entity & source Dataset is an Instance Dataset)

        dataset_prefix = dataset_link.target_filter_parameter_requires_source_dataset_root_id? || dataset_link.target_filter_parameter_requires_source_filter_parameter? ? "\"S\" + #{source_dataset_variable}" : ''
        if dataset_link.target_filter_parameter_requires_source_entity?
          source_entity_suffix = "\"E\" + #{repository.replicant.qualified_entity_type_constants_name}.#{Domgen::Naming.uppercase_constantize(data_module.name)}_#{Domgen::Naming.uppercase_constantize(entity.name)} + \".\" + #{entity_id_variable}"
          '' == dataset_prefix ? source_entity_suffix : "#{dataset_prefix} + #{source_entity_suffix}"
        else
          dataset_prefix
        end
      end

      def target_dataset_address_expression(dataset_link, target_dataset_root_id_expression, target_filter_parameter_variable, target_filter_parameter_typed_variable = nil)
        target_dataset = dataset_link.replicant_attribute.attribute.entity.data_module.repository.replicant.dataset_by_name(dataset_link.target_dataset)
        dataset_id_expression = "#{dataset_link.replicant_attribute.attribute.entity.data_module.repository.replicant.qualified_subscription_constants_name}.#{Domgen::Naming.uppercase_constantize(dataset_link.target_dataset)}"
        if target_dataset.keyed? && dataset_link.target_dataset_key_derived_from_target_filter_parameter? && target_filter_parameter_typed_variable
          "replicant.server.DatasetAddress.of( #{dataset_id_expression}, #{target_dataset_root_id_expression}, deriveDatasetKeyForDatasetLinkFrom#{dataset_link.source_dataset}To#{dataset_link.target_dataset}( #{target_filter_parameter_typed_variable} ) )"
        elsif target_dataset.keyed? && dataset_link.target_dataset_key_derived_from_target_filter_parameter?
          "replicant.server.DatasetAddressTemplate.of( #{dataset_id_expression}, #{target_dataset_root_id_expression} )"
        else
          "replicant.server.DatasetAddress.of( #{dataset_id_expression}#{target_dataset.instance_dataset? || target_dataset.keyed? ? "#{target_dataset.instance_dataset? ? ", #{target_dataset_root_id_expression}" : ', null'}#{target_dataset.keyed? ? ", deriveDatasetKeyForDatasetLinkFrom#{dataset_link.source_dataset}To#{dataset_link.target_dataset}( #{dataset_link.target_filter_parameter_requires_source_dataset_root_id? || dataset_link.target_filter_parameter_requires_source_filter_parameter? ? 'sourceDatasetAddress' : ''}#{(dataset_link.target_filter_parameter_requires_source_dataset_root_id? || dataset_link.target_filter_parameter_requires_source_filter_parameter?) && dataset_link.target_filter_parameter_requires_source_entity? ? ', ': ''}#{dataset_link.target_filter_parameter_requires_source_entity? ? 'entityId' : ''} )" : ''}" : ''} )"
        end
      end

      def entity_target_dataset_address_expression(dataset_link, target_dataset_root_id_expression, source_expression, entity_expression, target_filter_parameter_typed_expression = nil)
        target_dataset = dataset_link.replicant_attribute.attribute.entity.data_module.repository.replicant.dataset_by_name(dataset_link.target_dataset)
        dataset_id_expression = "#{dataset_link.replicant_attribute.attribute.entity.data_module.repository.replicant.qualified_subscription_constants_name}.#{Domgen::Naming.uppercase_constantize(dataset_link.target_dataset)}"
        if target_dataset.keyed? && dataset_link.target_dataset_key_derived_from_target_filter_parameter? && target_filter_parameter_typed_expression
          "replicant.server.DatasetAddress.of( #{dataset_id_expression}, #{target_dataset_root_id_expression}, deriveDatasetKeyForDatasetLinkFrom#{dataset_link.source_dataset}To#{dataset_link.target_dataset}( #{target_filter_parameter_typed_expression} ) )"
        elsif target_dataset.keyed? && dataset_link.target_dataset_key_derived_from_target_filter_parameter?
          "replicant.server.DatasetAddressTemplate.of( #{dataset_id_expression}, #{target_dataset_root_id_expression} )"
        else
          "replicant.server.DatasetAddress.of( #{dataset_id_expression}, #{target_dataset_root_id_expression}#{target_dataset.keyed? ? ", deriveDatasetKeyForDatasetLinkFrom#{dataset_link.source_dataset}To#{dataset_link.target_dataset}( #{dataset_link.target_filter_parameter_requires_source_dataset_root_id? || dataset_link.target_filter_parameter_requires_source_filter_parameter? ? source_expression : ''}#{(dataset_link.target_filter_parameter_requires_source_dataset_root_id? || dataset_link.target_filter_parameter_requires_source_filter_parameter?) && dataset_link.target_filter_parameter_requires_source_entity? ? ', ': ''}#{dataset_link.target_filter_parameter_requires_source_entity? ? "#{entity_expression}.#{getter_for(dataset_link.replicant_attribute.attribute.entity.primary_key)}" : ''} )" : ''} )"
        end
      end

      def process_parameter(entity, parameter_name, javaql, prefix)
        if entity.attribute_by_name?(parameter_name)
          a = entity.attribute_by_name(parameter_name)
          value = Domgen::Naming.camelize(parameter_name)
          return "#{prefix} java.util.Objects.equals( e.#{query_getter(a)}, #{value} ) #{javaql}"
        else
          # Handle parameters that are the primary keys of related entities
          entity.attributes.select { |a| a.reference? && a.referencing_link_name == parameter_name }.each do |a|
            return "#{prefix} java.util.Objects.equals( e.get#{a.name}().#{getter_for(a.referenced_entity.primary_key)}, #{Domgen::Naming.camelize(parameter_name)} ) #{javaql}"
          end
          return nil
        end
      end

      def lambda_query(query)
        javaql = ''
        query_text = nil
        query_text = $1 if query.name =~ /^[fF]indAllBy(.+)$/
        query_text = $1 if query.name =~ /^[fF]indBy(.+)$/
        query_text = $1 if query.name =~ /^[gG]etBy(.+)$/
        query_text = $1 if query.name =~ /^[cC]ountBy(.+)$/
        raise "Unable to derive lambda based query for #{query.qualified_name}" unless query_text

        entity = query.dao.entity

        while true
          if query_text =~ /(.+)(And|Or)([A-Z].*)/
            parameter_name = $3
            operation = $2 == 'And' ? '&&' : '||'
            query_text = $1
            javaql = process_parameter(entity, parameter_name, javaql, operation)
            break if javaql.nil?
          else
            parameter_name = query_text
            javaql = process_parameter(entity, parameter_name, javaql, nil)
            break
          end
        end
        raise "Unable to derive query #{query.qualified_name}" unless javaql
        javaql
      end

      def query_component_result_type(query)
        query.result_entity? ?
          query.entity.replicant.qualified_name :
          query.result_struct? ?
            query.struct.gwt.qualified_name :
            Domgen::TypeDB.characteristic_type_by_name(query.result_type).java.object_type
      end
    end
  end
end
