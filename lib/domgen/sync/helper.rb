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
  module Sync
    module SyncTestHelper
      def sync_generate_attribute_value(attribute)
        if attribute.primary_key?
          return nil
        elsif attribute.name == :MasterSynchronized
          return 'false'
        elsif attribute.name == :MappingId || attribute.name == :MappingKey
          return 'mappingId'
        elsif attribute.name == :DeletedAt
          return 'deletedAt'
        elsif attribute.reference?
          if attribute.referenced_entity.data_module.name == attribute.entity.data_module.name
            return Reality::Naming.camelize(attribute.name)
          else
            return 'null'
          end
        elsif attribute.nullable?
            return 'null'
        elsif attribute.integer?
          return 'org.realityforge.guiceyloops.shared.ValueUtil.randomInt()'
        elsif attribute.long?
          return 'org.realityforge.guiceyloops.shared.ValueUtil.randomLong()'
        elsif attribute.text?
          if attribute.has_non_max_length?
            return "org.realityforge.guiceyloops.shared.ValueUtil.randomString(#{attribute.entity.name}.#{Reality::Naming.uppercase_constantize(attribute.name)}_MAX_SIZE)"
          else
            return 'org.realityforge.guiceyloops.shared.ValueUtil.randomString()'
          end
        elsif attribute.boolean?
          return 'org.realityforge.guiceyloops.shared.ValueUtil.randomBoolean()'
        elsif attribute.date? || attribute.datetime?
          return 'org.realityforge.guiceyloops.shared.ValueUtil.now()'
        elsif attribute.enumeration?
          return "#{attribute.enumeration.ee.qualified_name}.values()[ java.lang.Math.abs( org.realityforge.guiceyloops.shared.ValueUtil.randomInt() ) % #{attribute.enumeration.values.size}]"
        elsif attribute.real?
          return 'org.realityforge.guiceyloops.shared.ValueUtil.randomFloat()'
        else
          return 'UnhandledType'
        end
      end
    end
  end
end
