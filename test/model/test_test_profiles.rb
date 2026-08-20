require File.expand_path('../../helper', __FILE__)
require 'domgen'

class Domgen::TestTestProfiles < Domgen::TestCase
  def test_resolves_realm_specific_default_profiles_deterministically
    repository = new_repository do |r|
      core = r.data_module(:Core) do |m|
        m.supports_test_profiles :persistence, :server, :client
        m.persistence_runtime_targets '//server/core:implementation', '//server/core:dao', '//server/core:implementation'
        m.entity(:Resource) { |e| e.integer(:Id, :primary_key => true) }
      end
      r.data_module(:Feature) do |m|
        m.supports_test_profiles :persistence, :server, :client
        m.imports :Core
        m.entity(:Work) do |e|
          e.integer(:Id, :primary_key => true)
          e.reference core.entity_by_name(:Resource)
        end
      end
    end

    profile = repository.test_profile_by_name(:FeatureServer)
    assert_equal [:persistence, :server, :client], Domgen::TestProfiles::REALMS
    assert_equal ['Core', 'Feature'], profile.closures[:server]
    assert_equal ['Core', 'Feature'], profile.closures[:persistence]
    assert_equal [], profile.closures[:client]
    assert_equal repository.test_profile_registry.to_json, repository.test_profile_registry.to_json
    assert_equal repository.test_profile_registry.to_text, repository.test_profile_registry.to_text
    assert_equal repository.test_profile_registry.to_dot, repository.test_profile_registry.to_dot
    core = repository.data_module_by_name(:Core)
    assert_equal ['//server/core:dao', '//server/core:implementation'],
                 repository.test_profile_registry.module_config(core).persistence_runtime_targets
    core_manifest = repository.test_profile_registry.manifest['modules'].find { |data_module| data_module['name'] == 'Core' }
    assert_equal ['//server/core:dao', '//server/core:implementation'], core_manifest['persistence_runtime_targets']
    assert_raises(RuntimeError) { core.persistence_runtime_targets '//server/core:other' }
    assert_match(/Core.*Feature/m, repository.test_profile_registry.to_dot)
    assert_equal 6, repository.test_profiles.size
    assert_equal repository, profile.repository
    assert_equal ['Core', 'Feature'], profile.data_modules.collect { |data_module| data_module.name.to_s }
    assert_equal "#{repository.name}#{profile.name}", profile.physical_persistence_unit_name
    assert_raises(FrozenError) { profile.modules << 'Other' }
    assert_raises(FrozenError) { profile.modules.first << 'Other' }

    with_unrelated_module = new_repository do |r|
      core = r.data_module(:Core) do |m|
        m.supports_test_profiles :persistence, :server, :client
        m.entity(:Resource) { |e| e.integer(:Id, :primary_key => true) }
      end
      r.data_module(:Feature) do |m|
        m.supports_test_profiles :persistence, :server, :client
        m.imports :Core
        m.entity(:Work) do |e|
          e.integer(:Id, :primary_key => true)
          e.reference core.entity_by_name(:Resource)
        end
      end
      r.data_module(:Unrelated) { |m| m.supports_test_profiles :server }
    end
    assert_equal profile.fingerprint, with_unrelated_module.test_profile_by_name(:FeatureServer).fingerprint
  end

  def test_rejects_invalid_persistence_runtime_target
    error = assert_raises(RuntimeError) do
      new_repository do |r|
        r.data_module(:Core) do |m|
          m.supports_test_profiles :persistence
          m.persistence_runtime_targets '//server/core'
        end
      end
    end
    assert_equal "Persistence runtime target '//server/core' on Core must be an exact Bazel target label", error.message
  end

  def test_reuses_server_support_for_equivalent_profile_closures
    repository = new_repository do |r|
      r.data_module(:Core) { |m| m.supports_test_profiles :server }
      r.test_profile :FirstCoreServer,
                     :realm => :server,
                     :root => :Core,
                     :consumers => ['//test:FirstCoreServerTest']
      r.test_profile :SecondCoreServer,
                     :realm => :server,
                     :root => :Core,
                     :consumers => ['//test:SecondCoreServerTest']
    end

    support = repository.test_profile_by_name(:CoreServer)
    assert support.server_support_profile?
    assert_equal support, repository.test_profile_by_name(:FirstCoreServer).server_support_profile
    assert_equal support, repository.test_profile_by_name(:SecondCoreServer).server_support_profile
  end

  def test_assigns_generated_tests_to_profiles
    repository = new_repository do |r|
      r.enable_facets(:mssql, :jpa, :ejb)
      core = r.data_module(:Core) do |m|
        m.supports_test_profiles :persistence, :server
        m.entity(:Resource) { |e| e.integer(:Id, :primary_key => true) }
        m.service(:ResourceService) { |service| service.method(:Refresh) }
      end
      r.test_profile :ResourcePersistence,
                     :realm => :persistence,
                     :root => :Core
      r.test_profile :ResourceServer,
                     :realm => :server,
                     :root => :Core
      core.entity_by_name(:Resource).uses_test_profile(:ResourcePersistence)
      core.service_by_name(:ResourceService).uses_test_profile(:ResourceServer)
    end

    entity = repository.data_module_by_name(:Core).entity_by_name(:Resource)
    service = repository.data_module_by_name(:Core).service_by_name(:ResourceService)
    assert_equal "#{repository.jpa.server_util_test_package}.profile.AbstractResourcePersistenceTest",
                 entity.jpa.test_base_class
    assert_equal "#{repository.jpa.server_util_test_package}.profile.AbstractResourceServerTest",
                 service.ejb.qualified_base_service_test_name
    assert_equal [generated_test_label(entity.jpa.qualified_model_test_name)],
                 repository.test_profile_by_name(:ResourcePersistence).consumers
    assert_equal [generated_test_label(service.ejb.qualified_concrete_service_test_name)],
                 repository.test_profile_by_name(:ResourceServer).consumers
  end

  def test_collects_every_typed_reference_surface
    repository = new_repository do |r|
      r.data_module(:Target) do |m|
        m.supports_test_profiles :persistence, :server, :client
        m.enumeration(:State, :integer, :values => ['Open', 'Closed'])
        m.struct(:Info) { |s| s.text(:Name) }
        m.entity(:Resource) { |e| e.integer(:Id, :primary_key => true) }
        m.exception(:BaseFailure, :abstract => true) { |e| e.text(:Message) }
        m.exception(:TargetFailure)
      end
      r.data_module(:Source) do |m|
        m.supports_test_profiles :persistence, :server, :client
        m.imports :Target
        m.entity(:Work) do |e|
          e.integer(:Id, :primary_key => true)
          e.reference :'Target.Resource'
          e.enumeration(:State, :'Target.State')
          e.query(:FindByResource) { |query| query.reference :'Target.Resource' }
        end
        m.struct(:Envelope) do |s|
          s.struct(:Info, :'Target.Info')
          s.reference :'Target.Resource'
        end
        m.exception(:SpecificFailure, :extends => :'Target.BaseFailure') do |e|
          e.reference :'Target.Resource'
        end
        m.service(:SourceService) do |service|
          service.method(:Update) do |method|
            method.struct(:Info, :'Target.Info')
            method.returns :reference, :referenced_entity => :'Target.Resource'
            method.exception :'Target.TargetFailure'
          end
        end
        m.dao(:ExternalResourceRepository, :entity => :'Target.Resource')
        m.dao(:Search) do |dao|
          dao.query(:FindAll) do |query|
            query.reference :'Target.Resource'
            query.result_struct = :'Target.Info'
          end
        end
        m.message(:Changed) do |message|
          message.enumeration(:State, :'Target.State')
          message.struct(:Info, :'Target.Info')
        end
      end
    end

    kinds = repository.test_profile_registry.references.collect(&:kind).uniq.sort
    assert_equal [:dao_entity,
                  :entity_attribute,
                  :exception_inheritance,
                  :exception_parameter,
                  :message_parameter,
                  :query_parameter,
                  :query_result,
                  :service_exception,
                  :service_parameter,
                  :service_result,
                  :struct_field],
                 kinds
    query_reference = repository.test_profile_registry.references.find { |reference| reference.kind == :query_parameter }
    assert_equal 'Source.Search.FindAll.Resource', query_reference.path
    entity_query_reference = repository.test_profile_registry.references.find do |reference|
      reference.kind == :query_parameter && reference.path.start_with?('Source.Work.')
    end
    assert_equal 'Source.Work.FindByResource.Resource', entity_query_reference.path
  end

  def test_requires_direct_import_for_typed_reference
    error = assert_raises(RuntimeError) do
      new_repository do |r|
        core = r.data_module(:Core) do |m|
          m.supports_test_profiles :server
          m.struct(:Value) { |s| s.text(:Name) }
        end
        r.data_module(:Feature) do |m|
          m.supports_test_profiles :server
          m.service(:FeatureService) do |service|
            service.method(:Update) { |method| method.struct(:Value, :'Core.Value') }
          end
        end
      end
    end
    assert_equal "Typed reference 'Feature.FeatureService#Update.Value' from Feature to Core materializes in server without a direct intended import or exact temporary dependency debt allowance", error.message
  end

  def test_accepts_exact_model_debt_and_rejects_stale_debt
    repository = new_repository do |r|
      payments = r.data_module(:Payments) do |m|
        m.supports_test_profiles :server
        m.struct(:Activity) { |s| s.integer(:Id) }
      end
      r.data_module(:Timeline) do |m|
        m.supports_test_profiles :server
        m.temporary_dependency :Payments,
                               :path => 'Timeline.TimelineService#Register.Activity',
                               :via => :server,
                               :issue => '#123',
                               :rationale => 'Move the command to Timeline',
                               :kind => :model
        m.service(:TimelineService) do |service|
          service.method(:Register) { |method| method.struct(:Activity, :'Payments.Activity') }
        end
      end
    end
    assert_equal ['Payments', 'Timeline'], repository.test_profile_by_name(:TimelineServer).modules

    error = assert_raises(RuntimeError) do
      new_repository do |r|
        r.data_module(:Payments) { |m| m.supports_test_profiles :server }
        r.data_module(:Timeline) do |m|
          m.supports_test_profiles :server
          m.temporary_dependency :Payments,
                                 :path => 'Timeline.Missing.Reference',
                                 :via => :server,
                                 :issue => '#123',
                                 :rationale => 'Remove it',
                                 :kind => :model
        end
      end
    end
    assert_equal "Temporary model dependency debt 'Timeline.Missing.Reference' is stale; the exact reference Timeline -> Payments no longer exists", error.message
  end

  def test_rejects_stale_import_unknown_capability_and_shortest_cycle
    stale = assert_raises(RuntimeError) do
      new_repository do |r|
        r.data_module(:Core) { |m| m.supports_test_profiles :server }
        r.data_module(:Feature) do |m|
          m.supports_test_profiles :server
          m.imports :Core
        end
      end
    end
    assert_equal 'Intended import Feature -> Core is stale; it has no typed reference or scoped handwritten/raw dependency', stale.message

    unknown = assert_raises(RuntimeError) do
      new_repository do |r|
        r.data_module(:Core) { |m| m.supports_test_profiles :browser }
      end
    end
    assert_equal "Unknown capability 'browser' in Data module Core. Expected one of persistence, server, client, database", unknown.message

    cycle = assert_raises(RuntimeError) do
      new_repository do |r|
        r.data_module(:A) do |m|
          m.supports_test_profiles :server
          m.imports :B, :via => :server
        end
        r.data_module(:B) do |m|
          m.supports_test_profiles :server
          m.imports :A, :via => :server
        end
      end
    end
    assert_equal 'Intended import cycle detected: A -> B -> A', cycle.message
  end

  def test_resolves_named_additions_and_full_profile_consumers
    repository = new_repository do |r|
      r.data_module(:Core) { |m| m.supports_test_profiles :client }
      r.data_module(:Operations) do |m|
        m.supports_test_profiles :client
        m.imports :Core, :via => :client
      end
      r.data_module(:Movements) do |m|
        m.supports_test_profiles :client
        m.imports :Operations, :via => :client
      end
      r.test_profile :OperationsScenarioClient,
                     :realm => :client,
                     :root => :Operations,
                     :includes => [:Movements],
                     :consumers => ['//test:OperationsClientServiceImplTest']
      r.test_profile :FullRoseClient,
                     :realm => :client,
                     :full => true,
                     :consumers => ['//test:FullRoseClientTest']
      r.test_profile :CoreNodeClient,
                     :realm => :client,
                     :root => :Core,
                     :node_compatible => true,
                     :consumers => ['//test:CoreNodeTest']
    end

    scenario = repository.test_profile_by_name(:OperationsScenarioClient)
    assert_equal ['Core', 'Movements', 'Operations'], scenario.modules
    assert_equal ['//test:OperationsClientServiceImplTest'], scenario.consumers
    full = repository.test_profile_by_name(:FullRoseClient)
    assert full.full?
    assert_equal ['Core', 'Movements', 'Operations'], full.modules
    assert_equal 1, repository.test_profile_registry.manifest['profiles'].count { |profile| profile['full'] }
    node = repository.test_profile_by_name(:CoreNodeClient)
    assert node.node_compatible?
    assert repository.test_profile_registry.manifest['profiles'].find { |profile| profile['name'] == 'CoreNodeClient' }['node_compatible']
  end

  def test_resolves_server_profile_persistence_only_additions
    repository = new_repository do |r|
      r.data_module(:Feature) { |m| m.supports_test_profiles :persistence, :server }
      r.data_module(:LegacySql) { |m| m.supports_test_profiles :persistence }
      r.test_profile :FeatureLegacyServer,
                     :realm => :server,
                     :root => :Feature,
                     :persistence_includes => [:LegacySql],
                     :consumers => ['//test:FeatureLegacyTest']
    end

    profile = repository.test_profile_by_name(:FeatureLegacyServer)
    assert_equal ['Feature'], profile.closures[:server]
    assert_equal ['Feature', 'LegacySql'], profile.closures[:persistence]
  end

  def test_rejects_unused_inexact_and_duplicate_profile_consumers
    unused = assert_raises(RuntimeError) do
      new_repository do |r|
        r.data_module(:Core) { |m| m.supports_test_profiles :client }
        r.test_profile :CoreScenarioClient, :realm => :client, :root => :Core
      end
    end
    assert_equal "Test Profile 'CoreScenarioClient' must declare at least one exact consumer", unused.message

    inexact = assert_raises(RuntimeError) do
      new_repository do |r|
        r.data_module(:Core) { |m| m.supports_test_profiles :client }
        r.test_profile :CoreScenarioClient,
                       :realm => :client,
                       :root => :Core,
                       :consumers => ['CoreTest']
      end
    end
    assert_equal "Test Profile 'CoreScenarioClient' consumer 'CoreTest' must be an exact Bazel target label", inexact.message

    duplicate = assert_raises(RuntimeError) do
      new_repository do |r|
        r.data_module(:Core) { |m| m.supports_test_profiles :client }
        r.test_profile :CoreScenarioClient,
                       :realm => :client,
                       :root => :Core,
                       :consumers => ['//test:CoreTest']
        r.test_profile :OtherScenarioClient,
                       :realm => :client,
                       :root => :Core,
                       :consumers => ['//test:CoreTest']
      end
    end
    assert_equal "Test Profile consumer '//test:CoreTest' is declared by both 'CoreScenarioClient' and 'OtherScenarioClient'", duplicate.message
  end

  def test_scoped_handwritten_and_database_imports_normalize_capabilities
    repository = new_repository do |r|
      r.data_module(:Core) { |m| m.supports_test_profiles :database, :server }
      r.data_module(:Feature) do |m|
        m.supports_test_profiles :persistence, :server
        m.imports :Core, :via => [:database, :server]
      end
    end
    declaration = repository.test_profile_registry.manifest['imports'].first
    assert_equal ['persistence', 'server'], declaration['capabilities']
    assert_equal ['Core', 'Feature'], repository.test_profile_by_name(:FeaturePersistence).modules
  end

  def test_records_explicit_architecture_packages_and_exclusions
    repository = new_repository do |r|
      r.data_module(:Core) do |m|
        m.supports_test_profiles :server, :client
        m.architecture_packages :server => 'example.server.core', :client => 'example.client.core'
      end
      r.data_module(:SqlOnly) do |m|
        m.supports_test_profiles :persistence
        m.exclude_from_architecture 'SQL-only module'
      end
      r.enforce_test_profile_architecture_mapping!
    end

    modules = repository.test_profile_registry.manifest['modules'].collect { |data_module| [data_module['name'], data_module] }.to_h
    assert_equal({'client' => 'example.client.core', 'server' => 'example.server.core'}, modules.fetch('Core')['architecture_packages'])
    assert_nil modules.fetch('Core')['architecture_exclusion']
    assert_equal({}, modules.fetch('SqlOnly')['architecture_packages'])
    assert_equal 'SQL-only module', modules.fetch('SqlOnly')['architecture_exclusion']
  end

  def test_rejects_missing_and_duplicate_architecture_packages
    missing = assert_raises(RuntimeError) do
      new_repository do |r|
        r.data_module(:Core) { |m| m.supports_test_profiles :server }
        r.enforce_test_profile_architecture_mapping!
      end
    end
    assert_equal 'Data module Core must declare architecture packages or an explicit architecture exclusion', missing.message

    duplicate = assert_raises(RuntimeError) do
      new_repository do |r|
        r.data_module(:Core) do |m|
          m.supports_test_profiles :server
          m.architecture_packages :server => 'example.server.shared'
        end
        r.data_module(:Feature) do |m|
          m.supports_test_profiles :server
          m.architecture_packages :server => 'example.server.shared'
        end
      end
    end
    assert_equal 'Architecture package example.server.shared in server is mapped to both Core and Feature', duplicate.message
  end

  def test_validates_exact_code_debt_against_architecture_packages
    repository = new_repository do |r|
      r.data_module(:Core) do |m|
        m.supports_test_profiles :server
        m.architecture_packages :server => 'example.server.core'
      end
      r.data_module(:Feature) do |m|
        m.supports_test_profiles :server
        m.architecture_packages :server => 'example.server.feature'
        m.temporary_dependency :Core,
                               :path => 'example.server.feature.Worker -> example.server.core.Resource',
                               :via => :server,
                               :issue => '#123',
                               :rationale => 'Move the worker',
                               :kind => :server_code
      end
      r.enforce_test_profile_architecture_mapping!
    end
    assert_equal 'server_code', repository.test_profile_registry.manifest['debt'].first['kind']

    error = assert_raises(RuntimeError) do
      new_repository do |r|
        r.data_module(:Core) do |m|
          m.supports_test_profiles :server
          m.architecture_packages :server => 'example.server.core'
        end
        r.data_module(:Feature) do |m|
          m.supports_test_profiles :server
          m.architecture_packages :server => 'example.server.feature'
          m.temporary_dependency :Core,
                                 :path => 'example.server.other.Worker -> example.server.core.Resource',
                                 :via => :server,
                                 :issue => '#123',
                                 :rationale => 'Move the worker',
                                 :kind => :server_code
        end
      end
    end
    assert_equal "Temporary server_code dependency debt origin 'example.server.other.Worker' is outside the Feature architecture package example.server.feature", error.message
  end

  def test_client_code_debt_is_enforced_but_does_not_widen_projected_client_profiles
    repository = new_repository do |r|
      r.data_module(:Core) do |m|
        m.supports_test_profiles :client
        m.architecture_packages :client => 'example.client.core'
        m.struct(:Value) { |s| s.text(:Name) }
      end
      r.data_module(:Feature) do |m|
        m.supports_test_profiles :client
        m.architecture_packages :client => 'example.client.feature'
        m.imports :Core, :via => :client
        m.service(:FeatureService) do |service|
          service.method(:Read) { |method| method.struct(:Value, :'Core.Value') }
        end
      end
      r.data_module(:Legacy) do |m|
        m.supports_test_profiles :client
        m.architecture_packages :client => 'example.client.legacy'
        m.temporary_dependency :Feature,
                               :path => 'example.client.legacy.LegacyView -> example.client.feature.FeatureView',
                               :via => :client,
                               :issue => '#123',
                               :rationale => 'Move the legacy view',
                               :kind => :client_code
      end
      r.enforce_test_profile_architecture_mapping!
    end

    assert_equal ['Core', 'Feature'], repository.test_profile_by_name(:FeatureClient).modules
    assert_equal ['Legacy'], repository.test_profile_by_name(:LegacyClient).modules
    assert_equal 'client_code', repository.test_profile_registry.manifest['debt'].first['kind']
  end

  def test_selects_generated_corruption_checks_for_the_installed_module_set
    repository = new_sql_analysis_repository do |r|
      r.data_module(:Dependency) do |m|
        m.supports_test_profiles :persistence
        m.entity(:DependencyRow) { |e| e.integer(:Id, :primary_key => true) }
      end
      r.data_module(:Feature) do |m|
        m.supports_test_profiles :persistence
        m.imports :Dependency, :via => :persistence
        m.entity(:FeatureRow) do |e|
          e.integer(:Id, :primary_key => true)
          e.sql.validation(:SelfContained) do |validation|
            validation.negative_sql = 'SELECT I.Id FROM inserted I WHERE I.Id < 0'
          end
          e.sql.validation(:UsesDependency) do |validation|
            validation.negative_sql = 'SELECT I.Id FROM inserted I JOIN Dependency.tblDependencyRow D ON D.Id = I.Id'
          end
        end
      end
      r.data_module(:Unrelated) do |m|
        m.supports_test_profiles :persistence
        m.entity(:UnrelatedRow) do |e|
          e.integer(:Id, :primary_key => true)
          e.sql.validation(:Unrelated) do |validation|
            validation.negative_sql = 'SELECT I.Id FROM inserted I WHERE I.Id < 0'
          end
        end
      end
    end

    feature = repository.data_module_by_name(:Feature)
    dependency = repository.data_module_by_name(:Dependency)
    feature_only = repository.sql_analysis.corruption_registration_sql([feature])
    feature_profile = repository.sql_analysis.corruption_registration_sql([dependency, feature])
    feature_fragment = repository.sql_analysis.corruption_registration_sql_for_owner(feature)

    assert_includes feature_only, 'SelfContained'
    refute_includes feature_only, 'UsesDependency'
    refute_includes feature_profile, 'Unrelated'
    assert_includes feature_profile, 'UsesDependency'
    assert_includes feature_profile, "'Feature,Dependency'"
    assert_includes feature_fragment, 'SelfContained'
    assert_includes feature_fragment, 'UsesDependency'
    assert repository.sql_analysis.corruption_check_owner?(feature)
    refute repository.sql_analysis.corruption_check_owner?(dependency)
    assert_equal [feature], repository.test_profile_by_name(:FeaturePersistence).corruption_check_data_modules
  end

  def test_rejects_incomplete_handwritten_corruption_check_requirements
    directory = File.join(temp_dir, 'corruption-checks')
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, 'Feature.yml'), <<~YAML)
      1:
        RequiredModules:
          - Feature
        Category: Example
        Description: Missing declared dependency
        Sql: SELECT F.Id FROM Feature.tblFeatureRow F JOIN Dependency.tblDependencyRow D ON D.Id = F.Id
    YAML
    repository = new_sql_analysis_repository do |r|
      r.sql_analysis.handwritten_corruption_checks_directory = directory
      r.data_module(:Dependency) do |m|
        m.supports_test_profiles :persistence
        m.entity(:DependencyRow) { |e| e.integer(:Id, :primary_key => true) }
      end
      r.data_module(:Feature) do |m|
        m.supports_test_profiles :persistence
        m.entity(:FeatureRow) { |e| e.integer(:Id, :primary_key => true) }
      end
    end

    error = assert_raises(RuntimeError) { repository.sql_analysis.handwritten_corruption_checks }
    assert_equal 'Handwritten corruption check 1 declares Feature but SQL touches Dependency, Feature', error.message
  end

  private

  def generated_test_label(qualified_name)
    package_name, _, class_name = qualified_name.rpartition('.')
    "//server/src/test/java/#{package_name.tr('.', '/')}:#{class_name}"
  end

  def new_repository(&block)
    @repository_index ||= 0
    @repository_index += 1
    Domgen::Repository.new("TestProfiles#{object_id}#{@repository_index}".to_sym, nil, {}, &block)
  end

  def new_sql_analysis_repository(&block)
    new_repository do |repository|
      repository.enable_facets(:sql, :mssql, :sql_analysis)
      block.call(repository)
    end
  end
end
