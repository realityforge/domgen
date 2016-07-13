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
  module Ejb
    class Schedule < Domgen.ParentedElement(:method)
      def initialize(method, options = {}, &block)
        @second = '0'
        @minute = '0'
        @hour = '0'
        @day_of_month = '*'
        @month = '*'
        @day_of_week = '*'
        @year = '*'
        @timezone = ''
        @persistent = false
        super(method, options, &block)
      end

      attr_accessor :second
      attr_accessor :minute
      attr_accessor :hour
      attr_accessor :day_of_month
      attr_accessor :month
      attr_accessor :day_of_week
      attr_accessor :year
      attr_accessor :timezone
      attr_writer :persistent

      def persistent?
        !!@persistent
      end

      attr_writer :info

      def info
        @info || method.qualified_name.gsub('#','.')
      end
    end
  end

  FacetManager.facet(:ejb => [:ee]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :complete_module, :test, :server, :ejb, '#{repository.name}Module', :sub_package => 'util'
      java_artifact :services_module, :test, :server, :ejb, '#{repository.name}ServicesModule', :sub_package => 'util'
      java_artifact :cdi_types_test, :test, :server, :ejb, '#{repository.name}CdiTypesTest', :sub_package => 'util'
      java_artifact :aggregate_service_test, :test, :server, :ejb, '#{repository.name}AggregateServiceTest', :sub_package => 'util'
      java_artifact :abstract_service_test, :test, :server, :ejb, 'Abstract#{repository.name}ServiceTest', :sub_package => 'util'
      java_artifact :server_test_module, :test, :server, :ejb, '#{repository.name}ServerModule', :sub_package => 'util'

      attr_writer :include_server_test_module

      def include_server_test_module?
        @include_server_test_module.nil? ? true : !!@include_server_test_module
      end

      def extra_test_modules
        @extra_test_modules ||= []
      end

      def qualified_base_service_test_name
        "#{server_util_test_package}.#{base_service_test_name}"
      end

      attr_writer :base_service_test_name

      def base_service_test_name
        @base_service_test_name || abstract_service_test_name.gsub(/^Abstract/,'')
      end

      def implementation_suffix
        repository.ee.use_cdi? ? 'Impl' : 'EJB'
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :name

      def name
        @name || service.qualified_name
      end

      def service_ejb_name
        "#{service.data_module.repository.name}.#{service.ejb.name}"
      end

      def boundary_name
        "#{name}Boundary"
      end

      def boundary_ejb_name
        "#{service.data_module.repository.name}.#{service.ejb.boundary_name}"
      end

      def implementation_suffix
        service.data_module.repository.ejb.implementation_suffix
      end

      java_artifact :service, :service, :server, :ee, '#{service.name}'
      java_artifact :service_implementation, :service, :server, :ee, '#{service.name}#{implementation_suffix}'
      java_artifact :boundary_interface, :service, :server, :ee, 'Local#{service_name}Boundary'
      java_artifact :remote_service, :service, :server, :ee, 'Remote#{service_name}'
      java_artifact :boundary_implementation, :service, :server, :ee, '#{service_name}Boundary#{implementation_suffix}', :sub_package => 'internal'
      java_artifact :service_test, :service, :server, :ee, 'Abstract#{service_name}#{implementation_suffix}Test'

      def qualified_concrete_service_test_name
        "#{qualified_service_test_name.gsub(/\.Abstract/,'.')}"
      end

      attr_accessor :boundary_extends

      def boundary_interceptors
        @boundary_interceptors ||= []
      end

      def boundary_annotations
        @boundary_annotations ||= []
      end

      attr_writer :local

      def local?
        @local.nil? ? true : @local
      end

      def remote=(remote)
        self.local = !remote
      end

      def remote?
        !local?
      end

      attr_accessor :generate_boundary

      def generate_boundary?
        if @generate_boundary.nil?
          return service.jmx? ||
            service.jws? ||
            service.jaxrs? ||
            service.imit? ||
            service.methods.any? { |method| method.parameters.any? { |parameter| parameter.reference? } || method.return_value.reference? }
        else
          return @generate_boundary
        end
      end

      def bind_in_tests?
        @bind_in_tests.nil? ? true : !!@bind_in_tests
      end

      def bind_in_tests=(bind_in_tests)
        @bind_in_tests = bind_in_tests
      end

      def generate_base_test?
        @generate_base_test.nil? ? true : !!@generate_base_test
      end

      def generate_base_test=(generate_base_test)
        @generate_base_test = generate_base_test
      end
    end

    facet.enhance(Method) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :scheduler, :service, :server, :ee, '#{method.service.name}#{method.name}ScheduleEJB', :sub_package => 'internal'

      def schedule
        raise "Attempted to access a schedule on #{method.qualified_name} when method has multiple parameters" unless method.parameters.empty?
        @schedule ||= Domgen::Ejb::Schedule.new(method)
      end

      def schedule?
        !@schedule.nil?
      end
    end

    facet.enhance(Parameter) do
      include Domgen::Java::EEJavaCharacteristic

      protected

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

    facet.enhance(Exception) do
      attr_writer :rollback

      def rollback?
        @rollback.nil? ? true : @rollback
      end
    end
  end
end
