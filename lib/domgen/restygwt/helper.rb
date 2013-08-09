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
  module RestGWT
    module Helper
      def restygwt_return_type(method)
        s = ''
        if supports_nullable?(method.return_value.restygwt)
          s << nullability_annotation(method.return_value.nullable?)
        end
        s << ' '

        if method.return_value.struct?
          jso_type = method.return_value.referenced_struct.gwt.qualified_jso_name
          if method.return_value.collection?
            s << "org.fusesource.restygwt.client.OverlayCallback<com.google.gwt.core.client.JsArray<#{jso_type}>>"
          else
            s << "org.fusesource.restygwt.client.OverlayCallback<#{jso_type}>"
          end
        elsif method.return_value.collection?
          type = method.return_value.gwt.java_component_type(:boundary)
          s << "org.fusesource.restygwt.client.OverlayCallback<com.google.gwt.core.client.JsArray<#{type}>>"
        elsif method.return_value.return_type.to_s == 'void'
          s << "org.fusesource.restygwt.client.MethodCallback<Void>"
        else
          type = method.return_value.gwt.java_type(:boundary)
          s << "org.fusesource.restygwt.client.MethodCallback<#{type}>"
        end
        s << ' '
        s << 'result'
        s
      end
    end
  end
end
