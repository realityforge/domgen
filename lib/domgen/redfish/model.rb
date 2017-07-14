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
  FacetManager.facet(:redfish => [:application]) do |facet|
    facet.enhance(Repository) do
      def pre_init
        @data = Reality::Mash.new
      end

      attr_reader :data

      def custom_resource(name, value, restype = nil)
        self.data['custom_resources'][name]['properties']['value'] = value
        self.data['custom_resources'][name]['restype'] = restype if restype
      end

      def custom_resource_from_env(name, env_key = nil, restype = nil, default_value = nil)
        components = name.split('/')
        components = [components.first] + components[2..components.size] if components.size > 2 && components[1] == 'env'
        env_key = components.join('_').upcase if env_key.nil?
        custom_resource(name, "${#{env_key}}", restype)
        environment_variable(env_key, default_value)
      end

      def environment_variable(key, default_value = '')
        self.data['environment_vars'][key] = default_value
      end

      def system_property(key, value)
        self.data['system_properties'][key] = value
      end

      def volume_requirement(key)
        self.data['volumes'][key]
      end
    end
  end
end
