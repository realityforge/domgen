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

      def custom_resource_from_env(name, options = {})
        env_key = options[:env_key]
        restype = options[:restype]
        default_value = options[:default_value]
        components = name.split('/')
        components = [components.first] + components[2..components.size] if components.size > 2 && components[1] == 'env'
        env_key = components.join('_').upcase if env_key.nil?
        custom_resource(name, "${#{env_key}}", restype)
        environment_variable(env_key, 'UNSPECIFIED', default_value)
      end

      def environment_variable(key, value = 'UNSPECIFIED', default_value = '')
        system_property(key, value)
        self.data['environment_vars'][key] = default_value
      end

      def system_property(key, value)
        Domgen.error("Redfish system_property '#{key}' can not have nil or empty value") if value.to_s == ''
        self.data['system_properties'][key] = value
      end

      def volume_requirement(key)
        self.data['volumes'][key]
      end

      def pre_complete
        key = Reality::Naming.uppercase_constantize(repository.name)

        # We magically create environment variables for any of the required settings
        # if they are used in custom_resources
        self.data['environment_vars'].keys.each do |name|
          value = self.data['environment_vars'][name].to_s

          create_env_if_required("#{key}_PUBLIC_HOST_URL", value)
          create_env_if_required("#{key}_PUBLIC_URL", value)
          create_env_if_required("#{key}_INTERNAL_URL", value)
          create_env_if_required("#{key}_INTERNAL_HOST_URL", value)
        end
      end

      private

      def create_env_if_required(env_key, value)
        if value =~ /\$\{#{env_key}\}/ && !self.data['environment_vars'].include?(env_key)
          self.environment_variable(env_key)
        end
      end
    end
  end
end
