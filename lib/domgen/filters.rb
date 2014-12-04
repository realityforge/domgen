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
  class Filters
    def self.include_data_modules(data_module_names)
      data_module_names = data_module_names.is_a?(Array) ? data_module_names : [data_module_names]
      Proc.new { |artifact_type, artifact| is_in_data_modules?(data_module_names, artifact_type, artifact) }
    end

    def self.include_data_module(data_module_name)
      Proc.new { |artifact_type, artifact| is_in_data_module?(data_module_name, artifact_type, artifact) }
    end

    private

    def self.is_in_data_modules?(data_module_names, artifact_type, artifact)
      data_module_names.any? { |data_module_name| is_in_data_module?(data_module_name, artifact_type, artifact) }
    end

    def self.is_in_data_module?(data_module_name, artifact_type, artifact)
      (artifact_type == :repository) ||
        (artifact_type == :data_module && artifact.name == data_module_name) ||
        (artifact_type == :dao && artifact.data_module.name == data_module_name) ||
        (artifact_type == :entity && artifact.data_module.name == data_module_name) ||
        (artifact_type == :enumeration && artifact.data_module.name == data_module_name) ||
        (artifact_type == :method && artifact.service.data_module.name == data_module_name) ||
        (artifact_type == :exception && artifact.data_module.name == data_module_name) ||
        (artifact_type == :message && artifact.data_module.name == data_module_name) ||
        (artifact_type == :service && artifact.data_module.name == data_module_name) ||
        (artifact_type == :struct && artifact.data_module.name == data_module_name)
    end
  end
end
