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
  module Mssql
    module Helper
      # Change tags named Description to MS_Description when making into an extended property as
      # that is the MS standard for documentation properties
      def sql_extended_property_key(name)
        (name.to_s == 'Description') ? 'MS_Description' : name
      end

      def sql_extended_property_value(data_module, value)
        data_module.sql.dialect.quote_string(value).strip
      end
    end
  end
end
