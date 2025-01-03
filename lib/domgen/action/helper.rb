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
require 'json'
require 'digest/md5'

module Domgen
  module Action
    module Helper
      def hashCode(method)
        methodCode = "#{method.data_module.name}.#{method.service.name}.#{method.name}"
        requestSchema = requestSchema(method)
        responseSchema = responseSchema(method)
        content = "#{methodCode}:#{requestSchema}:#{responseSchema}"
        Digest::MD5.hexdigest(content)
      end

      def requestSchema( method )
        schema = {
          type: 'object',
          properties: {
          },
          definitions: {
          }
        }
        method.parameters.each do |parameter|
          schema[:properties][parameter.name] = describeParameter(schema, parameter)
        end
        schema[:required] = method.parameters.map{|p| p.name}
        schema[:additionalProperties] = false
        schema.to_json
      end

      def responseSchema( method )
        schema = {
          oneOf: [
          ],
          definitions: {
          }
        }

        if method.return_value.return_type != :void
          if method.return_value.struct? && !method.return_value.collection?
            describeStruct(schema, method.return_value.referenced_struct)
            schema[:oneOf] <<
              {
                type: "object",
                properties: {
                  data: referenceStruct( method.return_value.referenced_struct )
                },
                required: ["data"],
                additionalProperties: false
              }
          else
            schema[:oneOf] <<
              {
                type: "object",
                properties: {
                  data: describeParameter( schema, method.return_value, true )
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
                exception: describeException(schema, exception)
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

      private
      def describeException(schema, exception)
        exceptionSchema =
          {
            type: "object",
            properties: {
              "$type": {
                type: "string",
                const: "#{exception.data_module.name}.#{exception.name}"
              },
              "$message": {
                type: "string"
              }
            },
            required: ["$type", "$message"],
          }

        exception.parameters.each do |parameter|
          exceptionSchema[:properties][parameter.name] = describeParameter(schema, parameter)
        end
        exceptionSchema[:required].push(*exception.parameters.map{|p| p.name})
        exceptionSchema
      end

      def describeParameter(schema, parameter, ignore_null = false)
        type =
          case
            when parameter.enumeration? then "integer"
            when parameter.date? then "string"
            when parameter.datetime? then "integer"
            when parameter.integer? then "integer"
            when parameter.reference? then "integer"
            when parameter.boolean? then "boolean"
            when parameter.struct? then
              describeStruct(schema, parameter.referenced_struct)
              referenceStruct(parameter.referenced_struct)
            else "string"
          end

        if parameter.collection?
          unless parameter.struct?
            type = {
              "type": type
            }
          end
          type = {
            type: "array",
            items: type
          }
          if parameter.nullable? && !ignore_null
            type = [type, "null"]
          end
        else
          if parameter.nullable? && !ignore_null
            type = { type: [type, "null"] }
          else
            unless parameter.struct?
             type = { type: type }
            end
          end
        end
        type
      end

      def referenceStruct(struct)
        {
          "$ref": "#/definitions/#{struct.name}"
        }
      end

      def describeStruct(schema, struct)
        return if schema[:definitions][struct.name]

        structSchema = {
          type: "object",
          properties: {
          }
        }
        schema[:definitions][struct.name] = structSchema

        struct.fields.each do |parameter|
          structSchema[:properties][parameter.name] = describeParameter(schema, parameter)
        end
        structSchema[:required] = struct.fields.map{|p| p.name}
        structSchema[:additionalProperties] = false
      end
    end
  end
end
