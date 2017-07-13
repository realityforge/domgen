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
      java_artifact :entrypoint_module, :ioc, :client, :gwt, '#{name}EntrypointModule'
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

      attr_writer :client_event_package

      def client_event_package
        @client_event_package || "#{client_package}.event"
      end

      java_artifact :async_callback, :service, :client, :gwt, '#{repository.name}AsyncCallback'
      java_artifact :async_error_callback, :service, :client, :gwt, '#{repository.name}AsyncErrorCallback'
      java_artifact :abstract_ginjector, :ioc, :client, :gwt, 'Abstract#{repository.name}Ginjector'
      java_artifact :abstract_application, nil, :client, :gwt, 'Abstract#{repository.name}App'
      java_artifact :aggregate_module, :ioc, :client, :gwt, '#{repository.name}Module'

      java_artifact :dev_module, :modules, nil, :gwt, '#{repository.name}DevSupport'
      java_artifact :prod_module, :modules, nil, :gwt, '#{repository.name}ProdSupport'
      java_artifact :app_module, :modules, nil, :gwt, '#{repository.name}AppSupport'
      java_artifact :model_module, :modules, nil, :gwt, '#{repository.name}ModelSupport'

      java_artifact :abstract_client_test, :test, :client, :gwt, 'Abstract#{repository.name}ClientTest', :sub_package => 'util'
      java_artifact :client_test, :test, :client, :gwt, '#{repository.name}ClientTest', :sub_package => 'util'
      java_artifact :support_test_module, :test, :client, :gwt, '#{repository.name}SupportTestModule', :sub_package => 'util'
      java_artifact :standard_test_module, :test, :client, :gwt, '#{repository.name}TestModule', :sub_package => 'util'
      java_artifact :callback_success_answer, :test, :client, :gwt, '#{repository.name}CallbackSuccessAnswer', :sub_package => 'util'
      java_artifact :callback_failure_answer, :test, :client, :gwt, '#{repository.name}CallbackFailureAnswer', :sub_package => 'util'
      java_artifact :abstract_client_ux_test, :test, :client, :gwt, 'Abstract#{repository.name}UserExperienceTest', :sub_package => 'util'
      java_artifact :client_ux_test, :test, :client, :gwt, '#{repository.name}UserExperienceTest', :sub_package => 'util'
      java_artifact :standard_ux_test_module, :test, :client, :gwt, '#{repository.name}UserExperienceTestModule', :sub_package => 'util'
      java_artifact :debug_config, nil, :client, :gwt, '#{repository.name}DebugConfig'

      def debug_config
        @debug_config ||= {
          'emit_raw_uncaught_exceptions' => {:default_value => true, :production_value => false},
        }
      end

      def gin_modules
        gin_modules_map.dup
      end

      def add_gin_module(name, classname)
        Domgen.error("Attempting to define duplicate test module for gwt facet. Name = '#{name}', Classname = '#{classname}'") if gin_modules_map[name.to_s]
        gin_modules_map[name.to_s] = classname
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
      end

      def pre_verify
        add_test_module(standard_test_module_name, qualified_standard_test_module_name) if include_standard_test_module?
        add_test_module(support_test_module_name, qualified_support_test_module_name)
        add_ux_test_module(standard_ux_test_module_name, qualified_standard_ux_test_module_name) if include_standard_ux_test_module?
        add_test_class_content(<<CONTENT)

  @java.lang.SuppressWarnings( { "unchecked", "UnusedParameters" } )
  protected final <T> java.lang.Class<#{repository.gwt.qualified_async_callback_name}<T>> asyncResultType( @javax.annotation.Nonnull final java.lang.Class<T> type )
  {
    return (Class) #{repository.gwt.qualified_async_callback_name}.class;
  }

  @javax.annotation.Nonnull
  protected final <H> H addHandler( @javax.annotation.Nonnull final com.google.web.bindery.event.shared.Event.Type<H> type, final H handler )
  {
    eventBus().addHandler( type, handler );
    return handler;
  }

  protected final void fireEvent( @javax.annotation.Nonnull final com.google.web.bindery.event.shared.Event<?> event )
  {
    eventBus().fireEvent( event );
  }

  @javax.annotation.Nonnull
  protected final com.google.gwt.event.shared.EventBus eventBus()
  {
    return s( com.google.gwt.event.shared.EventBus.class );
  }

  protected final <T extends com.google.web.bindery.event.shared.Event<?>> T event( @javax.annotation.Nonnull final T value )
  {
    return org.mockito.Matchers.refEq( value, "source" );
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

      def gin_modules_map
        @gin_modules_map ||= {}
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

      attr_writer :client_event_package

      def client_event_package
        @client_event_package || resolve_package(:client_event_package)
      end

      def generate_struct_factory?
        data_module.structs.select{|s|s.gwt? && s.gwt.generate_overlay?}.size > 0
      end

      attr_writer :short_test_code

      def short_test_code
        @short_test_code || Reality::Naming.split_into_words(data_module.name.to_s).collect { |w| w[0, 1] }.join.downcase
      end

      java_artifact :struct_test_factory, :test, :client, :gwt, '#{data_module.name}StructFactory', :sub_package => 'util'
      java_artifact :abstract_struct_test_factory, :test, :client, :gwt, 'Abstract#{data_module.name}StructFactory', :sub_package => 'util'

      def pre_complete
        if generate_struct_factory?
          data_module.repository.gwt.add_test_factory("#{short_test_code}s", qualified_struct_test_factory_name)
        end
      end

      protected

      def facet_key
        :gwt
      end
    end

    facet.enhance(Message) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :event, :event, :client, :gwt, '#{message.name}Event'
    end

    facet.enhance(MessageParameter) do
      include Domgen::Java::ImitJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    facet.enhance(Struct) do
      include Domgen::Java::BaseJavaGenerator

      # Needed to hook into standard java type resolution code
      def qualified_name
        self.qualified_interface_name
      end

      attr_writer :generate_overlay

      def generate_overlay?
        @generate_overlay.nil? ? true : !!@generate_overlay
      end

      java_artifact :interface, :data_type, :client, :gwt, '#{struct.name}'
      java_artifact :jso, :data_type, :client, :gwt, 'Jso#{struct.name}'
      java_artifact :java, :data_type, :client, :gwt, 'Java#{struct.name}'
      java_artifact :factory, :data_type, :client, :gwt, '#{struct.name}Factory'
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

    facet.enhance(EnumerationSet) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :name, :data_type, :client, :gwt, '#{enumeration.name}'
    end
  end
end
