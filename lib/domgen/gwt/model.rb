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
  module Gwt
    class Entrypoint < Domgen.ParentedElement(:gwt_repository)
      def initialize(gwt_repository, name, options = {}, &block)
        @name = name
        super(gwt_repository, options, &block)
      end

      include Domgen::Java::BaseJavaGenerator

      java_artifact :entrypoint, nil, :client, :gwt, '#{name}'
      java_artifact :gwt_module, :modules, nil, :gwt, '#{name}EntrypointSupport'

      def modules_package
        entrypoint.gwt_repository.modules_package
      end

      def qualified_application_name
        "#{gwt_repository.repository.gwt.client_package}.#{name}App"
      end

      attr_reader :name
    end
  end

  FacetManager.facet(:gwt => [:java, :json, :ce]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      attr_writer :module_name

      def module_name
        @module_name || Reality::Naming.underscore(repository.name)
      end

      java_artifact :async_callback, :service, :client, :gwt, '#{repository.name}AsyncCallback'
      java_artifact :async_error_callback, :service, :client, :gwt, '#{repository.name}AsyncErrorCallback'
      java_artifact :abstract_sting_injector, :ioc, :client, :gwt, 'Abstract#{repository.name}Injector'
      java_artifact :abstract_application, nil, :client, :gwt, 'Abstract#{repository.name}App'
      java_artifact :aggregate_sting_fragment, :ioc, :client, :gwt, '#{repository.name}Fragment'

      java_artifact :rdate, :data_type, :client, :gwt, 'RDate', :sub_package => 'util'

      java_artifact :dev_module, :modules, nil, :gwt, '#{repository.name}DevSupport'
      java_artifact :prod_module, :modules, nil, :gwt, '#{repository.name}ProdSupport'
      java_artifact :app_module, :modules, nil, :gwt, '#{repository.name}AppSupport'
      java_artifact :model_module, :modules, nil, :gwt, '#{repository.name}ModelSupport'

      java_artifact :abstract_client_test, :test, :client, :gwt, 'Abstract#{repository.name}ClientTest', :sub_package => 'util'
      java_artifact :abstract_test_sting_injector, :test, :client, :gwt, 'Abstract#{repository.name}TestInjector', :sub_package => 'util'
      java_artifact :test_fragment, :test, :client, :gwt, '#{repository.name}TestFragment', :sub_package => 'util'
      java_artifact :value_util, :test, :client, :gwt, 'ValueUtil', :sub_package => 'util'
      java_artifact :default_test_injector, :test, :client, :gwt, '#{repository.name}TestInjector', :sub_package => 'util'
      java_artifact :client_test, :test, :client, :gwt, '#{repository.name}ClientTest', :sub_package => 'util'
      java_artifact :client_entity_test, :test, :client, :gwt, '#{repository.name}EntityClientTest', :sub_package => 'util'
      java_artifact :callback_success_answer, :test, :client, :gwt, '#{repository.name}CallbackSuccessAnswer', :sub_package => 'util'
      java_artifact :callback_failure_answer, :test, :client, :gwt, '#{repository.name}CallbackFailureAnswer', :sub_package => 'util'

      def generate_sync_callbacks?
        repository.gwt_rpc? || repository.imit?
      end

      # Includes added to the aggregate test fragment
      def sting_test_includes
        (@sting_test_includes ||= [])
      end

      # Includes added to the default test injector
      def sting_test_injector_includes
        (@sting_test_injector_includes ||= [])
      end

      def sting_includes
        (@sting_includes ||= [])
      end

      attr_writer :custom_base_client_test

      def custom_base_client_test?
        @custom_base_client_test.nil? ? false : !!@custom_base_client_test
      end

      attr_writer :custom_default_test_injector

      def custom_default_test_injector?
        @custom_default_test_injector.nil? ? false : !!@custom_default_test_injector
      end

      def test_class_contents
        test_class_content_list.dup
      end

      def add_test_class_content(content)
        self.test_class_content_list << content
      end

      attr_writer :client_util_data_type_package

      def client_util_data_type_package
        @client_util_data_type_package || "#{client_data_type_package}.util"
      end

      attr_writer :modules_package

      def modules_package
        @modules_package || "#{repository.java.base_package}.modules"
      end

      attr_writer :client_ioc_package

      def client_ioc_package
        @client_ioc_package || "#{client_package}.ioc"
      end

      attr_writer :enable_entrypoints

      def enable_entrypoints?
        @enable_entrypoints.nil? ? true : !!@enable_entrypoints
      end

      attr_writer :enable_sting_injectors

      def enable_sting_injectors?
        @enable_sting_injectors.nil? ? true : !!@enable_sting_injectors
      end

      def default_entrypoint
        key = repository.name.to_s
        entrypoint(key) unless entrypoint_by_name?(key)
        entrypoint_by_key(key)
      end

      def entrypoint_by_name?(name)
        !!entrypoint_map[name.to_s]
      end

      def entrypoint_by_key(name)
        raise "No gwt entrypoint with name #{name} defined." unless entrypoint_map[name.to_s]
        entrypoint_map[name.to_s]
      end

      def entrypoint(name, options = {}, &block)
        raise "Gwt entrypoint with key #{name} already defined." if entrypoint_map[name.to_s]
        entrypoint_map[name.to_s] = Domgen::Gwt::Entrypoint.new(self, name, options, &block)
      end

      def entrypoints
        return [] unless enable_entrypoints?
        entrypoint_map.values
      end

      attr_writer :css_obfuscation_prefix

      def css_obfuscation_prefix
        if @css_obfuscation_prefix.nil?
          words = Reality::Naming.split_into_words(repository.name.to_s)
          @css_obfuscation_prefix = (words.size == 1 ? repository.name.to_s : words.collect { |w| w[0, 1] }.join).downcase[0, 2]
        end
        @css_obfuscation_prefix
      end

      Domgen.target_manager.target(:entrypoint, :repository, :facet_key => :gwt)

      def pre_complete
        if repository.ee?
          repository.ee.cdi_scan_excludes << "#{repository.gwt.client_package}.**"
          repository.ee.cdi_scan_excludes << 'org.realityforge.gwt.**'
          repository.ee.cdi_scan_excludes << 'com.google.web.**'
          repository.ee.cdi_scan_excludes << 'com.google.gwt.**'
        end
        if repository.gwt_cache_filter? && repository.application? && repository.application.user_experience?
          repository.gwt_cache_filter.add_cache_control_filter_path("/#{self.module_name}/*")
          repository.gwt_cache_filter.add_brotli_filter_path("/#{self.module_name}/*")
        end
      end

      def pre_verify
        add_test_class_content(<<CONTENT) if repository.gwt.generate_sync_callbacks?

  @java.lang.SuppressWarnings( { "unchecked", "UnusedParameters" } )
  protected final <T> java.lang.Class<#{repository.gwt.qualified_async_callback_name}<T>> asyncResultType( @javax.annotation.Nonnull final java.lang.Class<T> type )
  {
    return (Class) #{repository.gwt.qualified_async_callback_name}.class;
  }
CONTENT
      end

      def post_verify
        self.sting_test_includes << self.qualified_aggregate_sting_fragment_name unless repository.gwt.sting_includes.empty?
        self.sting_test_injector_includes << self.qualified_test_fragment_name unless repository.gwt.sting_test_includes.empty?
      end

      protected

      def test_class_content_list
        @test_class_content ||= []
      end

      def ux_test_class_content_list
        @ux_test_class_content ||= []
      end

      def facet_key
        :gwt
      end

      private

      def entrypoint_map
        raise "Attempted to retrieve gwt entrypoints on #{repository.name} when entrypoints not defined." unless enable_entrypoints?
        unless @entrypoints
          @entrypoints = {}
          default_entrypoint
        end
        @entrypoints
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::ClientServerJavaPackage

      attr_writer :client_data_type_package

      def client_data_type_package
        @client_data_type_package || resolve_package(:client_data_type_package)
      end

      protected

      def facet_key
        :gwt
      end
    end

    facet.enhance(Struct) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :name, :data_type, :client, :gwt, '#{struct.name}'
    end

    facet.enhance(StructField) do
      include Domgen::Java::ImitJavaCharacteristic

      def name
        field.name
      end

      protected

      def characteristic
        field
      end
    end
  end
end
