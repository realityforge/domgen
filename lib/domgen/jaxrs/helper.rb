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
      def jaxrs_paramater(parameter)
        s = ''
        s << "@javax.ws.rs.CookieParam( \"#{parameter.jaxrs.param_key}\" )" if parameter.jaxrs.param_type == :cookie
        s << "@javax.ws.rs.QueryParam( \"#{parameter.jaxrs.param_key}\" )" if parameter.jaxrs.param_type == :query
        s << "@javax.ws.rs.PathParam( \"#{parameter.jaxrs.param_key}\" )" if parameter.jaxrs.param_type == :path
        s << "@javax.ws.rs.FormParam( \"#{parameter.jaxrs.param_key}\" )" if parameter.jaxrs.param_type == :form
        s << "@javax.ws.rs.HeaderParam( \"#{parameter.jaxrs.param_key}\" )" if parameter.jaxrs.param_type == :header
        s << " "
        s << "@javax.ws.rs.DefaultValue( \"#{parameter.jaxrs.default_value}\" ) " if parameter.jaxrs.default_value
        s << "#{annotated_type(parameter, :jaxrs, :boundary)} #{Domgen::Naming.camelize(parameter.name)}"
        s
      end
    end
  end
end
