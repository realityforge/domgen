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
  module JAXB
    module Helper
      def namespace_annotation_parameter(element)
        return '' unless element.namespace
        ", namespace=\"#{element.namespace}\""
      end

      def jaxb_class_annotations(struct)
        s = ''
        s << "@javax.xml.bind.annotation.XmlAccessorType( javax.xml.bind.annotation.XmlAccessType.FIELD )\n"
        ns = namespace_annotation_parameter(struct.xml)
        s << "@javax.xml.bind.annotation.XmlRootElement( name = \"#{struct.xml.name}\"#{ns} )\n" if struct.top_level?
        s << "@javax.xml.bind.annotation.XmlType( name = \"#{struct.name}\", propOrder = {#{struct.fields.collect{|field| "\"#{Reality::Naming.camelize(field.name)}\""}.join(', ')}}#{ns} )\n"
        s
      end

      def jaxb_exception_annotations(exception)
        s = ''
        s << "@javax.xml.bind.annotation.XmlAccessorType( javax.xml.bind.annotation.XmlAccessType.FIELD )\n"
        ns = namespace_annotation_parameter(exception.xml)
        s << "@javax.xml.bind.annotation.XmlRootElement( name = \"#{exception.xml.name}\"#{ns} )\n"
        s << "@javax.xml.bind.annotation.XmlType( name = \"#{exception.name}\", propOrder = {#{exception.parameters.collect{|p| "\"#{p.name}\""}.join(', ')}}#{ns} )\n"
        s
      end

      def jaxb_field_annotation(field, wrap_collections = true)
        if field.collection?
          s = ''
          s << "@javax.xml.bind.annotation.XmlElementWrapper( name = \"#{field.xml.name}\", required = #{field.xml.required?}, nillable = false )\n" if wrap_collections
          s << "  @javax.xml.bind.annotation.XmlElement( name = \"#{field.xml.component_name}\" )\n"
          s
        else
          "@javax.xml.bind.annotation.Xml#{field.xml.element? ? 'Element' : 'Attribute' }( name = \"#{field.xml.name}\", required = #{field.xml.required?} )\n"
        end
      end
    end
  end
end
