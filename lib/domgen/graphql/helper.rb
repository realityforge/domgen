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
  module Graphql
    module Helper
      def has_description?(input)
        input.graphql.description.to_s.strip != ''
      end

      def description_to_string(input)
        j_escape_string(input.graphql.description.to_s.strip).gsub("\n", "\\n\" + \"")
      end
    end
  end
end
