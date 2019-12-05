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
      java_artifact :entrypoint_dagger_module, :ioc, :client, :gwt, '#{name}EntrypointDaggerModule'
      java_artifact :gwt_module, :modules, nil, :gwt, '#{name}EntrypointSupport'

      def modules_package
        entrypoint.gwt_repository.modules_package
      end

      def qualified_application_name
        "#{gwt_repository.repository.gwt.client_package}.#{name}App"
      end

      attr_reader :name

      def dagger_modules
        modules = [self.gwt_repository.repository.gwt.qualified_aggregate_dagger_module_name]
        if self.gwt_repository.repository.gwt.include_standard_user_experience_dagger_module?
          modules += [self.gwt_repository.repository.gwt.qualified_user_experience_dagger_module_name]
        end
        modules + self.additional_dagger_modules
      end

      def additional_dagger_modules
        @additional_dagger_modules ||= []
      end
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
      java_artifact :abstract_dagger_component, :ioc, :client, :gwt, 'Abstract#{repository.name}DaggerComponent'
      java_artifact :abstract_application, nil, :client, :gwt, 'Abstract#{repository.name}App'
      java_artifact :aggregate_dagger_module, :ioc, :client, :gwt, '#{repository.name}DaggerModule'
      java_artifact :user_experience_dagger_module, :ioc, :client, :gwt, '#{repository.name}UserExperienceDaggerModule'

      java_artifact :rdate, :data_type, :client, :gwt, 'RDate', :sub_package => 'util'

      java_artifact :dev_module, :modules, nil, :gwt, '#{repository.name}DevSupport'
      java_artifact :prod_module, :modules, nil, :gwt, '#{repository.name}ProdSupport'
      java_artifact :app_module, :modules, nil, :gwt, '#{repository.name}AppSupport'
      java_artifact :model_module, :modules, nil, :gwt, '#{repository.name}ModelSupport'

      java_artifact :abstract_client_test, :test, :client, :gwt, 'Abstract#{repository.name}ClientTest', :sub_package => 'util'
      java_artifact :client_test, :test, :client, :gwt, '#{repository.name}ClientTest', :sub_package => 'util'
      java_artifact :standard_test_module, :test, :client, :gwt, '#{repository.name}TestModule', :sub_package => 'util'
      java_artifact :callback_success_answer, :test, :client, :gwt, '#{repository.name}CallbackSuccessAnswer', :sub_package => 'util'
      java_artifact :callback_failure_answer, :test, :client, :gwt, '#{repository.name}CallbackFailureAnswer', :sub_package => 'util'
      java_artifact :abstract_client_ux_test, :test, :client, :gwt, 'Abstract#{repository.name}UserExperienceTest', :sub_package => 'util'
      java_artifact :client_ux_test, :test, :client, :gwt, '#{repository.name}UserExperienceTest', :sub_package => 'util'
      java_artifact :standard_ux_test_module, :test, :client, :gwt, '#{repository.name}UserExperienceTestModule', :sub_package => 'util'

      def generate_sync_callbacks?
        repository.gwt_rpc? || repository.imit?
      end

      def dagger_modules
        Domgen.error("Attempting to call dagger_modules but dagger is disabled") unless enable_dagger?
        dagger_modules_map.dup
      end

      def add_dagger_module(name, classname)
        Domgen.error("Attempting to add dagger module but dagger is disabled. Name = '#{name}', Classname = '#{classname}'") unless enable_dagger?
        Domgen.error("Attempting to define duplicate module for gwt facet. Name = '#{name}', Classname = '#{classname}'") if dagger_modules_map[name.to_s]
        dagger_modules_map[name.to_s] = classname
      end

      attr_writer :include_standard_user_experience_dagger_module

      def include_standard_user_experience_dagger_module?
        @include_standard_user_experience_dagger_module.nil? ? enable_dagger? : !!@include_standard_user_experience_dagger_module
      end

      attr_writer :enable_dagger

      def enable_dagger?
        @enable_dagger.nil? ? true : !!@enable_dagger
      end

      attr_writer :custom_base_client_test

      def custom_base_client_test?
        @custom_base_client_test.nil? ? false : !!@custom_base_client_test
      end

      def test_factories
        test_factory_map.dup
      end

      def add_test_factory(short_code, classname)
        raise "Attempting to add a test factory '#{classname}' with short_code #{short_code} but one already exists. ('#{test_factory_map[short_code.to_s]}')" if test_factory_map[short_code.to_s]
        test_factory_map[short_code.to_s] = classname
      end

      def test_modules
        test_modules_map.dup
      end

      def add_test_module(name, classname)
        Domgen.error("Attempting to define duplicate test module for gwt facet. Name = '#{name}', Classname = '#{classname}'") if test_modules_map[name.to_s]
        test_modules_map[name.to_s] = classname
      end

      def test_class_contents
        test_class_content_list.dup
      end

      def add_test_class_content(content)
        self.test_class_content_list << content
      end

      attr_writer :include_standard_test_module

      def include_standard_test_module?
        @include_standard_test_module.nil? ? true : !!@include_standard_test_module
      end

     attr_writer :custom_base_ux_client_test

      def custom_base_ux_client_test?
        @custom_base_ux_client_test.nil? ? false : !!@custom_base_ux_client_test
      end

      def ux_test_factories
        ux_test_factory_map.dup
      end

      def add_ux_test_factory(short_code, classname)
        raise "Attempting to add a test factory '#{classname}' with short_code #{short_code} but one already exists. ('#{ux_test_factory_map[short_code.to_s]}')" if ux_test_factory_map[short_code.to_s]
        ux_test_factory_map[short_code.to_s] = classname
      end

      def ux_test_modules
        ux_test_modules_map.dup
      end

      def add_ux_test_module(name, classname)
        Domgen.error("Attempting to define duplicate ux test module for gwt facet. Name = '#{name}', Classname = '#{classname}'") if ux_test_modules_map[name.to_s]
        ux_test_modules_map[name.to_s] = classname
      end

      def ux_test_class_contents
        ux_test_class_content_list.dup
      end

      def add_ux_test_class_content(content)
        self.ux_test_class_content_list << content
      end

      attr_writer :include_standard_ux_test_module

      def include_standard_ux_test_module?
        @include_standard_ux_test_module.nil? ? true : !!@include_standard_ux_test_module
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
          repository.gwt_cache_filter.add_gzip_filter_path("/#{self.module_name}/*")
        end
      end

      def pre_verify
        add_test_module(standard_test_module_name, qualified_standard_test_module_name) if include_standard_test_module?
        add_ux_test_module(standard_ux_test_module_name, qualified_standard_ux_test_module_name) if include_standard_ux_test_module?
        add_test_class_content(<<CONTENT) if repository.gwt.generate_sync_callbacks?

  @java.lang.SuppressWarnings( { "unchecked", "UnusedParameters" } )
  protected final <T> java.lang.Class<#{repository.gwt.qualified_async_callback_name}<T>> asyncResultType( @javax.annotation.Nonnull final java.lang.Class<T> type )
  {
    return (Class) #{repository.gwt.qualified_async_callback_name}.class;
  }
CONTENT
      end

      protected

      def test_factory_map
        @test_factory_map ||= {}
      end

      def test_class_content_list
        @test_class_content ||= []
      end

      def test_modules_map
        @test_modules_map ||= {}
      end

      def ux_test_factory_map
        @ux_test_factory_map ||= {}
      end

      def ux_test_class_content_list
        @ux_test_class_content ||= []
      end

      def ux_test_modules_map
        @ux_test_modules_map ||= {}
      end

      def dagger_modules_map
        @dagger_modules_map ||= {}
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

      attr_writer :short_test_code

      def short_test_code
        @short_test_code || Reality::Naming.split_into_words(data_module.name.to_s).collect { |w| w[0, 1] }.join.downcase
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
