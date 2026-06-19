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

require 'erb'

require_relative 'core'

require_relative 'generators/render_context'
require_relative 'generators/target_manager'
require_relative 'generators/template'
require_relative 'generators/ruby_template'
require_relative 'generators/erb_template'
require_relative 'generators/template_set'
require_relative 'generators/template_set_container'
require_relative 'generators/generator'
require_relative 'generators/standard_template_set'
require_relative 'generators/standard_artifact_dsl'
require_relative 'generators/rake_integration'
require_relative 'generators/runner'

require_relative 'generators/buildr_integration'
