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
  module Action

    def self.parameter_json_schema(schema, parameter, ignore_null = false)
      type =
        case
        when parameter.enumeration? then 'integer'
        when parameter.date? then 'string'
        when parameter.datetime? then 'integer'
        when parameter.integer? then 'integer'
        when parameter.reference? then 'integer'
        when parameter.boolean? then 'boolean'
        when parameter.struct? then
          parameter.referenced_struct.action.json_schema(schema)
          parameter.referenced_struct.action.json_reference
        else 'string'
        end

      if parameter.collection?
        unless parameter.struct?
          type = {
            "type": type
          }
        end
        type = {
          type: 'array',
          items: type
        }
        if parameter.nullable? && !ignore_null
          type = [type, 'null']
        end
      else
        if parameter.nullable? && !ignore_null
          type = { type: [type, 'null'] }
        else
          unless parameter.struct?
            type = { type: type }
          end
        end
      end
      type
    end
  end
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
        self.struct.fields.select { |f| f.enumeration? && f.enumeration.action? }.each do |field|
          field.enumeration.action.mark_as_referenced!
        end
        self.struct.fields.select { |f| f.struct? && f.referenced_struct.action? }.each do |field|
          field.referenced_struct.action.mark_as_referenced!
        end
      end

      def json_schema(schema)
        return if schema[:definitions][struct.name]

        struct_schema = {
          type: "object",
          properties: {
          }
        }
        schema[:definitions][struct.name] = struct_schema

        struct.fields.each do |parameter|
          struct_schema[:properties][parameter.name] = Domgen::Action.parameter_json_schema(schema, parameter)
        end
        struct_schema[:required] = struct.fields.map { |p| p.name }
        struct_schema[:additionalProperties] = false
      end

      def json_reference
        {
          "$ref": "#/definitions/#{struct.name}"
        }
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
        self.exception.parameters.select { |f| f.enumeration? && f.enumeration.action? }.each do |field|
          field.enumeration.action.mark_as_referenced!
        end
        self.exception.parameters.select { |f| f.struct? && f.referenced_struct.action? }.each do |field|
          field.referenced_struct.action.mark_as_referenced!
        end
      end

      def pre_complete
        self.exception.disable_facet(:action) unless self.referenced?
      end
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :register_actions, :service, :server, :action, '#{service.name}RegisterActions'

      def pre_complete
        service.disable_facet(:action) unless service.methods.any? { |m| m.action? }
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

      def code
        content = "#{method.qualified_name.gsub('#', '.')}:#{method.action.json_request_schema}:#{method.action.json_response_schema}"
        Digest::MD5.hexdigest(content)
      end

      attr_accessor :application_event

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

      def json_request_schema
        schema = {
          type: 'object',
          properties: {
          },
          definitions: {
          }
        }
        method.parameters.each do |parameter|
          schema[:properties][parameter.name] = Domgen::Action.parameter_json_schema(schema, parameter)
        end
        schema[:required] = method.parameters.map { |p| p.name }
        schema[:additionalProperties] = false
        schema.to_json
      end

      def pre_pre_complete
        unless self.method.ejb? && self.method.gwt_rpc?
          self.method.disable_facet(:action)
          return
        end

        self.method.parameters.select { |p| p.enumeration? && p.enumeration.action? }.each do |parameter|
          parameter.enumeration.action.mark_as_referenced!
        end
        self.method.parameters.select { |p| p.struct? && p.referenced_struct.action? }.each do |parameter|
          parameter.referenced_struct.action.mark_as_referenced!
        end
        self.method.exceptions.each do |exception|
          exception.action.mark_as_referenced!
        end
        if self.method.return_value.struct?
          self.method.return_value.referenced_struct.action.mark_as_referenced!
        end
      end

      def json_response_schema
        schema = {
          oneOf: [
          ],
          definitions: {
          }
        }

        if method.return_value.return_type != :void
          if method.return_value.struct? && !method.return_value.collection?
            method.return_value.referenced_struct.action.json_schema(schema)
            schema[:oneOf] <<
              {
                type: "object",
                properties: {
                  data: method.return_value.referenced_struct.action.json_reference
                },
                required: ["data"],
                additionalProperties: false
              }
          else
            schema[:oneOf] <<
              {
                type: "object",
                properties: {
                  data: Domgen::Action.parameter_json_schema(schema, method.return_value, true)
                },
                required: ["data"],
                additionalProperties: false
              }
          end
        end

        if method.return_value.nullable?
          schema[:oneOf] << {
            type: "object",
            properties: {
              data: {
                type: "null"
              }
            },
            required: ["data"],
            additionalProperties: false
          }
        end

        method.exceptions.each do |exception|
          schema[:oneOf] <<
            {
              type: "object",
              properties: {
                exception: exception_json_schema(schema, exception)
              },
              required: ["exception"],
              additionalProperties: false
            }
        end
        if method.return_value.return_type == :void
          schema[:oneOf] << {}
        end
        schema.to_json
      end

      def pre_complete
        if method.service.ejb? && method.service.ejb.generate_boundary?
          # method.ejb.boundary_interceptors << method.action.qualified_interceptor_impl_name
        end
      end

      private

      def exception_json_schema(schema, exception)
        exception_schema =
          {
            type: 'object',
            properties: {
              '$type': {
                type: 'string',
                const: "#{exception.data_module.name}.#{exception.name}"
              },
              '$message': {
                type: 'string'
              }
            },
            required: ['$type', '$message'],
          }

        exception.parameters.each do |parameter|
          exception_schema[:properties][parameter.name] = Domgen::Action.parameter_json_schema(schema, parameter)
        end
        exception_schema[:required].push(*exception.parameters.map { |p| p.name })
        exception_schema
      end
    end
  end
end
