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
        when parameter.enumeration? && parameter.enumeration.textual_values? then 'string'
        when parameter.enumeration? && parameter.enumeration.numeric_values? then 'integer'
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

      def pre_pre_complete
        if self.repository.imit?
          self.repository.imit.graphs.select{|graph|!graph.filter_parameter.nil?}.each do |graph|
            if graph.filter_parameter.enumeration? && graph.filter_parameter.enumeration.action?
              graph.filter_parameter.enumeration.action.mark_as_referenced!
            elsif graph.filter_parameter.struct? && graph.filter_parameter.referenced_struct.action?
              graph.filter_parameter.referenced_struct.action.mark_as_referenced!
            end
          end
        end
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage
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

      java_artifact :json_encoder, :service, :server, :action, '#{exception.name}ExceptionJsonEncoder'

      def referenced?
        @referenced.nil? ? false : !!@referenced
      end

      def public_encoder?
        return true unless exception.ee.module_local?
        return false unless exception.extends
        exception.data_module.exception_by_name(exception.extends).action.public_encoder?
      end

      def json_encoder_qualified_name
        "#{exception.data_module.ee.server_service_package}.#{json_encoder_name}"
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
        unless self.exception.extends.nil?
          exception.data_module.exception_by_name(exception.extends).action.mark_as_referenced!
        end
        self.exception.direct_subtypes.each do |e|
          e.action.mark_as_referenced! if e.action?
        end
      end

      def pre_complete
        self.exception.disable_facet(:action) unless self.referenced?
      end
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :service_actions, :service, :server, :action, '#{service.name}Actions'

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

      java_artifact :method_actions, :service, :server, :action, '#{method.service.name}#{method.name}Action'

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

      attr_writer :generate_serverside_action

      def generate_serverside_action?
        @generate_serverside_action.nil? ? false : @generate_serverside_action
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
        schema[:required] = method.parameters.reject{ |p| p.nullable? }.map { |p| p.name }
        schema[:additionalProperties] = false
        schema.to_json
      end

      def pre_pre_complete
        unless self.method.ejb?
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
          exception.direct_subtypes.each do |subtype_exception|
            schema[:oneOf] <<
              {
                type: "object",
                properties: {
                  exception: exception_json_schema(schema, subtype_exception)
                },
                required: ["exception"],
                additionalProperties: false
              }
          end
        end
        if method.return_value.return_type == :void
          schema[:oneOf] << {"type": "object", "maxProperties": 0}
        end
        if 1 == schema[:oneOf].size && schema[:definitions].empty?
          return schema[:oneOf][0].to_json
        else
          schema.to_json
        end
      end

      def post_complete
        if method.service.ejb? && method.service.ejb.generate_boundary?
          self.method.ejb.boundary_annotations << "#{self.method.service.action.qualified_service_actions_name}.#{self.method.name}ActionInterceptor.ActionInterceptorBinding"
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
            },
            required: ['$type'],
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
