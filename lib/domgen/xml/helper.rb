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
  module Xml
    module Helper
      def to_tag_name(name)
        name.to_s.gsub(/_/, '-').gsub(/\?/, '')
      end

      def tag_each(target, name)
        values = target.send(name)
        unless values.nil? || values.empty?
          doc.tag!(to_tag_name(name)) do
            values.each do |item|
              yield item
            end
          end
        end
      end

      def collect_attributes(target, names)
        attributes = Hash.new
        names.each do |name|
          value = target.send(name.to_sym)
          if value
            attributes[to_tag_name(name)] = value
          end
        end
        attributes
      end
    end
  end
end

module Builder
  class XmlMarkup
    def _nested_structures(block)
      super(block)
      # if there was no newline after the last item, indentation
      # will be added anyway, which looks pretty wacky
      unless target! =~ /\n$/
        _newline
      end
    end
  end
end