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
  module JaxRS
    module Helper
      def jaxrs_expanded_media_type(media_type)
        if :json == media_type
          'javax.ws.rs.core.MediaType.APPLICATION_JSON'
        elsif :xml == media_type
          'javax.ws.rs.core.MediaType.APPLICATION_XML'
        elsif :plain == media_type
          'javax.ws.rs.core.MediaType.TEXT_PLAIN'
        else
          Domgen.error("Unknown media type #{media_type}")
        end
      end

      def jaxrs_produces(element, prefix = '')
        return '' if element.produces.nil? || element.produces.empty?
        "#{prefix}@javax.ws.rs.Produces( {#{element.produces.collect { |p| jaxrs_expanded_media_type(p) }.join(', ')}} )\n"
      end

      def jaxrs_consumes(element, prefix = '')
        return '' if element.consumes.nil? || element.consumes.empty?
        "#{prefix}@javax.ws.rs.Consumes( {#{element.consumes.collect { |p| jaxrs_expanded_media_type(p) }.join(', ')}} )\n"
      end

      def jaxrs_path(element, prefix = '')
        return '' if element.path.nil? || '' == element.path
        "#{prefix}@javax.ws.rs.Path(\"#{element.path}\")\n"
      end

      def jaxrs_paramater(parameter)
        s = ''
        s << "@javax.ws.rs.CookieParam( \"#{parameter.jaxrs.param_key}\" )" if parameter.jaxrs.param_type == :cookie
        s << "@javax.ws.rs.QueryParam( \"#{parameter.jaxrs.param_key}\" )" if parameter.jaxrs.param_type == :query
        s << "@javax.ws.rs.PathParam( \"#{parameter.jaxrs.param_key}\" )" if parameter.jaxrs.param_type == :path
        s << "@javax.ws.rs.FormParam( \"#{parameter.jaxrs.param_key}\" )" if parameter.jaxrs.param_type == :form
        s << "@javax.ws.rs.HeaderParam( \"#{parameter.jaxrs.param_key}\" )" if parameter.jaxrs.param_type == :header
        s << ' '
        s << "@javax.ws.rs.DefaultValue( \"#{parameter.jaxrs.default_value}\" ) " if parameter.jaxrs.default_value
        s << "#{annotated_type(parameter, :jaxrs, :boundary, :final => true)} #{Reality::Naming.camelize(parameter.name)}"
        s
      end
    end
  end
end
