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
        @concurrency_management_type = :bean
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
      attr_reader :concurrency_management_type

      def concurrency_management_type=(cmt)
        Domgen.error("concurrency_management_type #{cmt} is invalid") unless [:bean, :container].include?(cmt)
        @concurrency_management_type = cmt
      end

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

      java_artifact :no_web_interceptor, :service, :server, :ejb, '#{repository.name}NoWebIntereptor'
      java_artifact :no_web_invoke_annotation, :service, :server, :ejb, '#{repository.name}NoWebInvoke'
      java_artifact :complete_module, :test, :server, :ejb, '#{repository.name}Module', :sub_package => 'util'
      java_artifact :services_module, :test, :server, :ejb, '#{repository.name}ServicesModule', :sub_package => 'util'
      java_artifact :cdi_types_test, :test, :server, :ejb, '#{repository.name}CdiTypesTest', :sub_package => 'util'
      java_artifact :aggregate_service_test, :test, :server, :ejb, '#{repository.name}AggregateServiceTest', :sub_package => 'util'
      java_artifact :abstract_service_test, :test, :server, :ejb, 'Abstract#{repository.name}ServiceTest', :sub_package => 'util'
      java_artifact :base_service_test, :test, :server, :ejb, '#{repository.name}ServiceTest', :sub_package => 'util'
      java_artifact :server_test_module, :test, :server, :ejb, '#{repository.name}ServerModule', :sub_package => 'util'

      attr_writer :include_server_test_module

      def include_server_test_module?
        @include_server_test_module.nil? ? true : !!@include_server_test_module
      end

      attr_writer :custom_base_service_test

      def custom_base_service_test?
        @custom_base_service_test.nil? ? false : !!@custom_base_service_test
      end

      def test_modules
        test_modules_map.dup
      end

      def add_test_module(name, classname)
        Domgen.error("Attempting to define duplicate test module for ejb facet. Name = '#{name}', Classname = '#{classname}'") if test_modules_map[name.to_s]
        test_modules_map[name.to_s] = classname
      end

      def flushable_test_modules
        flushable_test_modules_map.dup
      end

      def add_flushable_test_module(name, classname)
        Domgen.error("Attempting to define duplicate flushable test module for ejb facet. Name = '#{name}', Classname = '#{classname}'") if flushable_test_modules_map[name.to_s]
        flushable_test_modules_map[name.to_s] = classname
      end

      def test_class_contents
        test_class_content_list.dup
      end

      def add_test_class_content(content)
        self.test_class_content_list << content
      end

      def pre_verify
        if self.include_server_test_module?
          add_test_module(self.server_test_module_name, self.qualified_server_test_module_name)
        end
        add_test_module(repository.ee.message_module_name, repository.ee.qualified_message_module_name)
        add_flushable_test_module(self.services_module_name, self.qualified_services_module_name)
      end

      def any_no_web_invoke?
        self.repository.data_modules.each do |data_module|
          return true if data_module.services.any?{|service| service.ejb? && service.ejb.no_web_invoke?}
        end
        return false
      end

      protected

      def test_class_content_list
        @test_class_content ||= []
      end

      def flushable_test_modules_map
        @flushable_test_modules_map ||= {}
      end

      def test_modules_map
        @test_modules_map ||= {}
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::EEClientServerJavaPackage

      java_artifact :aggregate_service_test, :test, :server, :ejb, '#{data_module.name}AggregateServiceTest'
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

      java_artifact :service, :service, :server, :ejb, '#{service.name}'
      java_artifact :service_implementation, :service, :server, :ejb, '#{service.name}Impl'
      java_artifact :boundary_interface, :service, :server, :ejb, 'Local#{service_name}Boundary'
      java_artifact :remote_service, :service, :server, :ejb, 'Remote#{service_name}'
      java_artifact :boundary_implementation, :service, :server, :ejb, '#{service_name}BoundaryImpl'
      java_artifact :service_test, :service, :server, :ejb, 'Abstract#{service_name}ImplTest'

      attr_writer :module_local

      def module_local?
        @module_local.nil? ? false : !!@module_local
      end

      attr_writer :boundary_module_local

      def boundary_module_local?
        @boundary_module_local.nil? ? self.module_local? : !!@boundary_module_local
      end

      attr_writer :no_web_invoke

      def no_web_invoke!
        self.no_web_invoke = true
      end

      def no_web_invoke?
        @no_web_invoke.nil? ? false : !!@no_web_invoke
      end

      def qualified_concrete_service_test_name
        "#{qualified_service_test_name.gsub(/\.Abstract/,'.')}"
      end

      attr_writer :qualified_base_service_test_name

      def qualified_base_service_test_name
        @qualified_base_service_test_name.nil? ? self.service.data_module.repository.ejb.qualified_base_service_test_name : @qualified_base_service_test_name
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
            service.jms? ||
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

      def pre_pre_complete
        if self.no_web_invoke?
          self.service.disable_facets(:gwt, :jaxrs)
          self.boundary_annotations << self.service.data_module.repository.ejb.qualified_no_web_invoke_annotation_name
        end
      end

      def post_verify
        if generate_base_test? && !service.methods.any?{|m| m.ejb? && m.ejb.generate_base_test?}
          self.generate_base_test = false
        end
      end
    end

    facet.enhance(Method) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :scheduler, :service, :server, :ee, '#{method.service.name}#{method.name}ScheduleEJB'

      def schedule
        raise "Attempted to access a schedule on #{method.qualified_name} when method has multiple parameters" unless method.parameters.empty?
        @schedule ||= Domgen::Ejb::Schedule.new(method)
      end

      def schedule?
        !@schedule.nil?
      end

      def boundary_interceptors
        @boundary_interceptors ||= []
      end

      def boundary_annotations
        @boundary_annotations ||= []
      end

      attr_accessor :generate_boundary

      def generate_boundary?
        @generate_boundary.nil? ? self.method.service.ejb.generate_boundary? : !!@generate_boundary
      end

      def generate_base_test?
        @generate_base_test.nil? ? true : !!@generate_base_test
      end

      def generate_base_test=(generate_base_test)
        @generate_base_test = generate_base_test
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
      attr_writer :skip_test

      def skip_test?
        @skip_test.nil? ? false : !!@skip_test
      end

      attr_writer :rollback

      def rollback?
        @rollback.nil? ? true : @rollback
      end
    end
  end
end
