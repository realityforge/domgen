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
  module Generator
    class RenderContext
      def initialize
        @helpers = []
        @variables = {}
      end

      def add_helper(module_type)
        @helpers << module_type
      end

      def set_local_variable(key, value)
        @variables[key] = value
      end

      def context_binding
        clazz = Class.new
        @helpers.each do |helper|
          clazz.send :include, helper
        end
        context = clazz.new
        @variables.each_pair do |k, v|
          context.instance_eval "def #{k}; @#{k}; end"
          context.instance_variable_set "@#{k}".to_sym, v
        end
        context.instance_eval do
          return binding
        end
      end
    end
  end
end
