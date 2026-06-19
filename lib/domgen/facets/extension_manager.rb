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
    class ExtensionManager
      def initialize
        @locked = false
      end

      # An array of modules that should be mixed in to every extension object
      def instance_extensions
        instance_extension_list.dup
      end

      # Add a ruby module that will be applied to all extension objects
      def instance_extension(extension)
        Domgen.error("Attempting to define instance extension #{extension} after extension manager is locked") if locked?
        instance_extension_list << extension
      end

      # An array of modules that should be mixed in to the singleton class of extension objects
      def singleton_extensions
        singleton_extension_list.dup
      end

      def singleton_extension(extension)
        Domgen.error("Attempting to define singleton extension #{extension} after extension manager is locked") if locked?
        singleton_extension_list << extension
      end

      def lock!
        @locked = true
      end

      def locked?
        !!(@locked ||= nil)
      end

      private

      def singleton_extension_list
        @singleton_extensions ||= []
      end

      def instance_extension_list
        @instance_extensions ||= []
      end
    end
  end
end
