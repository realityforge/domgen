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
  module Options
    class << self
      # Set the levels on an array of loggers.
      # The levels parameter must be an array matching the number of loggers supplied or a single level.
      # If a block is supplied then the levels are set to the specified values for the duration of the
      # block and then reset to original values after the block completes.
      def check(options, valid_options, logging_container = nil, method_descriptor = nil)
        bad_options = options.keys.select { |k| !valid_options.include?(k) }
        return if bad_options.empty?

        single_error = bad_options.size == 1
        message = "Unknown option#{single_error ? '' : 's'} #{single_error ? "'#{bad_options.first.inspect}'" : bad_options.inspect} passed to #{method_descriptor || 'method'}"
        if logging_container
          logging_container.error(message)
        else
          raise ArgumentError.new(message)
        end
      end
    end
  end
end
