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
  module XML

    def self.include_xml(type, parent_key)
      type.class_eval(<<-RUBY)
      attr_writer :name

      def name
        @name || Domgen::Naming.xmlize(#{parent_key}.name)
      end

      attr_accessor :namespace
      RUBY
    end

    def self.include_data_element_xml(type, parent_key)
      type.class_eval(<<-RUBY)
      Domgen::XML.include_xml(self, :#{parent_key})

      def component_name
        Domgen::Naming.xmlize(#{parent_key}.component_name)
      end

      attr_writer :required

      def required?
        @required.nil? ? !#{parent_key}.nullable? : @required
      end

      attr_writer :element

      # default to false for non-collection attributes and true for collection attributes
      def element?
        @element.nil? ? #{parent_key}.collection? || #{parent_key}.struct? : @element
      end
      RUBY
    end

    class XmlStructField < Domgen.ParentedElement(:field)
      Domgen::XML.include_data_element_xml(self, :field)
    end

    class XmlStruct < Domgen.ParentedElement(:struct)
      Domgen::XML.include_xml(self, :struct)

      # Override name to strip out DTO/VO suffix
      def name
        return @name if @name
        candidate = Domgen::Naming.xmlize(struct.name)
        return candidate[0, candidate.size-4] if candidate =~ /-dto$/
        return candidate[0, candidate.size-3] if candidate =~ /-vo$/
        candidate
      end
    end

    class XmlEnumeration < Domgen.ParentedElement(:enumeration)
      Domgen::XML.include_xml(self, :enumeration)
    end

    class XmlParameter < Domgen.ParentedElement(:parameter)
      Domgen::XML.include_data_element_xml(self, :parameter)
    end
  end

  FacetManager.define_facet(:xml,
                            Struct => Domgen::XML::XmlStruct,
                            StructField => Domgen::XML::XmlStructField,
                            Parameter => Domgen::XML::XmlParameter,
                            EnumerationSet => Domgen::XML::XmlEnumeration)
end
