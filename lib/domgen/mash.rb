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
  class Mash < Hash
    alias_method :h_read, :[]
    alias_method :h_write, :[]=

    def [](key)
      self.h_write(key, Mash.new) unless key?(key)
      self.h_read(key)
    end

    def to_h
      basic_types = [Integer, Float, TrueClass, FalseClass, NilClass]
      result = {}
      each_pair do |key, value|
        result[key] = value.is_a?(Mash) ? value.to_h : basic_types.include?(value.class) ? value : value.dup
      end
      result
    end

    def merge(other)
      result = Mash.new
      result.merge!(self)
      result.merge!(other)
      result
    end

    def merge!(other)
      other.each_pair do |k, v|
        if v.is_a?(Hash)
          self[k].merge!(v)
        elsif v.is_a?(Array)
          if self.key?(k) && self[k].is_a?(Array)
            self[k] = self[k].concat(v)
          else
            self[k] = v.dup
          end
        else
          self[k] = v
        end
      end
    end

    def sort
      result = Mash.new
      self.keys.sort.each do |key|
        value = self[key]
        result[key] = value.is_a?(Mash) ? value.sort : value
      end
      result
    end

    def self.from(hash)
      result = Mash.new
      hash.each_pair do |k, v|
        result[k] = v.is_a?(Hash) ? Mash.from(v) : v
      end
      result
    end
  end
end
