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
  Reality::Logging.configure(Domgen, ::Logger::WARN)

  class BaseTaggableElement < Reality::BaseElement
    attr_writer :tags

    def tags
      @tags ||= {}
    end

    def description=(description)
      tags[:Description] = description
    end

    def description(value = nil)
      return tags[:Description] if value.nil?
      # Assume an old style "setter"
      tags[:Description] = value
    end

    def tag_as_html(key)
      value = tags[key]
      if value
        require 'maruku' unless defined?(::Maruku)
        ::Maruku.new(value).to_html
      else
        nil
      end
    end
  end

  def self.ParentedElement(parent_key, pre_config_code = '')
    type = Class.new(BaseTaggableElement)
    code = <<-RUBY
    attr_accessor :#{parent_key}

    def initialize(#{parent_key}, options = {}, &block)
      @#{parent_key} = #{parent_key}
      #{pre_config_code}
      super(options, &block)
    end

    def parent
      self.#{parent_key}
    end
    RUBY
    type.class_eval(code)
    type
  end
end
