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

Domgen::TypeDB.config_element('jpa.mssql') do
  attr_accessor :converter
end

Domgen::TypeDB.config_element('jpa.pgsql') do
  attr_accessor :converter
end

Domgen::TypeDB.config_element('jpa') do
  attr_writer :converter

  def converter(dialect)
    @converter || (dialect.is_a?(Domgen::Mssql::MssqlDialect) ? self.mssql.converter : self.pgsql.converter)
  end
end

[:point, :multipoint, :linestring, :multilinestring, :polygon, :multipolygon, :geometry,
 :pointm, :multipointm, :linestringm, :multilinestringm, :polygonm, :multipolygonm].each do |type_key|
  Domgen::TypeDB.enhance(type_key,
                         'jpa.pgsql.converter' => 'org.realityforge.jeo.geolatte.jpa.PostgisConverter',
                         'jpa.mssql.converter' => 'org.realityforge.jeo.geolatte.jpa.SqlServerConverter')
end

module Domgen
  module JPA
    class DefaultValues < Domgen.ParentedElement(:entity)
      def initialize(entity, defaults, options = {}, &block)
        raise "Attempted to define #{default_type} on abstract entity #{entity.qualified_name}" if entity.abstract?
        raise "Attempted to define #{default_type} on #{entity.qualified_name} with no values" if defaults.empty?
        defaults.keys.each do |key|
          raise "Attempted to define #{default_type} on #{entity.qualified_name} with key '#{key}' that is not an attribute value" unless entity.attribute_by_name?(key)
          a = entity.attribute_by_name(key)
          raise "Attempted to define #{default_type} on #{entity.qualified_name} for attribute '#{key}' when attribute has no jpa facet defined. Defaults = #{defaults.inspect}" unless a.jpa?
          raise "Attempted to define #{default_type} on #{entity.qualified_name} for attribute '#{key}' when attribute when non persistent. Defaults = #{defaults.inspect}" unless a.jpa.persistent?
          raise "Attempted to define #{default_type} on #{entity.qualified_name} for attribute '#{key}' when attribute when generated. Defaults = #{defaults.inspect}" if a.generated_value?
        end
        values = {}
        defaults.each_pair do |k, v|
          values[k.to_s] = v
        end
        @values = values

        super(entity, options, &block)
      end

      def has_attribute?(name)
        @values.keys.include?(name.to_s)
      end

      def value_for(name)
        @values[name.to_s]
      end

      def values
        @values.dup
      end

      def default_type
        'default'
      end
    end

    class TestDefaultValues < DefaultValues
      def initialize(entity, defaults, options = {}, &block)
        super(entity, defaults, options, &block)
      end

      attr_writer :ignore

      def ignore?
        @ignore.nil? ? false : !!@ignore
      end

      def default_type
        'test_default'
      end
    end

    class UpdateDefaultValues < DefaultValues
      def initialize(entity, defaults, options = {}, &block)
        super(entity, defaults, options, &block)
      end

      attr_writer :factory_method_name

      def factory_method_name
        @factory_method_name.nil? ? self.default_factory_method_name : @factory_method_name
      end

      def default_factory_method_name
        'update'
      end
    end

    class TestUpdateDefaultValues < UpdateDefaultValues
      def initialize(entity, defaults, options = {}, &block)
        super(entity, defaults, options, &block)
      end

      def default_type
        'test_default'
      end

      def default_factory_method_name
        "update#{entity.name}"
      end

      def force_refresh?
        @force_refresh.nil? ? false : !!@force_refresh
      end

      attr_writer :force_refresh
    end

    module BaseJpaField
      def cascade
        @cascade || []
      end

      def cascade=(value)
        value = value.is_a?(Array) ? value : [value]
        invalid_cascades = value.select {|v| !self.class.cascade_types.include?(v)}
        unless invalid_cascades.empty?
          Domgen.error("cascade_type must be one of #{self.class.cascade_types.join(', ')}, not #{invalid_cascades.join(', ')}")
        end
        @cascade = value
      end

      def self.cascade_types
        [:all, :persist, :merge, :remove, :refresh, :detach]
      end

      def fetch_type
        @fetch_type || default_fetch_type
      end

      def default_fetch_type
        raise 'default_fetch_type not overridden'
      end

      def fetch_type=(fetch_type)
        Domgen.error("fetch_type #{fetch_type} is not recognized") unless BaseJpaField.fetch_types.include?(fetch_type)
        @fetch_type = fetch_type
      end

      def self.fetch_types
        [:eager, :lazy]
      end

      attr_reader :fetch_mode

      def fetch_mode=(fetch_mode)
        Domgen.error("fetch_mode #{fetch_mode} is not recognized") unless BaseJpaField.fetch_modes.include?(fetch_mode)
        @fetch_mode = fetch_mode
      end

      def self.fetch_modes
        [:select, :join, :subselect]
      end
    end

    class PersistenceUnitDescriptor < Domgen.ParentedElement(:jpa_repository)
      def initialize(jpa_repository, options = {}, &block)
        super(jpa_repository, options, &block)
      end

      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :raw_test_module, :test, :server, :jpa, '#{jpa_repository.repository.name}#{short_name}PersistenceTestModule', :sub_package => 'util'
      java_artifact :persistence_unit_test_util, :test, :server, :jpa, '#{jpa_repository.repository.name}#{jpa_repository.repository.name == short_name ? "" : short_name}PersistentUnitTestUtil', :sub_package => 'util'
      java_artifact :persistence_unit_module, :test, :server, :jpa, '#{jpa_repository.repository.name}#{jpa_repository.repository.name == short_name ? "" : short_name}PersistentUnitTestModule', :sub_package => 'util'

      Domgen.target_manager.target(:persistence_unit, :repository, :facet_key => :jpa, :access_method => :persistence_units)

      def generate_test_util?
        related_database_keys.size > 0
      end

      attr_writer :unit_name

      def unit_name
        @unit_name || jpa_repository.repository.name
      end

      def name
        unit_name
      end

      attr_writer :short_name

      def short_name
        @short_name || unit_name
      end

      attr_writer :classes

      def classes
        @classes ||= []
      end

      attr_writer :provider

      def provider
        @provider.nil? ? :eclipselink : @provider
      end

      def provider_class
        return 'org.eclipse.persistence.jpa.PersistenceProvider' if self.provider == :eclipselink
        return 'org.hibernate.ejb.HibernatePersistence' if self.provider == :hibernate
        return nil if self.provider.nil?
      end

      attr_writer :properties

      def application_scope
        Reality::Naming.underscore(jpa_repository.repository.name)
      end

      def applicationScope
        jpa_repository.repository.name
      end

      def resolved_properties
        results = {}
        properties.each do |k, v|
          results[k] = interpolate(v.to_s)
        end
        results
      end

      def interpolate(content)
        content.gsub(/{{([^}]+)}}/) do |m|
          self.instance_eval($1)
        end
      end

      def properties
        @properties ||= default_properties
      end

      def related_database_keys
        @related_database_keys ||= []
      end

      def related_database_jndi(key)
        prefix = jpa_repository.repository.name == short_name ? '' : "#{Reality::Naming.underscore(short_name)}/"
        "#{application_scope}/env/#{prefix}#{key}_database_name"
      end

      def default_properties
        if provider.nil? || provider == :eclipselink
          {
            'eclipselink.logging.logger' => 'JavaLogger',
            'eclipselink.session-name' => "{{applicationScope}}#{self.unit_name}",
            'eclipselink.temporal.mutable' => 'false'
          }
        else
          {}
        end
      end

      attr_writer :xa_data_source

      def xa_data_source?
        @xa_data_source.nil? ? false : !!@xa_data_source
      end

      attr_writer :socket_timeout

      def socket_timeout
        @socket_timeout || '1200'
      end

      attr_writer :login_timeout

      def login_timeout
        @login_timeout || '60'
      end

      attr_writer :data_source

      def data_source
        @data_source || "{{application_scope}}/jdbc/#{self.short_name}"
      end

      def resolved_data_source
        interpolate(data_source)
      end

      attr_writer :exclude_unlisted_classes

      def exclude_unlisted_classes?
        @exclude_unlisted_classes.nil? ? true : @exclude_unlisted_classes
      end

      def valid_test_modes
        [:default, :manual, :raw, :mock]
      end

      # The test_mode determines how the framework manages units in test
      # - :default framework handled through normal means, user does nothing.
      # - :manual framework does nothing, user does all
      # - :raw framework creates a persistence unit that contains no entities but does give access to underlying database
      # - :mock framework creates a mock persistence unit in tests
      def test_mode
        @test_mode || :raw
      end

      def test_mode=(test_mode)
        raise "Invalid test_mode (#{test_mode.inspect}) supplied to persistence unit #{unit_name}. Valid modes #{valid_test_modes.inspect}" unless self.valid_test_modes.include?(test_mode)
        @test_mode = test_mode
      end

      def manual_test_mode?
        self.test_mode == :manual
      end

      def raw_test_mode?
        self.test_mode == :raw
      end

      def mock_test_mode?
        self.test_mode == :mock
      end
    end
  end

  FacetManager.facet(:jpa => [:sql, :ee]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      def version
        @version || (repository.ee.version == '6' ? '2.0' : '2.1')
      end

      def version=(version)
        Domgen.error("Unknown version '#{version}'") unless %w(2.0 2.1).include?(version)
        @version = version
      end

      attr_writer :default_username

      def default_username
        @default_username || Reality::Naming.underscore(repository.name)
      end

      attr_writer :include_default_unit

      def include_default_unit?
        @include_default_unit.nil? ? true : !!@include_default_unit
      end

      java_artifact :unit_descriptor, :entity, :server, :jpa, '#{repository.name}PersistenceUnit'
      java_artifact :persistent_test_module, :test, :server, :jpa, '#{repository.name}PersistenceTestModule', :sub_package => 'util'
      java_artifact :abstract_entity_test, :test, :server, :jpa, 'Abstract#{repository.name}EntityTest', :sub_package => 'util'
      java_artifact :base_entity_test, :test, :server, :jpa, '#{repository.name}EntityTest', :sub_package => 'util'
      java_artifact :standalone_entity_test, :test, :server, :jpa, 'Standalone#{repository.name}EntityTest', :sub_package => 'util'
      java_artifact :aggregate_entity_test, :test, :server, :jpa, '#{repository.name}AggregateEntityTest', :sub_package => 'util'
      java_artifact :dao_module, :test, :server, :jpa, '#{repository.name}RepositoryModule', :sub_package => 'util'
      java_artifact :test_factory_module, :test, :server, :jpa, '#{repository.name}FactorySetModule', :sub_package => 'util'

      attr_writer :use_time_service_for_now

      def use_time_service_for_now?
        @use_time_service_for_now.nil? ? false : !!@use_time_service_for_now
      end

      attr_writer :custom_base_entity_test

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
        Domgen.error("Attempting to define duplicate test module for jpa facet. Name = '#{name}', Classname = '#{classname}'") if test_modules_map[name.to_s]
        test_modules_map[name.to_s] = classname
      end

      def add_flushable_test_module(name, classname)
        add_test_module(name, "#{classname}( this )")
      end

      def test_class_contents
        test_class_content_list.dup
      end

      def add_test_class_content(content)
        self.test_class_content_list << content
      end

      def custom_base_entity_test?
        @custom_base_entity_test.nil? ? false : !!@custom_base_entity_test
      end

      def interpolate(content)
        content.gsub(/{{([^}]+)}}/) do |m|
          self.instance_eval($1)
        end
      end

      def application_scope
        Reality::Naming.underscore(repository.name)
      end

      def applicationScope
        repository.name
      end

      # There are 3 different variants of the persistence.xml and orm.xml that can be generated from domgen
      # depending on the context.
      #
      # * Template Variant: The template variant includes all the persistence orm fragments required for the
      #   model. This includes any native queries added to support DAOs, any standalone units added etc. However
      #   the output files may have values that need to be interpolated for deployment specific configuration
      #   such as the JNDI name and session name. It is typically in META-INF/domgen/templates directory in the
      #   model jar and only generated if repository.application.model_library?
      # * Application Variant: This includes everything from the template variant, with the interpolated values
      #   replaced with actual values. It may also include other fragments required for the application to run
      #   such as appconfig and syncrecord fragments. These must be specifically added. It is typically generated
      #   in the server jar if !repository.application.service_library?
      # * Test Variant: This is used to add test specific dependencies or if application is a service library.
      #   If repository.application.service_library? is true it will also include the complete contents the
      #   application variant. It may also include specifically defined fragments required
      #   to test the application. It is typically generated in the test directory of server jar.
      #
      # The helper methods have no prefix for template variant, 'application_' prefix for application variant and
      # 'test_' for test variant.
      #

      ['', 'application_', 'test_'].each do |prefix|

        class_eval <<-RUBY
          def #{prefix}artifact_fragments
            @#{prefix}artifact_fragments ||= []
          end

          def #{prefix}persistence_file_content_fragments
            @#{prefix}persistence_file_content_fragments ||= []
          end

          def #{prefix}persistence_file_fragments
            @#{prefix}persistence_file_fragments ||= []
          end

          def resolved_#{prefix}persistence_file_fragments(interpolate = true)
            fragments = self.#{prefix}persistence_file_fragments.collect do |fragment|
              repository.read_file(fragment)
            end
            fragments += #{prefix}persistence_file_content_fragments
            fragments += resolve_persistence_artifact_fragments(self.#{prefix}artifact_fragments)
            fragments.collect { |f| interpolate ? self.interpolate(f) : f }
          end

          def #{prefix}orm_file_content_fragments
            @#{prefix}orm_file_content_fragments ||= []
          end

          def #{prefix}orm_file_fragments
            @#{prefix}orm_file_fragments ||= []
          end

          def resolved_#{prefix}orm_file_fragments(interpolate = true)
            fragments = self.#{prefix}orm_file_fragments.collect do |fragment|
              repository.read_file(fragment)
            end
            fragments += #{prefix}orm_file_content_fragments
            fragments += resolve_orm_artifact_fragments(self.#{prefix}artifact_fragments)
            fragments.collect { |f| interpolate ? self.interpolate(f) : f }
          end
        RUBY
      end

      def resolve_persistence_artifact_fragments(artifacts)
        resolve_artifact_fragments(artifacts, 'META-INF/domgen/templates/persistence.xml')
      end

      def resolve_orm_artifact_fragments(artifacts)
        resolve_artifact_fragments(artifacts, 'META-INF/domgen/templates/orm.xml')
      end

      def resolve_artifact_fragments(artifacts, filename)
        artifacts.collect do |artifact_spec|
          interpolate(Domgen::Util.extract_template_from_artifact(artifact_spec, filename))
        end
      end

      def converters
        @converters ||= []
      end

      # Should domgen generate template xmls for model?
      def template_xmls?
        repository.application.model_library? && !repository.application.standalone_model_library?
      end

      # Should domgen generate real xmls for model?
      def model_xmls?
        repository.application.standalone_model_library?
      end

      # Should domgen generate real xmls in application jar?
      def application_xmls?
        !repository.application.service_library? && !repository.application.standalone_model_library?
      end

      # Should domgen generate test xmls?
      def test_xmls?
        repository.application.service_library? ||
          !test_persistence_file_content_fragments.empty?||
          !test_persistence_file_fragments.empty? ||
          !test_artifact_fragments.empty? ||
          !test_orm_file_fragments.empty?
      end

      attr_accessor :default_jpql_criterion

      def add_standalone_persistence_unit(short_name, options = {}, &block)
        name = options[:unit_name] || ("#{self.include_default_unit? ? self.unit_name : self.repository.name}#{short_name}")
        raise "Persistence unit with name #{name} already exists" if self.standalone_persistence_unit_map[name.to_s] || (self.include_default_unit? && self.unit_name.to_s == name.to_s)
        self.standalone_persistence_unit_map[name.to_s] = Domgen::JPA::PersistenceUnitDescriptor.new(self, { :short_name => short_name, :unit_name => name }.merge(options), &block)
      end

      def standalone_persistence_unit_by_name?(short_name)
        name = "#{self.include_default_unit? ? self.unit_name : self.repository.name}#{short_name}"
        !!self.standalone_persistence_unit_map[name.to_s]
      end

      def standalone_persistence_unit_by_name(short_name)
        name = "#{self.include_default_unit? ? self.unit_name : self.repository.name}#{short_name}"
        self.standalone_persistence_unit_map[name.to_s]
      end

      def standalone_persistence_units?
        !standalone_persistence_units.empty?
      end

      def standalone_persistence_units
        standalone_persistence_unit_map.values
      end

      def persistence_unit_by_name?(name)
        return true if self.include_default_unit? && self.unit_name.to_s == name.to_s
        standalone_persistence_unit_by_name?(name)
      end

      def persistence_unit_by_name(name)
        return self.default_persistence_unit if self.include_default_unit? && self.unit_name.to_s == name.to_s
        standalone_persistence_unit_by_name(name)
      end

      def persistence_units
        standalone_persistence_units + (self.include_default_unit? ? [self.default_persistence_unit] : [])
      end

      def unit_name=(unit_name)
        self.default_persistence_unit.unit_name = unit_name
      end

      def unit_name
        self.default_persistence_unit.unit_name
      end

      def properties=(properties)
        self.default_persistence_unit.properties = properties
      end

      def properties
        self.default_persistence_unit.properties
      end

      def resolved_properties
        self.default_persistence_unit.resolved_properties
      end

      def default_properties
        self.default_persistence_unit.default_properties
      end

      def data_source=(data_source)
        self.safe_default_persistence_unit.data_source = data_source
      end

      def data_source
        self.safe_default_persistence_unit.data_source
      end

      def resolved_data_source
        interpolate(data_source)
      end

      def exclude_unlisted_classes=(exclude_unlisted_classes)
        self.default_persistence_unit.exclude_unlisted_classes = exclude_unlisted_classes
      end

      def exclude_unlisted_classes?
        self.default_persistence_unit.exclude_unlisted_classes?
      end

      def provider=(provider)
        self.default_persistence_unit.provider = provider
      end

      def provider
        self.default_persistence_unit.provider
      end

      def provider_class
        self.default_persistence_unit.provider_class
      end

      def default_persistence_unit
        raise 'Attempting to access the default persistence_unit when no default unit included' unless self.include_default_unit?
        self.safe_default_persistence_unit
      end

      def pre_complete
        if repository.ee?
          # Just in case some attributes use spatial types
          repository.ee.cdi_scan_excludes << 'org.realityforge.jeo.geolatte.**'
        end
        self.standalone_persistence_units.each do |unit|
          fragment = <<FRAGMENT
<persistence-unit name="#{unit.unit_name}" transaction-type="JTA">
  <jta-data-source>#{unit.data_source}</jta-data-source>

FRAGMENT
          unit.classes.each do |cls|
            fragment << <<FRAGMENT
      <class>#{cls}</class>
FRAGMENT
          end
          fragment << <<FRAGMENT
  <exclude-unlisted-classes>#{unit.exclude_unlisted_classes?}</exclude-unlisted-classes>
  <shared-cache-mode>ENABLE_SELECTIVE</shared-cache-mode>
  <validation-mode>AUTO</validation-mode>

  <properties>
FRAGMENT

          unit.properties.each_pair do |key, value|
            fragment << "      <property name=\"#{key}\" value=\"#{value}\"/>\n"
          end
          fragment << <<FRAGMENT
  </properties>
</persistence-unit>
FRAGMENT
          repository.jpa.persistence_file_content_fragments << fragment
        end

        if repository.redfish?
          self.persistence_units.each do |unit|
            repository.redfish.persistence_unit(unit.short_name,
                                                unit.resolved_data_source,
                                                :xa_data_source => unit.xa_data_source?,
                                                :socket_timeout => unit.socket_timeout,
                                                :login_timeout => unit.login_timeout)

            unit.related_database_keys.each do |key|
              env_key = "#{Reality::Naming.uppercase_constantize(repository.name)}_#{repository.name == unit.short_name ? '' : "#{Reality::Naming.uppercase_constantize(unit.short_name)}_"}#{Reality::Naming.uppercase_constantize(key)}_DATABASE_NAME"
              repository.redfish.environment_variable(env_key)
              repository.redfish.custom_resource(unit.related_database_jndi(key), "${#{env_key}}")
            end
          end
        end
      end

      def perform_verify
        unless include_default_unit?
          persistent_entities =
            repository.data_modules.collect {|data_module| data_module.entities.select {|entity| entity.jpa?}}.flatten
          if persistent_entities.size > 0
            Domgen.error("Attempted to set repository.jpa.include_default_unit = false but persistent entities exist: #{persistent_entities.collect {|e| e.qualified_name}}")
          end
        end
      end

      def pre_verify
        add_test_module(persistent_test_module_name, qualified_persistent_test_module_name) if repository.jpa.include_default_unit?
        add_test_module(test_factory_module_name, qualified_test_factory_module_name)
        add_test_module(dao_module_name, qualified_dao_module_name)
        standalone_persistence_units.select {|unit| unit.mock_test_mode?}.each do |unit|
          add_test_module("#{unit.unit_name}PersistenceModule",
                          "org.realityforge.guiceyloops.server.MockPersistenceTestModule( #{qualified_unit_descriptor_name }.#{Reality::Naming.uppercase_constantize(unit.short_name)}_NAME )")
        end
        standalone_persistence_units.select {|unit| unit.raw_test_mode?}.each do |unit|
          add_test_module(unit.raw_test_module_name, unit.qualified_raw_test_module_name)
        end
        repository.jpa.persistence_units.select {|persistence_unit| persistence_unit.generate_test_util?}.each do |persistence_unit|
          add_test_module(persistence_unit.persistence_unit_module_name, persistence_unit.qualified_persistence_unit_module_name)
        end
        repository.data_modules.select {|data_module| data_module.jpa? && data_module.jpa.generate_test_factory?}.each do |data_module|
          add_test_factory(data_module.jpa.short_test_code, data_module.jpa.qualified_test_factory_name)
        end
        if include_default_unit?
          add_test_class_content(<<-JAVA)

  @javax.annotation.Nullable
  @java.lang.Override
  protected String getPrimaryPersistenceUnitName()
  {
    return #{qualified_unit_descriptor_name}.NAME;
  }
          JAVA
        else
          add_test_class_content(<<-JAVA)

  @Override
  public void flush()
  {
    //No default persistence unit so no need to flush
  }
          JAVA
        end
      end

      protected

      def test_class_content_list
        @test_class_content ||= []
      end

      def test_modules_map
        @test_modules_map ||= {}
      end

      def test_factory_map
        @test_factory_map ||= {}
      end

      def safe_default_persistence_unit
        @default_persistence_unit ||= Domgen::JPA::PersistenceUnitDescriptor.new(self, :test_mode => :default)
      end

      def standalone_persistence_unit_map
        @standalone_persistence_units ||= {}
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::EEClientServerJavaPackage

      attr_writer :short_test_code

      def short_test_code
        @short_test_code || Reality::Naming.split_into_words(data_module.name.to_s).collect {|w| w[0, 1]}.join.downcase
      end

      java_artifact :abstract_test_factory, :test, :server, :jpa, 'Abstract#{data_module.name}Factory', :sub_package => 'util'

      def server_util_test_package
        @server_util_test_package.nil? ? data_module.repository.jpa.server_util_test_package : @server_util_test_package
      end

      attr_writer :server_util_test_package

      attr_writer :test_factory_name

      def test_factory_name
        @test_factory_name || abstract_test_factory_name.gsub(/^Abstract/, '')
      end

      def qualified_test_factory_name
        "#{server_util_test_package}.#{test_factory_name}"
      end

      attr_writer :default_jpql_criterion

      def default_jpql_criterion
        @default_jpql_criterion.nil? ? data_module.repository.jpa.default_jpql_criterion : @default_jpql_criterion
      end

      def generate_test_factory?
        data_module.entities.any? {|e| e.jpa?}
      end
    end

    facet.enhance(DataAccessObject) do
      include Domgen::Java::BaseJavaGenerator

      def extensions
        @extensions ||= []
      end

      def friend_daos
        @friend_daos ||= []
      end

      attr_writer :module_local

      def module_local?
        @module_local.nil? ? (dao.repository? ? dao.entity.jpa.module_local? : false) : !!@module_local
      end

      attr_accessor :persistence_unit_name

      def transaction_type
        @transaction_type || :mandatory
      end

      def transaction_type=(transaction_type)
        raise "Attempted to set transaction_type to invalid #{transaction_type}" unless [:mandatory, :required, :requires_new].include?(transaction_type)
        @transaction_type = transaction_type
      end

      java_artifact :dao_service, :entity, :server, :jpa, '#{dao.name}', :sub_package => 'dao'
      java_artifact :dao, :entity, :server, :jpa, '#{dao_service_name}Impl', :sub_package => 'dao.internal'
      java_artifact :dao_test, :entity, :server, :jpa, 'Abstract#{dao_service_name}ImplTest', :sub_package => 'dao.internal'

      def qualified_concrete_dao_test_name
        "#{qualified_dao_test_name.gsub(/\.Abstract/, '.')}"
      end

      def perform_verify
        unless persistence_unit_name.nil?
          unless dao.data_module.repository.jpa.standalone_persistence_unit_by_name?(persistence_unit_name)
            Domgen.error("Defined a dao #{dao.name} that does not reference a standalone_persistence_unit but references non-existent #{persistence_unit_name}")
          end
        end
        self.friend_daos.each do |name|
          unless dao.data_module.dao_by_name?(name)
            Domgen.error("On dao #{dao.name} a friend #{name} was defined but this does not refer to a valid DAO")
          end
        end
      end
    end

    facet.enhance(Entity) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :generate_metamodel

      def generate_metamodel?
        @generate_metamodel.nil? ? true : !!@generate_metamodel
      end

      attr_writer :module_local

      def module_local?
        @module_local.nil? ? false : !!@module_local
      end

      def interfaces
        @interfaces ||= []
      end

      def track_changes?
        @track_changes.nil? ? entity.imit? && entity.attributes.any? {|a| !a.immutable?} : !!@track_changes
      end

      def track_changes=(track_changes)
        @track_changes = track_changes
      end

      attr_writer :table_name

      def table_name
        return @table_name unless @table_name.nil?
        Domgen.error("Attempted to call 'jpa.table_name' on subclass #{entity.qualified_name}") unless entity.extends.nil?
        entity.sql.view? ? entity.sql.view_name : entity.sql.table_name
      end

      attr_writer :jpql_name

      def jpql_name
        @jpql_name || entity.qualified_name.gsub('.', '_')
      end

      java_artifact :name, :entity, :server, :jpa, '#{entity.name}'
      java_artifact :metamodel, :entity, :server, :jpa, '#{name}_'
      java_artifact :abstract_model_test, :entity, :server, :jpa, 'Abstract#{entity.name}Test'
      java_artifact :model_test, :entity, :server, :jpa, '#{entity.name}Test'

      attr_writer :cacheable

      def cacheable?
        return @cacheable unless @cacheable.nil?
        return true if entity.read_only?
        # Eclipselink caches entity instances so all referenced and referencing entities must also be cacheable
        # This is to expensive to calculate so we require explicit configuration except in the most obvious of cases
        entity.referencing_attributes.empty? && entity.attributes.all? {|a| (a.immutable? || a.primary_key?) && !a.reference?}
      end

      attr_writer :support_create

      def support_create?
        @support_create.nil? ? (self.entity.sync? && self.entity.sync.core? && !self.entity.sync.support_unmanaged? ? false : !self.entity.sql.load_from_fixture?) : !!@support_create
      end

      attr_writer :support_update

      def support_update?
        @support_update.nil? ? (self.entity.sync? && self.entity.sync.core? && !self.entity.sync.support_unmanaged? ? false : !self.entity.sql.load_from_fixture?) : !!@support_update
      end

      attr_writer :support_delete

      def support_delete?
        self.entity.deletable? && (@support_delete.nil? ? true : !!@support_delete)
      end

      attr_writer :support_remove

      def support_remove?
        self.entity.deletable? && (@support_remove.nil? ? true : !!@support_remove)
      end

      attr_writer :support_refresh

      def support_refresh?
        @support_refresh.nil? ? false : !!@support_refresh
      end

      attr_writer :detachable

      def detachable?
        @detachable.nil? ? false : !!@detachable
      end

      def entity_listeners
        @entity_listeners ||= []
      end

      def test_create_default(defaults, options = {}, &block)
        default_values = Domgen::JPA::TestDefaultValues.new(entity, defaults, options, &block)
        existing_defaults = (@test_create_defaults ||= [])
        existing_defaults.delete_if{|v| v.values.keys.sort == default_values.values.keys.sort}
        existing_defaults << default_values
        default_values
      end

      def test_create_defaults
        @test_create_defaults.nil? ? [] : @test_create_defaults.dup
      end

      def delete_test_create_default(keys)
        existing_defaults = (@test_create_defaults ||= [])
        existing_defaults.delete_if {|v| p v.values.keys; v.values.keys.sort == keys.sort}
        existing_defaults
      end

      def test_update_default(defaults, options = {}, &block)
        default_values = Domgen::JPA::TestUpdateDefaultValues.new(entity, defaults, options, &block)
        existing_defaults = (@test_update_defaults ||= [])
        existing_defaults.delete_if{|v| v.values.keys.sort == default_values.values.keys.sort}
        existing_defaults << default_values
        default_values
      end

      def test_update_defaults
        @test_update_defaults.nil? ? [] : @test_update_defaults.dup
      end

      def create_default(defaults, options = {}, &block)
        default_values = Domgen::JPA::DefaultValues.new(entity, defaults, options, &block)
        existing_defaults = (@create_defaults ||= [])
        existing_defaults.delete_if{|v| v.values.keys.sort == default_values.values.keys.sort}
        existing_defaults << default_values
        default_values
      end

      def create_defaults
        @create_defaults.nil? ? [] : @create_defaults.dup
      end

      def remove_create_defaults(defaults)
        @create_defaults.delete(defaults)
      end

      def update_default(defaults, options = {}, &block)
        default_values = Domgen::JPA::UpdateDefaultValues.new(entity, defaults, options, &block)
        existing_defaults = (@update_defaults ||= [])
        existing_defaults.delete_if{|v| v.values.keys.sort == default_values.values.keys.sort}
        existing_defaults << default_values
        default_values
      end

      def update_defaults
        @update_defaults.nil? ? [] : @update_defaults.dup
      end

      def remove_update_default(defaults)
        @update_defaults.delete(defaults)
      end

      attr_writer :default_jpql_criterion

      def default_jpql_criterion
        @default_jpql_criterion.nil? ? entity.data_module.jpa.default_jpql_criterion : @default_jpql_criterion
      end

      def non_standard_model_constraints?
        !entity.sql.constraints.select {|constraint| !constraint.standard?}.empty? ||
          !entity.sql.function_constraints.select {|constraint| !constraint.standard?}.empty? ||
          !entity.sql.validations.select {|validation| !validation.standard?}.empty?
      end

      def attributes_to_delink
        self.entity.declared_attributes.select {|attribute| attribute.reference? && !(attribute.abstract? || attribute.inherited?) && attribute.inverse.jpa.java_traversable? && attribute.inverse.jpa.traversable?}
      end

      def pre_verify
        entity.query(:FindAll, :standard_query => true)
        entity.query("FindBy#{entity.primary_key.name}")
        entity.query("GetBy#{entity.primary_key.name}")

        entity.attributes.select {|a| a.jpa? && a.reference? && !a.abstract?}.each do |a|
          query_name = "Find#{a.inverse.multiplicity == :many ? 'All' : ''}By#{a.name}"
          exists = entity.query_by_name?(query_name)
          entity.query(query_name) unless exists
          query = entity.dao.query_by_name(query_name)
          query.disable_facets_not_in(:jpa) unless exists
        end

        entity.queries.select {|query| query.jpa? && query.jpa.no_ql?}.each do |query|
          tmp_query_name = query.name.to_s
          jpql = ''
          query_text = nil
          query_text = $1 if tmp_query_name =~ /^[fF]indAllBy(.+)$/
          query_text = $1 if tmp_query_name =~ /^[fF]indBy(.+)$/
          query_text = $1 if tmp_query_name =~ /^[gG]etBy(.+)$/
          query_text = $1 if tmp_query_name =~ /^[dD]eleteBy(.+)$/
          query_text = $1 if tmp_query_name =~ /^[cC]ountBy(.+)$/
          next unless query_text

          lock_mode = nil
          if query_text =~ /(.+)With([A-Z].*)Lock$/
            query_text = $1
            lock_mode = Reality::Naming.underscore($2).to_sym
            unless Domgen::FacetManager::FacetDefinitions::JpaQueryFacet.valid_lock_modes.include?(lock_mode)
              Domgen.error("Invalid lock mode specified in query name #{query.qualified_name}")
            end
          end

          entity_prefix = 'O.'

          while true
            if query_text =~ /(.+)(And|Or)([A-Z].*)/
              parameter_name = $3
              operation = $2.upcase
              query_text = $1
              if entity.attribute_by_name?(parameter_name)
                a = entity.attribute_by_name(parameter_name)
                jpql_name = parameter_name
                field = "#{entity_prefix}#{Reality::Naming.camelize(jpql_name)}"
                comparison = "#{field} = :#{parameter_name}"
                jpql = "#{operation} #{comparison} #{jpql}"
              else
                # Handle parameters that are the primary keys of related entities
                found = false
                entity.attributes.select {|a| a.reference? && a.referencing_link_name == parameter_name}.each do |a|
                  field = "#{entity_prefix}#{Reality::Naming.camelize(a.name)}.#{Reality::Naming.camelize(a.referenced_entity.primary_key.name)}"
                  comparison = "#{field} = :#{parameter_name}"
                  jpql = "#{operation} #{comparison} #{jpql}"
                  found = true
                end
                unless found
                  jpql = nil
                  break
                end
              end
            else
              parameter_name = query_text
              if entity.attribute_by_name?(parameter_name)
                a = entity.attribute_by_name(parameter_name)
                jpql_name = parameter_name
                field = "#{entity_prefix}#{Reality::Naming.camelize(jpql_name)}"
                comparison = "#{field} = :#{parameter_name}"
                jpql = "#{comparison} #{jpql}"
              else
                # Handle parameters that are the primary keys of related entities
                found = false
                entity.attributes.select {|a| a.reference? && a.referencing_link_name == parameter_name}.each do |a|
                  field = "#{entity_prefix}#{Reality::Naming.camelize(a.name)}.#{Reality::Naming.camelize(a.referenced_entity.primary_key.name)}"
                  comparison = "#{field} = :#{parameter_name}"
                  jpql = "#{comparison} #{jpql}"
                  found = true
                end
                jpql = nil unless found
              end
              break
            end
          end
          if jpql
            query.jpa.jpql = jpql
            query.jpa.lock_mode = lock_mode if lock_mode
            query.standard_query = true
          else
            Domgen.error("Query #{query.qualified_name} is jpa enabled but defines no jpql or sql but is not a standard query.")
          end
        end
      end
    end

    facet.enhance(EnumerationSet) do
      def converter_name
        raise "converter_name invoked for #{enumeration.qualified_name} when no converter required" unless requires_converter?
        "#{enumeration.ee.qualified_name}$Converter"
      end

      def requires_converter?
        enumeration.textual_values? && enumeration.values.any? {|v| v.name != v.value}
      end
    end

    facet.enhance(Attribute) do
      include Domgen::JPA::BaseJpaField

      def default_fetch_type
        attribute.reference? ? :lazy : :eager
      end

      attr_writer :persistent

      def persistent?
        @persistent.nil? ? !attribute.abstract? : @persistent
      end

      def generator_name
        Domgen.error('generator_name invoked on non-sequence') if !sequence? && !table_sequence?
        "#{attribute.entity.data_module.name}#{attribute.entity.name}#{attribute.name}Generator"
      end

      include Domgen::Java::EEJavaCharacteristic

      attr_writer :converter

      def converter
        return nil if attribute.reference?
        return attribute.enumeration.jpa.converter_name if attribute.enumeration? && attribute.enumeration.jpa.requires_converter?
        return nil if attribute.enumeration?
        @converter || attribute.characteristic_type.jpa.converter(attribute.sql.dialect)
      end

      def field_name(modality = :default)
        Reality::Naming.camelize(name(modality))
      end

      def generated_value_strategy
        @generated_value_strategy || (attribute.sql.identity? ? :identity : attribute.sql.sequence? ? :sequence : :none)
      end

      def generated_value_strategy=(generated_value_strategy)
        raise "Invalid generated_value_strategy set on #{attribute.qualified_name}" unless self.class.valid_generated_value_strategies.include?(generated_value_strategy)
        @generated_value_strategy = generated_value_strategy
      end

      def identity?
        self.generated_value_strategy == :identity
      end

      def sequence?
        self.generated_value_strategy == :sequence
      end

      def table_sequence?
        self.generated_value_strategy == :table_sequence
      end

      def sequence_name=(sequence_name)
        Domgen.error("sequence_name= called on #{attribute.qualified_name} when not a sequence") if !sequence? && !table_sequence?
        @sequence_name = sequence_name
      end

      def sequence_name
        Domgen.error("sequence_name called on #{attribute.qualified_name} when not a sequence") if !sequence? && !table_sequence?
        @sequence_name || (sequence? && attribute.sql.sequence? ? attribute.sql.sequence_name : "#{attribute.entity.sql.table_name}#{attribute.name}Seq")
      end

      def self.valid_generated_value_strategies
        [:none, :identity, :sequence, :table_sequence]
      end

      protected

      def characteristic
        attribute
      end
    end

    facet.enhance(InverseElement) do
      include Domgen::JPA::BaseJpaField

      def default_fetch_type
        :lazy
      end

      attr_writer :orphan_removal

      def orphan_removal?
        !!@orphan_removal
      end

      def traversable=(traversable)
        Domgen.error("traversable #{traversable} is invalid") unless inverse.class.inverse_traversable_types.include?(traversable)
        @traversable = traversable
      end

      def traversable?
        @traversable.nil? ? (self.inverse.traversable? && self.inverse.attribute.referenced_entity.jpa?) : @traversable
      end

      def java_traversable=(java_traversable)
        @java_traversable = java_traversable
      end

      def java_traversable?
        @java_traversable.nil? ? traversable? : @java_traversable
      end
    end

    facet.enhance(Query) do
      def transaction_type
        @transaction_type || self.query.dao.jpa.transaction_type
      end

      def transaction_type=(transaction_type)
        raise "Attempted to set transaction_type to invalid #{transaction_type}" unless [:mandatory, :required, :requires_new].include?(transaction_type)
        @transaction_type = transaction_type
      end

      def perform_verify
        query_parameters = self.ql.nil? ? [] : self.ql.scan(/([^:]):([^:\W]+)/).collect { |s| s[1] }

        expected_parameters = query_parameters.uniq
        expected_parameters.each do |parameter_name|
          if !query.parameter_by_name?(parameter_name) && (query.dao.repository? || query.result_entity?)
            if query.entity.attribute_by_name?(parameter_name)
              attribute = query.entity.attribute_by_name(parameter_name)
              characteristic_options = {}
              characteristic_options[:enumeration] = attribute.enumeration if attribute.enumeration?
              characteristic_options[:referenced_entity] = attribute.referenced_entity if attribute.reference?
              p = query.parameter(attribute.name, attribute.attribute_type, characteristic_options)
              p.disable_facets_not_in(attribute.enabled_facets)
            else
              # Handle parameters that are the primary keys of related entities
              query.entity.attributes.select {|a| a.reference? && a.referencing_link_name == parameter_name}.each do |a|
                attribute = a.referenced_entity.primary_key
                characteristic_options = {}
                characteristic_options[:enumeration] = attribute.enumeration if attribute.enumeration?
                characteristic_options[:referenced_entity] = attribute.referenced_entity if attribute.reference?
                p = query.parameter(parameter_name, attribute.attribute_type, characteristic_options)
                p.disable_facets_not_in(attribute.enabled_facets)
              end
            end
          end
        end

        actual_parameters = query.parameters.collect {|p| p.name.to_s}
        if expected_parameters.sort != actual_parameters.sort
          Domgen.error("Actual parameters for query #{query.qualified_name} [ql=#{self.ql}] (#{actual_parameters.inspect}) do not match expected parameters #{expected_parameters.inspect}")
        end
      end

      def query_spec=(query_spec)
        Domgen.error("query_spec #{query_spec} is invalid") unless self.class.valid_query_specs.include?(query_spec)
        @query_spec = query_spec
      end

      def query_spec
        @query_spec || :criteria
      end

      def default_hints
        hints = {}
        if [:insert, :update].include?(self.query.query_type)
          provider = self.query.data_module.repository.jpa.provider
          if provider.nil? || provider == :eclipselink
            hints['eclipselink.query-type'] = 'org.eclipse.persistence.queries.DataModifyQuery'
          end
        end
        hints
      end

      attr_writer :hints

      def hints
        @hints ||= default_hints
      end

      def actual_hints
        hints
      end

      def self.valid_query_specs
        [:statement, :criteria]
      end

      attr_writer :native

      def native?
        @native.nil? ? false : @native
      end

      attr_accessor :limit

      attr_accessor :offset

      attr_accessor :order_by

      def self.valid_lock_modes
        [:optimistic, :optimistic_force_increment, :pessimistic_read, :pessimistic_write, :pessimistic_force_increment, :none]
      end

      def lock_mode=(lock_mode)
        raise "Attempted to set lock_mode to invalid #{lock_mode}" unless self.class.valid_lock_modes.include?(lock_mode)
        @lock_mode = lock_mode
      end

      attr_reader :lock_mode

      def standard_query?
        @standard_query.nil? ? query.standard_query? : !!@standard_query
      end

      attr_accessor :standard_query

      def ql
        @ql
      end

      def no_ql?
        @ql.nil?
      end

      def jpql=(ql)
        @native = false
        self.ql = ql
      end

      def jpql
        Domgen.error('Called jpql for native query') if self.native?
        @ql
      end

      def sql=(ql)
        @native = true
        self.ql = ql
      end

      def sql
        Domgen.error('Called sql for non-native query') unless self.native?
        @ql
      end

      def derive_table_name
        self.native? ? query.entity.sql.table_name : query.entity.jpa.jpql_name
      end

      def query_string
        order_by_clause = order_by ? " ORDER BY #{order_by}" : ''
        q = nil
        if self.query_spec == :statement
          q = self.ql
        elsif self.query_spec == :criteria
          criteria_clause = "#{no_ql? ? '' : 'WHERE '}#{ql}"
          if query.query_type == :select
            if query.name =~ /^[cC]ount(.*)$/
              if self.native?
                q = "SELECT COUNT(O.*) FROM #{derive_table_name} O #{criteria_clause}"
              else
                q = "SELECT COUNT(O) FROM #{derive_table_name} O #{criteria_clause}"
              end
            else
              if self.native?
                q = "SELECT O.* FROM #{derive_table_name} O #{criteria_clause}#{order_by_clause}"
              else
                q = "SELECT O FROM #{derive_table_name} O #{criteria_clause}#{order_by_clause}"
              end
            end
          elsif query.query_type == :update
            Domgen.error('The combination of query.query_type == :update and query_spec == :criteria is not supported')
          elsif query.query_type == :insert
            Domgen.error('The combination of query.query_type == :insert and query_spec == :criteria is not supported')
          elsif query.query_type == :delete
            if self.native?
              table_name = derive_table_name
              q = "DELETE FROM #{table_name} FROM #{table_name} O #{criteria_clause}"
            else
              q = "DELETE FROM #{derive_table_name} O #{criteria_clause}"
            end
          else
            Domgen.error("Unknown query type #{query.query_type}")
          end
        else
          Domgen.error("Unknown query spec #{self.query_spec}")
        end
        if self.native?
          q = q.gsub(/([^:]):([^:\W]+)/) do |parameter_name|
            index = nil
            query.parameters.each_with_index do |parameter, i|
              index = i + 1 if parameter_name[2, parameter_name.length].to_s == parameter.name.to_s
            end
            raise "Unable to locate parameter named #{parameter_name} in #{query.qualified_name}" unless index
            "#{parameter_name[0]}?#{index}"
          end
        end

        # For any line that ends in a single line sql server quote (i.e. " -- ...\n" )
        # try to convert it to multiline quote (i.e. " /* ... */ "). That way when we strip out
        # whitespace in subsequent lines we do not end up with invalid sql
        regex = /('[^']*'|"[^"]*")|--(.*)\n/
        q = q.gsub(regex) {|m| $1 || "/* #{$2} */"}

        q.gsub(/[\s]+/, ' ').strip
      end

      protected

      def ql=(ql)
        @ql = ql
        unless @query_spec
          statement = false
          statement = true if ql =~ /\sFROM\s/ix
          statement = true if ql =~ /^UPDATE\s/ix
          statement = true if ql =~ /\sUPDATE\s/ix
          self.query_spec = statement ? :statement : :criteria
        end
      end
    end

    facet.enhance(QueryParameter) do
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end
  end
end
