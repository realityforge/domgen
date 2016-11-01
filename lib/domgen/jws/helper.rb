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
  module Jws
    module Helper
      def jws_convert_parameter_value(p, input_value, output_value)
        v =
          if p.integer?
            "final java.math.BigInteger #{output_value} = java.math.BigInteger.valueOf( #{input_value}  );"
          elsif p.long? || p.boolean? || p.text?
            "final #{p.ee.java_type} #{output_value} = #{input_value};"
          elsif p.reference?
            jws_convert_parameter_value(p.referenced_entity.primary_key, "#{input_value}.#{getter_for(p.referenced_entity.primary_key)}", output_value)
          elsif p.enumeration?
            "final #{p.ee.java_type} #{output_value} = #{input_value}.name();"
          elsif p.struct?
            "convert( #{service.jws.api_package}.#{p.referenced_struct.name}.class, #{java_create_struct(p.referenced_struct, p.characteristic_container)} )"
          elsif p.datetime?
            <<-CONVERT
final java.util.GregorianCalendar $_$#{output_value} = new java.util.GregorianCalendar();
$_$#{output_value}.setTime( #{input_value} );
final javax.xml.datatype.XMLGregorianCalendar #{output_value} = javax.xml.datatype.DatatypeFactory.newInstance().newXMLGregorianCalendar( $_$#{output_value} );
            CONVERT
          elsif p.date?
            <<-CONVERT
final java.util.GregorianCalendar $_$#{output_value} = new java.util.GregorianCalendar();
$_$#{output_value}.setTime( #{input_value} );
$_$#{output_value}.set( java.util.Calendar.HOUR_OF_DAY, 0 );
$_$#{output_value}.set( java.util.Calendar.MINUTE, 0 );
$_$#{output_value}.set( java.util.Calendar.SECOND, 0 );
$_$#{output_value}.set( java.util.Calendar.MILLISECOND, 0 );
final javax.xml.datatype.XMLGregorianCalendar #{output_value} = javax.xml.datatype.DatatypeFactory.newInstance().newXMLGregorianCalendar( $_$#{output_value} );
            CONVERT
          else
            Domgen.error("Unknown parameter type for #{p.qualified_name}")
          end
      end

      def jws_wrap_characteristic(p, input_value, output_value)
        if p.collection?
          str = <<-STR
final java.util.ArrayList<#{p.ee.java_component_type}> #{output_value} = new java.util.ArrayList<#{p.ee.java_component_type}>();
{
  for( #{p.ee.java_component_type} c: #{input_value} )
  {
          STR
          str += "    #{jws_convert_parameter_value(p, 'c', '$c')}\n"
          str += "    #{output_value}.add( $c );\n"
          str += <<-STR
  }
}
          STR

        else
          jws_convert_parameter_value(p, input_value, output_value)
        end
      end
    end
  end
end
