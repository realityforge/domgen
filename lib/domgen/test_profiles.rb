#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'digest/sha2'
require 'json'

module Domgen
  module TestProfiles
    REALMS = [:persistence, :server, :client].freeze
    CAPABILITY_ALIASES = {:database => :persistence}.freeze
    DEBT_KINDS = [:model, :server_code, :client_code, :database].freeze

    class ImportDeclaration
      attr_reader :source
      attr_reader :target
      attr_reader :explicit_capabilities

      def initialize(source, target)
        @source = source
        @target = target
        @explicit_capabilities = []
      end

      def add_capabilities(capabilities)
        @explicit_capabilities = (@explicit_capabilities + capabilities).uniq.sort.freeze
      end
    end

    class DebtDeclaration
      attr_reader :source
      attr_reader :target
      attr_reader :path
      attr_reader :capabilities
      attr_reader :issue
      attr_reader :rationale
      attr_reader :kind

      def initialize(source, target, path, capabilities, issue, rationale, kind)
        @source = source
        @target = target
        @path = path
        @capabilities = capabilities.freeze
        @issue = issue
        @rationale = rationale
        @kind = kind
        freeze
      end
    end

    class ProfileDefinition
      attr_reader :name
      attr_reader :realm
      attr_reader :root
      attr_reader :includes
      attr_reader :persistence_includes
      attr_reader :consumers
      attr_reader :node_compatible

      def initialize(name, realm, root, includes, persistence_includes, consumers, full, node_compatible)
        @name = name
        @realm = realm
        @root = root
        @includes = includes.freeze
        @persistence_includes = persistence_includes.freeze
        @consumers = consumers.freeze
        @full = full
        @node_compatible = node_compatible
        freeze
      end

      def full?
        @full
      end
    end

    class TypedReference
      attr_reader :source
      attr_reader :target
      attr_reader :path
      attr_reader :capabilities
      attr_reader :kind

      def initialize(source, target, path, capabilities, kind)
        @source = source
        @target = target
        @path = path
        @capabilities = capabilities.freeze
        @kind = kind
        freeze
      end

      def to_h
        {
          'path' => path,
          'source' => source,
          'target' => target,
          'capabilities' => capabilities.collect(&:to_s),
          'kind' => kind.to_s
        }
      end
    end

    class ResolvedProfile
      attr_reader :repository
      attr_reader :name
      attr_reader :realm
      attr_reader :root
      attr_reader :closures
      attr_reader :consumers
      attr_reader :fingerprint
      attr_reader :node_compatible

      def initialize(repository, name, realm, root, closures, consumers, full, node_compatible, fingerprint)
        @repository = repository
        @name = name.to_s.dup.freeze
        @realm = realm
        @root = root && root.to_s.dup.freeze
        @closures = REALMS.each_with_object({}) do |candidate, result|
          result[candidate] = closures[candidate].collect { |module_name| module_name.to_s.dup.freeze }.freeze
        end.freeze
        @consumers = consumers.collect { |consumer| consumer.to_s.dup.freeze }.freeze
        @full = full
        @node_compatible = node_compatible
        @fingerprint = fingerprint.dup.freeze
        freeze
      end

      def full?
        @full
      end

      def modules
        closures[realm]
      end

      def data_modules(candidate_realm = realm)
        selected = closures[candidate_realm]
        repository.data_modules.select { |data_module| selected.include?(data_module.name.to_s) }
      end

      def persistence?
        realm == :persistence
      end

      def server?
        realm == :server
      end

      def client?
        realm == :client
      end

      def node_compatible?
        @node_compatible
      end

      def database_backed?
        persistence? || (server? && data_modules(:persistence).any?(&:sql?))
      end

      def action_data_modules
        return [] unless data_modules(:persistence).any? { |data_module| :Action == data_module.name }
        data_modules(:server).select { |data_module| data_module.services.any?(&:action?) }
      end

      def corruption_check_data_modules
        data_modules(:persistence).select do |data_module|
          repository.sql_analysis.corruption_check_owner?(data_module)
        end
      end

      def database_post_create_dirs
        action_modules = action_data_modules
        check_modules = corruption_check_data_modules
        module_directories = repository.data_modules.flat_map do |data_module|
          path = "test-profile-modules/#{Domgen::Naming.underscore(data_module.name)}"
          directories = []
          directories << "#{path}/post" if action_modules.include?(data_module)
          directories << "#{path}/integrity" if check_modules.include?(data_module)
          directories
        end
        ["test-profiles/#{path_name}/setup"] + module_directories +
          ["test-profiles/#{path_name}/post", "test-profiles/#{path_name}/verify"]
      end

      def server_support_profile
        repository.test_profile_registry.server_support_profile(self)
      end

      def server_support_profile?
        equal?(server_support_profile)
      end

      def physical_persistence_unit_name
        full? ? repository.name.to_s : "#{repository.name}#{name}"
      end

      def java_name
        name.gsub(/[^A-Za-z0-9_]/, '')
      end

      def path_name
        Domgen::Naming.underscore(name)
      end

      def to_h
        profile = {
          'name' => name,
          'realm' => realm.to_s,
          'root' => root,
          'full' => full?,
          'closures' => REALMS.each_with_object({}) do |candidate, result|
            result[candidate.to_s] = closures[candidate]
          end,
          'consumers' => consumers,
          'fingerprint' => fingerprint
        }
        profile['node_compatible'] = node_compatible? if client?
        profile
      end

    end

    class ModuleConfig
      attr_reader :data_module
      attr_reader :supported_realms
      attr_reader :imports
      attr_reader :debts
      attr_reader :architecture_packages
      attr_reader :persistence_runtime_targets
      attr_reader :architecture_exclusion

      def initialize(data_module)
        @data_module = data_module
        @supported_realms = []
        @imports = {}
        @debts = []
        @architecture_packages = {}
        @persistence_runtime_targets = [].freeze
        @architecture_exclusion = nil
      end

      def support(realms)
        @supported_realms = (@supported_realms + realms).uniq.sort.freeze
      end

      def import(target, capabilities)
        declaration = (@imports[target] ||= ImportDeclaration.new(data_module.name.to_s, target))
        declaration.add_capabilities(capabilities)
        declaration
      end

      def add_debt(debt)
        Domgen.error("Temporary dependency debt path '#{debt.path}' is declared more than once on #{data_module.name}") if
          @debts.any? { |candidate| candidate.path == debt.path }
        @debts << debt
      end

      def map_architecture_packages(packages)
        Domgen.error("Data module #{data_module.name} can not have architecture packages and an architecture exclusion") if @architecture_exclusion
        packages.each do |realm, package_name|
          Domgen.error("Architecture package for #{data_module.name} in #{realm} is already declared") if @architecture_packages[realm]
          @architecture_packages[realm] = package_name
        end
      end

      def add_persistence_runtime_targets(targets)
        @persistence_runtime_targets = (@persistence_runtime_targets + targets).uniq.sort.freeze
      end

      def exclude_from_architecture(reason)
        Domgen.error("Data module #{data_module.name} can not have an architecture exclusion and architecture packages") unless @architecture_packages.empty?
        Domgen.error("Architecture exclusion for #{data_module.name} is already declared") if @architecture_exclusion
        @architecture_exclusion = reason
      end
    end

    class ReferenceCollector
      def initialize(registry)
        @registry = registry
        @references = []
      end

      def collect
        @registry.repository.data_modules.each do |data_module|
          collect_entities(data_module)
          collect_structs(data_module)
          collect_exceptions(data_module)
          collect_services(data_module)
          collect_daos(data_module)
          collect_messages(data_module)
        end
        @references.sort_by { |reference| [reference.path, reference.target, reference.kind.to_s] }.freeze
      end

      private

      def collect_entities(data_module)
        data_module.entities.each do |entity|
          if entity.extends
            target = data_module.entity_by_name(entity.extends)
            add_reference(data_module, target.data_module, "#{entity.qualified_name}.extends", [:persistence, :server, :client], :entity_inheritance)
          end
          entity.declared_attributes.each do |attribute|
            collect_characteristic(data_module, attribute, attribute.qualified_name, [:persistence, :server, :client], :entity_attribute)
          end
        end
      end

      def collect_structs(data_module)
        data_module.structs.each do |struct|
          struct.fields.each do |field|
            collect_characteristic(data_module, field, field.qualified_name, [:server, :client], :struct_field)
          end
        end
      end

      def collect_exceptions(data_module)
        data_module.exceptions.each do |exception|
          if exception.extends
            target = data_module.exception_by_name(exception.extends)
            add_reference(data_module, target.data_module, "#{clean_path(exception.qualified_name)}.extends", [:server, :client], :exception_inheritance)
          end
          exception.declared_parameters.each do |parameter|
            collect_characteristic(data_module, parameter, parameter.qualified_name, [:server, :client], :exception_parameter)
          end
        end
      end

      def collect_services(data_module)
        data_module.services.each do |service|
          service.methods.each do |method|
            method.parameters.each do |parameter|
              collect_characteristic(data_module, parameter, parameter.qualified_name, [:server, :client], :service_parameter)
            end
            if method.result
              collect_characteristic(data_module, method.result, method.result.qualified_name, [:server, :client], :service_result)
            end
            method.exceptions.each do |exception|
              add_reference(data_module,
                            exception.data_module,
                            "#{method.qualified_name}.throws.#{clean_path(exception.qualified_name)}",
                            [:server, :client],
                            :service_exception)
            end
          end
        end
      end

      def collect_daos(data_module)
        data_module.daos.each do |dao|
          if dao.repository?
            add_reference(data_module, dao.entity.data_module, "#{dao.qualified_name}.Entity", [:persistence, :server], :dao_entity)
          end
          dao.queries.each do |query|
            query_path = dao.repository? ? "#{dao.entity.qualified_name}.#{query.name}" : query.qualified_name
            query.parameters.each do |parameter|
              collect_characteristic(data_module,
                                     parameter,
                                     "#{query_path}.#{parameter.name}",
                                     [:persistence, :server],
                                     :query_parameter)
            end
            if query.result_entity?
              add_reference(data_module, query.entity.data_module, "#{query_path}.Result", [:persistence, :server], :query_result)
            elsif query.result_struct?
              add_reference(data_module, query.struct.data_module, "#{query_path}.Result", [:persistence, :server], :query_result)
            end
          end
        end
      end

      def collect_messages(data_module)
        data_module.messages.each do |message|
          message.parameters.each do |parameter|
            collect_characteristic(data_module, parameter, parameter.qualified_name, [:server, :client], :message_parameter)
          end
        end
      end

      def collect_characteristic(source, characteristic, path, capabilities, kind)
        target = if characteristic.reference?
                   characteristic.referenced_entity.data_module
                 elsif characteristic.struct?
                   characteristic.referenced_struct.data_module
                 elsif characteristic.enumeration?
                   characteristic.enumeration.data_module
                 end
        add_reference(source, target, path, capabilities, kind) if target
      end

      def add_reference(source, target, path, candidate_capabilities, kind)
        return if source.name.to_s == target.name.to_s
        capabilities = candidate_capabilities.select do |capability|
          @registry.module_config(source).supported_realms.include?(capability)
        end
        return if capabilities.empty?
        @references << TypedReference.new(source.name.to_s,
                                          target.name.to_s,
                                          clean_path(path),
                                          capabilities.sort,
                                          kind)
      end

      def clean_path(path)
        path.to_s.gsub('$', '.').gsub('!', '')
      end
    end

    class Registry
      attr_reader :repository

      def initialize(repository)
        @repository = repository
        @module_configs = {}
        @profile_definitions = {}
        @generated_test_profiles = {}
        @configured = false
        @compiled = false
        @enforce_architecture_mapping = false
      end

      def configured?
        @configured
      end

      def module_config(data_module)
        @module_configs[data_module.name.to_s] ||= ModuleConfig.new(data_module)
      end

      def support(data_module, capabilities)
        ensure_mutable!
        @configured = true
        module_config(data_module).support(normalize_capabilities(capabilities, "Data module #{data_module.name}"))
      end

      def import(data_module, targets, capabilities)
        ensure_mutable!
        @configured = true
        normalized = normalize_capabilities(capabilities, "Import from #{data_module.name}")
        targets.each do |target|
          target_name = target.to_s
          Domgen.error("Data module #{data_module.name} can not import itself") if target_name == data_module.name.to_s
          module_config(data_module).import(target_name, normalized)
        end
      end

      def debt(data_module, target, options)
        ensure_mutable!
        @configured = true
        options = options.dup
        path = required_option(options, :path, "Temporary dependency debt on #{data_module.name}").to_s
        capabilities = normalize_capabilities(required_option(options, :via, "Temporary dependency debt '#{path}'"),
                                                "Temporary dependency debt '#{path}'")
        issue = required_option(options, :issue, "Temporary dependency debt '#{path}'").to_s
        rationale = required_option(options, :rationale, "Temporary dependency debt '#{path}'").to_s
        kind = (options.delete(:kind) || :model).to_sym
        Domgen.error("Unknown temporary dependency debt kind '#{kind}' on '#{path}'. Expected one of #{DEBT_KINDS.join(', ')}") unless DEBT_KINDS.include?(kind)
        Domgen.error("Temporary dependency debt '#{path}' must declare at least one capability") if capabilities.empty?
        Domgen.error("Temporary dependency debt '#{path}' must declare a non-empty issue") if issue.empty?
        Domgen.error("Temporary dependency debt '#{path}' must declare a non-empty rationale") if rationale.empty?
        Domgen.error("Unknown temporary dependency debt options on '#{path}': #{options.keys.sort.join(', ')}") unless options.empty?
        validate_debt_kind(path, kind, capabilities)
        declaration = DebtDeclaration.new(data_module.name.to_s,
                                          target.to_s,
                                          path,
                                          capabilities,
                                          issue,
                                          rationale,
                                          kind)
        module_config(data_module).add_debt(declaration)
        declaration
      end

      def architecture_packages(data_module, packages)
        ensure_mutable!
        @configured = true
        normalized = packages.each_with_object({}) do |(realm, package_name), result|
          capability = normalize_capabilities([realm], "Architecture package on #{data_module.name}").first
          value = package_name.to_s
          Domgen.error("Architecture package on #{data_module.name} in #{capability} must not be empty") if value.empty?
          result[capability] = value
        end
        Domgen.error("Data module #{data_module.name} must map at least one architecture package") if normalized.empty?
        module_config(data_module).map_architecture_packages(normalized)
      end

      def architecture_exclusion(data_module, reason)
        ensure_mutable!
        @configured = true
        value = reason.to_s
        Domgen.error("Architecture exclusion for #{data_module.name} must not be empty") if value.empty?
        module_config(data_module).exclude_from_architecture(value)
      end

      def persistence_runtime_targets(data_module, targets)
        ensure_mutable!
        @configured = true
        normalized = targets.flatten.collect(&:to_s)
        Domgen.error("Persistence runtime target on #{data_module.name} must not be empty") if normalized.any?(&:empty?)
        normalized.each do |target|
          Domgen.error("Persistence runtime target '#{target}' on #{data_module.name} must be an exact Bazel target label") unless
            target.match?(%r{\A//[^:]+:[^:]+\z})
        end
        module_config(data_module).add_persistence_runtime_targets(normalized)
      end

      def enforce_architecture_mapping!
        ensure_mutable!
        @configured = true
        @enforce_architecture_mapping = true
      end

      def profile(name, options)
        ensure_mutable!
        @configured = true
        options = options.dup
        profile_name = name.to_s
        Domgen.error("Test Profile '#{profile_name}' is already declared") if @profile_definitions[profile_name]
        realm = normalize_capabilities([required_option(options, :realm, "Test Profile '#{profile_name}'")],
                                       "Test Profile '#{profile_name}'").first
        full = !!options.delete(:full)
        root = options.delete(:root)
        includes = Array(options.delete(:includes)).collect(&:to_s).uniq.sort
        persistence_includes = Array(options.delete(:persistence_includes)).collect(&:to_s).uniq.sort
        consumers = Array(options.delete(:consumers)).collect(&:to_s).uniq.sort
        node_compatible = !!options.delete(:node_compatible)
        Domgen.error("Unknown options on Test Profile '#{profile_name}': #{options.keys.sort.join(', ')}") unless options.empty?
        expected_suffix = realm.to_s.capitalize
        Domgen.error("Test Profile '#{profile_name}' must end with its realm name '#{expected_suffix}'") unless profile_name.end_with?(expected_suffix)
        Domgen.error("Full Test Profile '#{profile_name}' must not declare a root") if full && root
        Domgen.error("Full Test Profile '#{profile_name}' must not declare persistence includes") if full && !persistence_includes.empty?
        Domgen.error("Full Test Profile '#{profile_name}' must be named 'FullRose#{expected_suffix}'") if full && profile_name != "FullRose#{expected_suffix}"
        Domgen.error("Test Profile '#{profile_name}' must declare a root") if !full && !root
        Domgen.error("Only client Test Profiles may be node-compatible") if node_compatible && realm != :client
        @profile_definitions[profile_name] = ProfileDefinition.new(profile_name,
                                                                   realm,
                                                                   root && root.to_s,
                                                                   includes,
                                                                   persistence_includes,
                                                                   consumers,
                                                                   full,
                                                                   node_compatible)
      end

      def use_profile_for_generated_test(realm, profile_name, qualified_test_name)
        ensure_mutable!
        @configured = true
        profile_name = profile_name.to_s
        consumer = generated_test_consumer(qualified_test_name)
        existing = @generated_test_profiles[consumer]
        Domgen.error("Generated test '#{consumer}' already uses Test Profile '#{existing[:profile]}'") if existing
        @generated_test_profiles[consumer] = {
          :profile => profile_name,
          :realm => realm
        }
        "#{repository.jpa.server_util_test_package}.profile.Abstract#{profile_name}Test"
      end

      def compile!
        return self if @compiled
        validate_declarations
        @references = ReferenceCollector.new(self).collect
        @import_capabilities = Hash.new { |hash, key| hash[key] = [] }
        validate_references
        validate_debts
        validate_imports
        validate_cycles
        @edges = build_edges
        @profiles = resolve_profiles
        @manifest = deep_freeze(build_manifest)
        freeze_declarations
        @compiled = true
        self
      end

      def profiles
        compile!
        @profiles
      end

      def profile_by_name(name)
        profile = profiles[name.to_s]
        Domgen.error("Unable to locate Test Profile '#{name}'") unless profile
        profile
      end

      def server_support_profile(profile)
        Domgen.error("Test Profile #{profile.name} is not a server profile") unless profile.server?
        signature = server_support_signature(profile)
        profiles.values.select(&:server?).select { |candidate| server_support_signature(candidate) == signature }.min_by(&:name)
      end

      def references
        compile!
        @references
      end

      def manifest
        compile!
        @manifest
      end

      def to_json(*_args)
        JSON.pretty_generate(manifest)
      end

      def to_text
        compile!
        lines = ["repository #{repository.name}", 'modules:']
        manifest['modules'].each do |data_module|
          lines << "  #{data_module['name']} [#{data_module['realms'].join(',')}]"
        end
        lines << 'imports:'
        manifest['imports'].each do |import|
          lines << "  #{import['source']} -> #{import['target']} [#{import['capabilities'].join(',')}]"
        end
        lines << 'debt:'
        manifest['debt'].each do |debt|
          lines << "  #{debt['source']} -> #{debt['target']} [#{debt['capabilities'].join(',')}] #{debt['path']}"
        end
        lines << 'profiles:'
        manifest['profiles'].each do |profile|
          closures = profile['closures'].collect { |realm, modules| "#{realm}=#{modules.join(',')}" }.join(' ')
          lines << "  #{profile['name']} [#{profile['realm']}] #{closures}"
        end
        lines.join("\n") + "\n"
      end

      def to_dot
        compile!
        lines = ["digraph \"#{repository.name}TestProfiles\" {"]
        module_names.each { |name| lines << "  \"#{name}\";" }
        manifest['imports'].each do |import|
          lines << "  \"#{import['source']}\" -> \"#{import['target']}\" [label=\"#{import['capabilities'].join(',')}\"];"
        end
        manifest['debt'].each do |debt|
          lines << "  \"#{debt['source']}\" -> \"#{debt['target']}\" [color=red,style=dashed,label=\"#{debt['capabilities'].join(',')}\"];"
        end
        lines << '}'
        lines.join("\n") + "\n"
      end

      private

      def ensure_mutable!
        Domgen.error("Test Profile declarations on repository #{repository.name} are immutable after compilation") if @compiled
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, child| deep_freeze(key); deep_freeze(child) }
        when Array
          value.each { |child| deep_freeze(child) }
        end
        value.freeze
      end

      def freeze_declarations
        @module_configs.each_value do |config|
          config.imports.each_value(&:freeze)
          config.imports.freeze
          config.debts.freeze
          config.architecture_packages.freeze
          config.freeze
        end
        @module_configs.freeze
        @profile_definitions.freeze
        @generated_test_profiles.each_value(&:freeze)
        @generated_test_profiles.freeze
      end

      def required_option(options, key, context)
        value = options.delete(key)
        Domgen.error("#{context} must declare '#{key}'") if value.nil?
        value
      end

      def normalize_capabilities(capabilities, context)
        Array(capabilities).collect do |capability|
          key = capability.to_sym
          normalized = CAPABILITY_ALIASES[key] || key
          Domgen.error("Unknown capability '#{capability}' in #{context}. Expected one of persistence, server, client, database") unless REALMS.include?(normalized)
          normalized
        end.uniq.sort
      end

      def validate_debt_kind(path, kind, capabilities)
        expected = case kind
                   when :server_code then [:server]
                   when :client_code then [:client]
                   when :database then [:persistence]
                   else capabilities
                   end
        Domgen.error("Temporary dependency debt '#{path}' of kind #{kind} must use #{expected.join(', ')}") unless capabilities == expected
      end

      def validate_declarations
        validate_architecture_mappings
        @module_configs.each_value do |config|
          if !config.persistence_runtime_targets.empty? && !config.supported_realms.include?(:persistence)
            Domgen.error("Persistence runtime targets on #{config.data_module.name} require the persistence Test Profile Realm")
          end
          config.imports.each_value do |declaration|
            validate_target(declaration.source, declaration.target, 'Intended import')
            declaration.explicit_capabilities.each do |capability|
              validate_supported_capability(declaration.source, capability, "Intended import #{declaration.source} -> #{declaration.target}")
              validate_supported_capability(declaration.target, capability, "Intended import #{declaration.source} -> #{declaration.target}")
            end
          end
          config.debts.each do |debt|
            validate_target(debt.source, debt.target, "Temporary dependency debt '#{debt.path}'")
            Domgen.error("Temporary dependency debt '#{debt.path}' is redundant with intended import #{debt.source} -> #{debt.target}") if import_for(debt.source, debt.target)
            debt.capabilities.each do |capability|
              validate_supported_capability(debt.source, capability, "Temporary dependency debt '#{debt.path}'")
              validate_supported_capability(debt.target, capability, "Temporary dependency debt '#{debt.path}'")
            end
          end
        end
        @generated_test_profiles.each do |consumer, assignment|
          profile = @profile_definitions[assignment[:profile]]
          Domgen.error("Generated test '#{consumer}' uses unknown Test Profile '#{assignment[:profile]}'") unless profile
          Domgen.error("Generated test '#{consumer}' uses #{assignment[:realm]}, but Test Profile '#{profile.name}' is #{profile.realm}") unless
            assignment[:realm] == profile.realm
        end
        @profile_definitions.each_value do |profile|
          consumers = profile_consumers(profile)
          Domgen.error("Test Profile '#{profile.name}' must declare at least one exact consumer") if consumers.empty?
          consumers.each do |consumer|
            Domgen.error("Test Profile '#{profile.name}' consumer '#{consumer}' must be an exact Bazel target label") unless
              consumer.match?(%r{\A//[^:]+:[^:]+\z})
          end
          ([profile.root] + profile.includes).compact.each do |module_name|
            validate_module(module_name, "Test Profile '#{profile.name}'")
            validate_supported_capability(module_name, profile.realm, "Test Profile '#{profile.name}'")
          end
          Domgen.error("Only server Test Profiles may declare persistence includes") if
            !profile.persistence_includes.empty? && profile.realm != :server
          profile.persistence_includes.each do |module_name|
            validate_module(module_name, "Test Profile '#{profile.name}' persistence include")
            validate_supported_capability(module_name,
                                          :persistence,
                                          "Test Profile '#{profile.name}' persistence include")
          end
        end
        consumers = {}
        @profile_definitions.each_value do |profile|
          profile_consumers(profile).each do |consumer|
            owner = consumers[consumer]
            Domgen.error("Test Profile consumer '#{consumer}' is declared by both '#{owner}' and '#{profile.name}'") if owner
            consumers[consumer] = profile.name
          end
        end
      end

      def validate_architecture_mappings
        package_owners = {}
        module_names.each do |name|
          config = module_config_by_name(name)
          if @enforce_architecture_mapping && config.architecture_packages.empty? && !config.architecture_exclusion
            Domgen.error("Data module #{name} must declare architecture packages or an explicit architecture exclusion")
          end
          config.architecture_packages.each do |realm, package_name|
            validate_supported_capability(name, realm, "Architecture package on #{name}")
            owner = package_owners[[realm, package_name]]
            Domgen.error("Architecture package #{package_name} in #{realm} is mapped to both #{owner} and #{name}") if owner
            package_owners[[realm, package_name]] = name
          end
        end
      end

      def validate_target(source, target, context)
        validate_module(source, context)
        validate_module(target, context)
        Domgen.error("#{context} can not target its source module #{source}") if source == target
      end

      def validate_module(name, context)
        Domgen.error("#{context} references unknown data module '#{name}'") unless repository.data_module_by_name?(name)
      end

      def validate_supported_capability(module_name, capability, context)
        config = @module_configs[module_name]
        unless config && config.supported_realms.include?(capability)
          Domgen.error("#{context} uses #{capability}, but data module #{module_name} does not support that Test Profile Realm")
        end
      end

      def validate_references
        @references.each do |reference|
          reference.capabilities.each do |capability|
            validate_supported_capability(reference.target,
                                          capability,
                                          "Typed reference '#{reference.path}' from #{reference.source} to #{reference.target}")
            intended_import = import_for(reference.source, reference.target)
            debt = model_debt_for(reference.path)
            if intended_import
              @import_capabilities[[reference.source, reference.target]] |= [capability]
            elsif debt && debt.source == reference.source && debt.target == reference.target && debt.capabilities.include?(capability)
              next
            else
              Domgen.error("Typed reference '#{reference.path}' from #{reference.source} to #{reference.target} materializes in #{capability} without a direct intended import or exact temporary dependency debt allowance")
            end
          end
        end
      end

      def validate_debts
        all_debts.each do |debt|
          if debt.kind == :model
            reference = @references.find do |candidate|
              candidate.path == debt.path && candidate.source == debt.source && candidate.target == debt.target
            end
            Domgen.error("Temporary model dependency debt '#{debt.path}' is stale; the exact reference #{debt.source} -> #{debt.target} no longer exists") unless reference
            extra = debt.capabilities - reference.capabilities
            Domgen.error("Temporary model dependency debt '#{debt.path}' declares capabilities not materialized by the reference: #{extra.join(', ')}") unless extra.empty?
          elsif [:server_code, :client_code].include?(debt.kind)
            validate_code_debt_path(debt)
          end
        end
      end

      def validate_code_debt_path(debt)
        origin, target, extra = debt.path.split(' -> ', 3)
        Domgen.error("Temporary #{debt.kind} dependency debt '#{debt.path}' must identify one exact 'origin -> target' class pair") if !origin || !target || extra
        realm = debt.kind == :server_code ? :server : :client
        source_package = module_config_by_name(debt.source).architecture_packages[realm]
        target_package = module_config_by_name(debt.target).architecture_packages[realm]
        Domgen.error("Temporary #{debt.kind} dependency debt '#{debt.path}' requires architecture packages for #{debt.source} and #{debt.target}") unless source_package && target_package
        Domgen.error("Temporary #{debt.kind} dependency debt origin '#{origin}' is outside the #{debt.source} architecture package #{source_package}") unless origin.start_with?("#{source_package}.")
        Domgen.error("Temporary #{debt.kind} dependency debt target '#{target}' is outside the #{debt.target} architecture package #{target_package}") unless target.start_with?("#{target_package}.")
      end

      def validate_imports
        all_imports.each do |declaration|
          capabilities = (declaration.explicit_capabilities + @import_capabilities[[declaration.source, declaration.target]]).uniq.sort
          Domgen.error("Intended import #{declaration.source} -> #{declaration.target} is stale; it has no typed reference or scoped handwritten/raw dependency") if capabilities.empty?
          @import_capabilities[[declaration.source, declaration.target]] = capabilities.freeze
        end
      end

      def validate_cycles
        adjacency = Hash.new { |hash, key| hash[key] = [] }
        all_imports.each { |declaration| adjacency[declaration.source] << declaration.target }
        adjacency.each_value(&:sort!)
        shortest = nil
        adjacency.keys.sort.each do |source|
          adjacency[source].each do |target|
            path = shortest_path(adjacency, target, source)
            next unless path
            cycle = [source] + path
            shortest = cycle if shortest.nil? || cycle.length < shortest.length || (cycle.length == shortest.length && cycle.join('>') < shortest.join('>'))
          end
        end
        Domgen.error("Intended import cycle detected: #{shortest.join(' -> ')}") if shortest
      end

      def shortest_path(adjacency, start, target)
        queue = [[start]]
        visited = {start => true}
        until queue.empty?
          path = queue.shift
          node = path.last
          return path if node == target
          adjacency[node].each do |candidate|
            next if visited[candidate]
            visited[candidate] = true
            queue << path + [candidate]
          end
        end
        nil
      end

      def build_edges
        edges = REALMS.each_with_object({}) { |realm, result| result[realm] = Hash.new { |hash, key| hash[key] = [] } }
        @import_capabilities.each do |(source, target), capabilities|
          capabilities.each { |capability| edges[capability][source] << target }
        end
        all_debts.each do |debt|
          next if debt.kind == :client_code
          debt.capabilities.each { |capability| edges[capability][debt.source] << debt.target }
        end
        REALMS.each do |realm|
          normalized = {}
          edges[realm].each { |source, targets| normalized[source] = targets.uniq.sort.freeze }
          normalized.default = [].freeze
          edges[realm] = normalized.freeze
        end
        edges.freeze
      end

      def resolve_profiles
        definitions = {}
        @module_configs.values.sort_by { |config| config.data_module.name.to_s }.each do |config|
          config.supported_realms.each do |realm|
            name = "#{config.data_module.name}#{realm.to_s.capitalize}"
            definitions[name] = ProfileDefinition.new(name, realm, config.data_module.name.to_s, [], [], [], false, false)
          end
        end
        @profile_definitions.each do |name, definition|
          Domgen.error("Test Profile '#{name}' conflicts with an automatically generated default profile") if definitions[name]
          definitions[name] = definition
        end
        definitions.keys.sort.each_with_object({}) do |name, result|
          result[name] = resolve_profile(definitions[name])
        end.freeze
      end

      def resolve_profile(definition)
        seeds = if definition.full?
                  module_names.select { |name| supports?(name, definition.realm) }
                else
                  [definition.root] + definition.includes
                end
        primary = closure(seeds, definition.realm)
        closures = REALMS.each_with_object({}) { |realm, result| result[realm] = [] }
        closures[definition.realm] = primary
        if definition.realm == :server
          persistence_seeds = primary.select { |name| supports?(name, :persistence) } + definition.persistence_includes
          closures[:persistence] = closure(persistence_seeds, :persistence)
        end
        closures.each { |realm, modules| closures[realm] = modules.sort.freeze }
        closures.freeze
        consumers = profile_consumers(definition)
        payload = profile_fingerprint_payload(definition, closures, consumers)
        fingerprint = Digest::SHA256.hexdigest(JSON.generate(payload))
        ResolvedProfile.new(repository,
                            definition.name,
                            definition.realm,
                            definition.root,
                            closures,
                            consumers,
                            definition.full?,
                            definition.node_compatible,
                            fingerprint)
      end

      def closure(seeds, realm)
        pending = seeds.uniq.sort
        result = []
        until pending.empty?
          current = pending.shift
          next if result.include?(current)
          result << current
          pending = (pending + @edges[realm][current]).uniq.sort
        end
        result.sort.freeze
      end

      def profile_fingerprint_payload(definition, closures, consumers)
        relevant_edges = []
        REALMS.each do |realm|
          selected = closures[realm]
          @edges[realm].keys.sort.each do |source|
            next unless selected.include?(source)
            @edges[realm][source].each do |target|
              relevant_edges << [realm.to_s, source, target] if selected.include?(target)
            end
          end
        end
        payload = {
          'name' => definition.name,
          'realm' => definition.realm.to_s,
          'root' => definition.root,
          'full' => definition.full?,
          'persistence_includes' => definition.persistence_includes,
          'closures' => REALMS.collect { |realm| [realm.to_s, closures[realm]] }.to_h,
          'edges' => relevant_edges,
          'consumers' => consumers
        }
        payload['node_compatible'] = definition.node_compatible if definition.realm == :client
        payload
      end

      def build_manifest
        {
          'generated_notice' => 'DO NOT EDIT: File is auto-generated',
          'repository' => repository.name.to_s,
          'modules' => module_names.collect do |name|
            config = module_config_by_name(name)
            {
              'name' => name,
              'realms' => config.supported_realms.collect(&:to_s),
              'architecture_packages' => config.architecture_packages.keys.sort.each_with_object({}) do |realm, result|
                result[realm.to_s] = config.architecture_packages[realm]
              end,
              'persistence_runtime_targets' => config.persistence_runtime_targets,
              'architecture_exclusion' => config.architecture_exclusion
            }
          end,
          'imports' => all_imports.collect do |declaration|
            {
              'source' => declaration.source,
              'target' => declaration.target,
              'capabilities' => @import_capabilities[[declaration.source, declaration.target]].collect(&:to_s)
            }
          end,
          'debt' => all_debts.collect do |debt|
            {
              'source' => debt.source,
              'target' => debt.target,
              'path' => debt.path,
              'capabilities' => debt.capabilities.collect(&:to_s),
              'kind' => debt.kind.to_s,
              'issue' => debt.issue,
              'rationale' => debt.rationale
            }
          end,
          'references' => @references.collect(&:to_h),
          'profiles' => @profiles.values.collect(&:to_h)
        }
      end

      def import_for(source, target)
        config = @module_configs[source]
        config && config.imports[target]
      end

      def model_debt_for(path)
        all_debts.find { |debt| debt.kind == :model && debt.path == path }
      end

      def all_imports
        @module_configs.values.flat_map { |config| config.imports.values }.sort_by { |declaration| [declaration.source, declaration.target] }
      end

      def all_debts
        @module_configs.values.flat_map(&:debts).sort_by { |debt| [debt.path, debt.source, debt.target] }
      end

      def module_names
        repository.data_modules.collect { |data_module| data_module.name.to_s }.sort
      end

      def module_config_by_name(name)
        data_module = repository.data_module_by_name(name)
        module_config(data_module)
      end

      def supports?(name, realm)
        module_config_by_name(name).supported_realms.include?(realm)
      end

      def profile_consumers(profile)
        generated = @generated_test_profiles.select { |_consumer, assignment| assignment[:profile] == profile.name }.keys
        (profile.consumers + generated).uniq.sort.freeze
      end

      def generated_test_consumer(qualified_test_name)
        package_name, separator, class_name = qualified_test_name.rpartition('.')
        Domgen.error("Generated test '#{qualified_test_name}' must have a qualified Java name") if separator.empty?
        "//server/src/test/java/#{package_name.tr('.', '/')}:#{class_name}"
      end

      def server_support_signature(profile)
        [profile.closures[:server],
         profile.closures[:persistence],
         'CommonDataAnalysisServer' == profile.name]
      end
    end

    module DataModuleExtension
      def supports_test_profiles(*realms)
        repository.test_profile_registry.support(self, realms)
      end

      def imports(*targets)
        options = targets.last.is_a?(Hash) ? targets.pop.dup : {}
        capabilities = options.delete(:via)
        Domgen.error("Unknown options on intended import from #{name}: #{options.keys.sort.join(', ')}") unless options.empty?
        Domgen.error("Data module #{name} must import at least one target") if targets.empty?
        repository.test_profile_registry.import(self, targets, capabilities)
      end

      def temporary_dependency(target, options = {})
        repository.test_profile_registry.debt(self, target, options)
      end

      def architecture_packages(packages)
        repository.test_profile_registry.architecture_packages(self, packages)
      end

      def persistence_runtime_targets(*targets)
        repository.test_profile_registry.persistence_runtime_targets(self, targets)
      end

      def exclude_from_architecture(reason)
        repository.test_profile_registry.architecture_exclusion(self, reason)
      end
    end

    module EntityExtension
      def uses_test_profile(profile_name)
        Domgen.error("Entity #{qualified_name} must enable JPA before using a persistence Test Profile") unless jpa?
        self.jpa.test_base_class = data_module.repository.test_profile_registry.use_profile_for_generated_test(
          :persistence,
          profile_name,
          jpa.qualified_model_test_name
        )
      end
    end

    module DataAccessObjectExtension
      def uses_test_profile(profile_name)
        Domgen.error("DAO #{qualified_name} must enable JPA before using a persistence Test Profile") unless jpa?
        self.jpa.test_base_class = data_module.repository.test_profile_registry.use_profile_for_generated_test(
          :persistence,
          profile_name,
          jpa.qualified_concrete_dao_test_name
        )
      end
    end

    module ServiceExtension
      def uses_test_profile(profile_name)
        Domgen.error("Service #{qualified_name} must enable EJB before using a server Test Profile") unless ejb?
        self.ejb.qualified_base_service_test_name = data_module.repository.test_profile_registry.use_profile_for_generated_test(
          :server,
          profile_name,
          ejb.qualified_concrete_service_test_name
        )
      end
    end

    module RepositoryExtension
      attr_reader :test_profile_registry

      def initialize(*args, &block)
        @test_profile_registry = Registry.new(self)
        super
      end

      def test_profile(name, options = {})
        test_profile_registry.profile(name, options)
      end

      def test_profiles
        test_profile_registry.profiles.values
      end

      def test_profile_by_name(name)
        test_profile_registry.profile_by_name(name)
      end

      def enforce_test_profile_architecture_mapping!
        test_profile_registry.enforce_architecture_mapping!
      end

      private

      def post_repository_definition
        super
        test_profile_registry.compile! if test_profile_registry.configured?
      end
    end
  end
end

Domgen::DataModule.prepend(Domgen::TestProfiles::DataModuleExtension)
Domgen::Entity.prepend(Domgen::TestProfiles::EntityExtension)
Domgen::DataAccessObject.prepend(Domgen::TestProfiles::DataAccessObjectExtension)
Domgen::Service.prepend(Domgen::TestProfiles::ServiceExtension)
Domgen::Repository.prepend(Domgen::TestProfiles::RepositoryExtension)
