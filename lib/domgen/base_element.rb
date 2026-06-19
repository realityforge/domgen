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

  # Base class used for elements configurable via options
  class BaseElement
    def initialize(options = {})
      self.options = options
      yield self if block_given?
    end

    def options=(options)
      options.each_pair do |k, v|
        keys = k.to_s.split('.')
        target = self
        keys[0, keys.length - 1].each do |target_accessor_key|
          target = target.send target_accessor_key.to_sym
        end
        begin
          target.send "#{keys.last}=", v
        rescue NoMethodError
          raise "Attempted to configure property \"#{keys.last}\" on #{self.class} but property does not exist."
        end
      end
    end
  end

  def self.base_element(options = {})
    type = Class.new(BaseElement)

    container_key = options[:container_key]
    pre_config_code = options[:pre_config_code]
    post_config_code = options[:post_config_code]
    has_name = !!options[:name]
    has_key = !!options[:key]

    code = ''

    parameters = []
    initializers = ''

    if container_key
      code += "attr_reader :#{container_key}\n"
      parameters << container_key
      initializers += <<-RUBY
        @#{container_key} = #{container_key}
        raise "Nil #{container_key} parameter passed to #{self.class} instance" if @#{container_key}.nil?
      RUBY
    end

    if has_key
      code += "attr_reader :key\n"
      parameters << 'key'
      initializers += <<-RUBY
        @key = key
        raise "Nil key parameter passed to #{self.class} instance" if @key.nil?
      RUBY
    end

    if has_name
      code += "attr_reader :name\n"
      parameters << 'name'
      initializers += <<-RUBY
        @name = name
        raise "Nil name parameter passed to #{self.class} instance" if @name.nil?
      RUBY
    end


    parameters = parameters.join(', ')
    parameters += ', ' if parameters.size > 0
    code += <<RUBY
    def initialize(#{parameters}options = {}, &block)
      #{initializers}
      #{pre_config_code}
      super(options, &block)
      #{post_config_code}
    end
RUBY
    type.class_eval(code)
    type
  end
end
