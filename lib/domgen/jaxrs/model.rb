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
    module MediaTypeEnabled
      def consumes
        @consumes || [:json, :xml]
      end

      def consumes=(consumes)
        consumes = [consumes] unless consumes.is_a?(Array)
        consumes.each do |media_type|
          Domgen.error("Specified media type '#{media_type}' is not valid") unless valid_media_type?(media_type)
        end
        @consumes = consumes
      end

      def produces
        @produces || [:json, :xml]
      end

      def produces=(produces)
        produces = [produces] unless produces.is_a?(Array)
        produces.each do |media_type|
          Domgen.error("Specified media type '#{media_type}' is not valid") unless valid_media_type?(media_type)
        end
        @produces = produces
      end

      def valid_media_type?(media_type)
        [:json, :xml, :plain].include?(media_type)
      end
    end
  end

  FacetManager.facet(:jaxrs => [:ee]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :path

      def path
        @path || 'api'
      end

      attr_writer :custom_application

      def custom_application?
        @custom_application.nil? ? false : !!@custom_application
      end

      java_artifact :constants, :rest, :server, :ee, '#{repository.name}JaxRsConstants'
      java_artifact :abstract_application, :rest, :server, :ee, 'Abstract#{repository.name}JaxRsApplication'
      java_artifact :standard_application, :rest, :server, :ee, '#{repository.name}JaxRsApplication'

      def extensions
        @extensions ||= []
      end
    end

    facet.enhance(Service) do
      include Domgen::JaxRS::MediaTypeEnabled
      include Domgen::Java::BaseJavaGenerator

      def short_service_name
        service.name.to_s =~ /^(.*)Service/ ? service.name.to_s[0..-8] : service.name
      end

      java_artifact :service, :rest, :server, :ee, '#{short_service_name}RestService'
      java_artifact :boundary, :rest, :server, :ee, '#{service_name}Impl', :sub_package => 'internal'

      attr_accessor :boundary_extends

      attr_writer :path

      def path
        return @path unless @path.nil?
        return "/#{Reality::Naming.underscore(short_service_name)}"
      end
    end

    facet.enhance(Exception) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :exception_mapper, :rest, :server, :ee, '#{exception.name}ExceptionMapper'

      attr_writer :internal_code

      def internal_code
        @internal_code || "#{exception.data_module.name}.#{exception.name}"
      end

      attr_writer :http_code

      def http_code
        @http_code || exception.java.normal? ? 400 : 500
      end
    end

    facet.enhance(ExceptionParameter) do
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    facet.enhance(Method) do
      include Domgen::JaxRS::MediaTypeEnabled

      attr_writer :path

      def path
        if @path
          return @path == '' ? nil : @path
        end
        base_path = "/#{Reality::Naming.underscore(method.name)}"
        path_parameters = method.parameters.select { |p| p.jaxrs? && :path == p.jaxrs.param_type }
        return base_path if path_parameters.empty?
        return "#{base_path}/{#{path_parameters.collect { |p| p.jaxrs.param_key }.join('/')}}"
      end

      def http_method=(http_method)
        Domgen.error("Specified http method '#{http_method}' is not valid") unless valid_http_method?(http_method)
        @http_method = http_method
      end

      def http_method
        return @http_method if @http_method
        name = method.name.to_s
        if name =~ /^Get[A-Z].*/ || name =~ /^Find[A-Z].*/
          return 'GET'
        elsif name =~ /^Delete[A-Z].*/ || name =~ /^Remove[A-Z].*/
          return 'DELETE'
        else
          return 'POST'
        end
      end

      def valid_http_method?(http_method)
        %w(GET DELETE PUT POST HEAD OPTIONS).include?(http_method)
      end
    end

    facet.enhance(Parameter) do
      include Domgen::Java::EEJavaCharacteristic

      attr_writer :param_key

      def param_key
        @param_key || Reality::Naming.camelize(characteristic.name)
      end

      attr_accessor :default_value

      def param_type
        @param_type || :query
      end

      def param_type=(param_type)
        Domgen.error("Unknown param_type #{param_type}") unless valid_param_type?(param_type)
        @param_type = param_type
      end

      protected

      def valid_param_type?(param_type)
        [:query, :cookie, :path, :form, :header].include?(param_type)
      end

      def characteristic
        parameter
      end
    end

    facet.enhance(Result) do
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        result
      end
    end
  end
end
