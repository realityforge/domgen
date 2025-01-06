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

require 'domgen'

module Domgen
  FacetManager.facet(:action) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication
    end

    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage

      def pre_complete
        self.data_module.entities.each do |e|
          e.disable_facet(:action) if e.action?
        end
      end
    end

    facet.enhance(EnumerationSet) do
      def referenced?
        @referenced.nil? ? false : !!@referenced
      end

      def mark_as_referenced!
        @referenced = true
      end

      def pre_complete
        self.enumeration.disable_facet(:action) unless self.referenced?
      end
    end

    facet.enhance(Struct) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :json_encoder, :service, :server, :action, '#{struct.name}JsonEncoder'

      def referenced?
        @referenced.nil? ? false : !!@referenced
      end

      def mark_as_referenced!
        return if referenced?
        @referenced = true
        self.struct.fields.select{|f|f.enumeration? && f.enumeration.action?}.each do |field|
          field.enumeration.action.mark_as_referenced!
        end
        self.struct.fields.select{|f|f.struct? && f.referenced_struct.action?}.each do |field|
          field.referenced_struct.action.mark_as_referenced!
        end
      end

      def pre_complete
        self.struct.disable_facet(:action) unless self.referenced?
      end
    end

    facet.enhance(Exception) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :json_encoder, :service, :server, :action, '#{exception.name}JsonEncoder'

      def referenced?
        @referenced.nil? ? false : !!@referenced
      end

      def mark_as_referenced!
        return if referenced?
        @referenced = true
        self.exception.parameters.select{|f|f.enumeration? && f.enumeration.action?}.each do |field|
          field.enumeration.action.mark_as_referenced!
        end
        self.exception.parameters.select{|f|f.struct? && f.referenced_struct.action?}.each do |field|
          field.referenced_struct.action.mark_as_referenced!
        end
      end

      def pre_complete
        self.exception.disable_facet(:action) unless self.referenced?
      end
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      def pre_complete
        service.disable_facet(:action) unless service.methods.any?{|m| m.action?}
      end

      def post_verify
        if service.action? && (!service.ejb? || !service.ejb.generate_boundary?)
          Domgen::error("Service #{service.qualified_name} has action facet enabled but has no associated ejb boundary so the interceptor can not be applied")
        end
      end
    end

    facet.enhance(Method) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :interceptor_impl, :service, :server, :action, '#{method.name}ActionInterceptor'
      java_artifact :action_impl, :service, :server, :action, '#{method.name}Action'

      attr_writer :max_error_count

      def max_error_count
        @max_error_count.nil? ? 1 : @max_error_count
      end

      attr_writer :retry_rate

      def retry_rate
        @retry_rate.nil? ? 0 : @retry_rate
      end

      attr_writer :store_response_on_success

      def store_response_on_success?
        @store_response_on_success.nil? ? true : @store_response_on_success
      end

      attr_writer :generate_message_on_success

      def generate_message_on_success?
        @generate_message_on_success.nil? ? true : @generate_message_on_success
      end

      attr_writer :retain_failed_message_duration

      def retain_failed_message_duration
        @retain_failed_message_duration.nil? ? 1 : @retain_failed_message_duration
      end

      attr_writer :store_error_message_on_failure

      def store_error_message_on_failure?
        @store_error_message_on_failure.nil? ? true : @store_error_message_on_failure
      end

      attr_writer :persist_on_success

      def persist_on_success?
        @persist_on_success.nil? ? true : @persist_on_success
      end

      attr_writer :persist_duration

      def persist_duration
        @persist_duration.nil? ? nil : @persist_duration
      end

      attr_writer :clear_error_on_success

      def clear_error_on_success?
        @clear_error_on_success.nil? ? true : @clear_error_on_success
      end

      def pre_pre_complete
        unless self.method.ejb? && self.method.gwt_rpc?
          self.method.disable_facet(:action)
          return
        end

        self.method.parameters.select{|p|p.enumeration? && p.enumeration.action?}.each do |parameter|
          parameter.enumeration.action.mark_as_referenced!
        end
        self.method.parameters.select{|p|p.struct? && p.referenced_struct.action?}.each do |parameter|
          parameter.referenced_struct.action.mark_as_referenced!
        end
        self.method.exceptions.each do |exception|
          exception.action.mark_as_referenced!
        end
        if self.method.return_value.struct?
          self.method.return_value.referenced_struct.action.mark_as_referenced!
        end
      end

      def pre_complete
        if method.service.ejb? && method.service.ejb.generate_boundary?
          # method.ejb.boundary_interceptors << method.action.qualified_interceptor_impl_name
        end
      end
    end
  end
end
