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

module Domgen #nodoc
  module Facets #nodoc

    class << self
      # Copy the targets from the specified generator container to the facet container.
      # This is typically used when projects include both reality-generators and reality-facets
      # and do not want to duplicate the code tor defining targets in both systems
      def copy_targets_to_generator_target_manager(template_set_container, facet_container)
        facet_container.target_manager.targets.each do |target|
          template_set_container.target_manager.target(target.key, target.container_key, :access_method => target.access_method)
        end
      end
    end
  end
end
