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
  module Replicant
    class DefaultValues < Domgen.ParentedElement(:entity)
      def initialize(entity, defaults, options = {}, &block)
        raise "Attempted to define test_default on abstract entity #{entity.qualified_name}" if entity.abstract?
        raise "Attempted to define test_default on #{entity.qualified_name} with no values" if defaults.empty?
        defaults.keys.each do |key|
          raise "Attempted to define test_default on #{entity.qualified_name} with key '#{key}' that is not an attribute value" unless entity.attribute_by_name?(key)
          a = entity.attribute_by_name(key)
          raise "Attempted to define test_default on #{entity.qualified_name} for attribute '#{key}' when attribute has no replicant facet defined. Defaults = #{defaults.inspect}" unless a.replicant?
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
    end

    class Dataset < Domgen.ParentedElement(:application)
      def initialize(application, code, name, options, &block)
        @name = name
        @code = code
        @candidate_entity_types = []
        @required_type_datasets = []
        @dependent_datasets = []
        @dataset_root_entity_type = nil
        @post_subscribe_collect_hook = false
        @subscribe_private = true
        @outward_dataset_links = {}
        @inward_dataset_links = {}
        @routing_keys = {}
        @visibility = :universal
        @target_filter_parameter_derived_from_source_filter_parameter = false
        application.send :register_dataset, name, self
        super(application, options, &block)
      end

      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :react4j_area_of_interest_view, :component, :client, :replicant, '#{name}AreaOfInterestView'
      java_artifact :subscription_util, :comm, :client, :replicant, '#{name}SubscriptionUtil'

      Domgen.target_manager.target(:dataset, :repository, :facet_key => :replicant, :access_method => :datasets)

      attr_reader :application

      attr_reader :name

      def qualified_name
        "#{application.repository.qualified_name}.Datasets.#{name}"
      end

      attr_reader :code

      def to_s
        "Dataset[#{qualified_name}]"
      end

      def post_subscribe_collect_hook?
        !!@post_subscribe_collect_hook
      end

      attr_writer :post_subscribe_collect_hook

      def subscribe_private?
        !!@subscribe_private
      end

      attr_writer :subscribe_private

      def cacheable?
        !!@cacheable
      end

      attr_writer :cacheable

      def secure?
        @secure.nil? ? true : !!@secure
      end

      attr_writer :secure

      def visibility=(visibility)
        valid_values = [:external, :internal, :universal]
        Domgen.error("Invalid visibility set on #{qualified_name}. Value: #{visibility}. Valid_values: #{valid_values}") unless valid_values.include?(visibility)
        @visibility = visibility
      end

      def filter_mode
        @filter_mode || :unfiltered
      end

      def filter_mode=(filter_mode)
        valid_values = [:unfiltered, :implicit, :parameter_filtered]
        Domgen.error("Invalid filter_mode set on #{qualified_name}. Value: #{filter_mode}. Valid values: #{valid_values}") unless valid_values.include?(filter_mode)
        @filter_mode = filter_mode
      end

      def unfiltered?
        :unfiltered == filter_mode
      end

      def implicitly_filtered?
        :implicit == filter_mode
      end

      def parameter_filtered?
        :parameter_filtered == filter_mode
      end

      def fixed_filter_parameter?
        parameter_filtered? && filter_parameter.fixed?
      end

      def updatable_filter_parameter?
        parameter_filtered? && filter_parameter.updatable?
      end

      def reevaluate_membership_on_replica_update?
        @reevaluate_membership_on_replica_update.nil? ? false : !!@reevaluate_membership_on_replica_update
      end

      attr_writer :reevaluate_membership_on_replica_update

      # Does this dataset permit independently addressable selections distinguished by a dataset key?
      def keyed?
        @keyed.nil? ? false : !!@keyed
      end

      attr_writer :keyed

      def visibility
        @visibility
      end

      def external_visibility?
        self.visibility == :external || self.universal_visibility?
      end

      def internal_visibility?
        self.visibility == :internal || self.universal_visibility?
      end

      # Default visibility is both internal and externally visible
      # So a user can both subscribe to dataset explicitly and a dataset can dataset_link to this dataset
      def universal_visibility?
        self.visibility == :universal
      end

      def instance_dataset?
        !@dataset_root_entity_type.nil?
      end

      def type_dataset?
        !instance_dataset?
      end

      def candidate_entity_types
        Domgen.error("candidate_entity_types invoked for Instance Dataset #{name}") if instance_dataset?
        @candidate_entity_types
      end

      def type_dataset_transitively_includes_entity?(qualified_entity_name)
        self.required_type_datasets.any? { |dataset| dataset.candidate_entity_types.include?(qualified_entity_name) || dataset.type_dataset_transitively_includes_entity?(qualified_entity_name) }
      end

      def candidate_entity_types=(candidate_entity_types)
        Domgen.error("Attempted to assign candidate Entity Types #{candidate_entity_types.inspect} to Instance Dataset #{name} with Dataset Root Entity Type #{@dataset_root_entity_type.inspect}") if instance_dataset?
        @candidate_entity_types = candidate_entity_types
      end

      def dataset_root_entity_type
        Domgen.error("dataset_root_entity_type invoked for Type Dataset #{name}") if 0 != @candidate_entity_types.size
        @dataset_root_entity_type
      end

      def dataset_root_entity_type=(dataset_root_entity_type)
        Domgen.error("Attempted to assign Dataset Root Entity Type #{dataset_root_entity_type.inspect} to Type Dataset #{name} with candidate Entity Types #{@candidate_entity_types.inspect}") if 0 != @candidate_entity_types.size
        @dataset_root_entity_type = dataset_root_entity_type
      end

      def outward_dataset_links
        @outward_dataset_links.values
      end

      # Dataset Links from this Dataset to Parameter-Filtered target Datasets that are followed automatically.
      # Multiple Dataset Links between the same source and target Datasets must derive the same filter.
      def parameter_filtered_outward_automatic_dataset_links
        processed = []
        result = []
        self.outward_dataset_links.select{|dataset_link| dataset_link.auto?}.each do |dataset_link|
           target_dataset = self.application.dataset_by_name(dataset_link.target_dataset)
           next unless target_dataset.parameter_filtered?
           key = "#{dataset_link.source_dataset}=>#{dataset_link.target_dataset}"
           next if processed.include?(key)
           processed << key
           result << dataset_link
        end
        result
      end

      def inward_dataset_links
        Domgen.error("inward_dataset_links invoked for Type Dataset #{name}") if 0 != @candidate_entity_types.size
        @inward_dataset_links.values
      end

      def routing_keys
        Domgen.error("routing_keys invoked for Unfiltered Dataset #{name}") if unfiltered?
        @routing_keys.values
      end

      # Return the list of Entity Types reachable in an Instance Dataset.
      def reachable_entity_types
        Domgen.error("reachable_entity_types invoked for Type Dataset #{name}") if 0 != @candidate_entity_types.size
        @reachable_entity_types ||= []
      end

      def leaf_entity_types
        Domgen.error("leaf_entity_types invoked for Type Dataset #{name}") if 0 != @candidate_entity_types.size
        @leaf_entity_types ||= []
      end

      def included_entity_types
        instance_dataset? ? reachable_entity_types : candidate_entity_types
      end

      def filter(filter_parameter_type, options = {}, &block)
        Domgen.error("Attempting to redefine filter on dataset #{self.name}") if @filter
        Domgen.error("Filter Parameter on Dataset #{self.name} is not of type :struct, the only decoder supported at this time") if :struct != filter_parameter_type
        @filter ||= FilterParameter.new(self, filter_parameter_type, options, &block)
      end

      def filter_parameter
        Domgen.error("filter_parameter invoked for Dataset #{name} that is not Parameter-Filtered") unless parameter_filtered? && @filter
        @filter
      end

      def dependent_datasets
        @dependent_datasets.dup
      end

      def required_type_datasets
        @required_type_datasets.dup
      end

      def require_type_datasets=(require_type_datasets)
        require_type_datasets.each do |dataset_key|
          require_type_dataset(dataset_key)
        end
      end

      def require_type_dataset(dataset_key)
        dataset = application.repository.replicant.dataset_by_name(dataset_key)
        Domgen.error("Dataset '#{self.name}' requires Type Dataset #{dataset_key} but the required Dataset is not a Type Dataset.") if dataset.instance_dataset?
        Domgen.error("Dataset '#{self.name}' requires self which is invalid.") if self.name.to_s == dataset_key.to_s
        Domgen.error("Dataset '#{self.name}' requires Type Dataset #{dataset_key} multiple times.") if @required_type_datasets.include?(dataset)
        @required_type_datasets << dataset
        dataset.send(:add_dependent_dataset, self)
      end

      def post_verify
        if parameter_filtered? && !@filter
          Domgen.error("Parameter-Filtered Dataset #{self.name} must define a Filter Parameter")
        elsif !parameter_filtered? && @filter
          Domgen.error("#{filter_mode == :implicit ? 'Implicitly Filtered' : 'Unfiltered'} Dataset #{self.name} can not define a Filter Parameter")
        end
        if @filter && @filter.mode.nil?
          Domgen.error("Filter Parameter on Parameter-Filtered Dataset #{self.name} must specify mode as :fixed or :updatable")
        end
        if keyed? && !parameter_filtered?
          Domgen.error("Dataset #{self.name} can only be keyed when it is Parameter-Filtered")
        end
        if reevaluate_membership_on_replica_update? && !implicitly_filtered?
          Domgen.error("Dataset #{self.name} can only reevaluate membership on Replica update when it is Implicitly Filtered")
        end
        if cacheable? && (!unfiltered? || instance_dataset?)
          Domgen.error("Dataset #{self.name} can not be marked as cacheable as cacheable Datasets are not supported for Instance Datasets or filtered Datasets")
        end
        if cacheable? && post_subscribe_collect_hook?
          Domgen.error("Dataset #{self.name} can not be marked as cacheable when it has a post-subscribe collect hook because the hook may produce subscriber-specific results")
        end
        if self.instance_dataset?
          dataset_root_entity_type = self.application.repository.entity_by_name(self.dataset_root_entity_type)
          unless dataset_root_entity_type.primary_key.integer?
            Domgen.error("Instance Dataset #{self.name} has Dataset Root Entity Type #{self.dataset_root_entity_type} with a primary key that is not an integer")
          end
        end

        if self.internal_visibility? && self.instance_dataset? && self.inward_dataset_links.empty?
          Domgen.error("Dataset '#{self.name}' is marked with internal visibility but has no inward Dataset Links.")
        end

        if self.internal_visibility? && !self.instance_dataset? && self.dependent_datasets.empty?
          Domgen.error("Dataset '#{self.name}' is a Type Dataset marked with internal visibility but has no dependent Datasets.")
        end

        entities = self.included_entity_types

        if entities.empty?
          Domgen.error("Dataset '#{self.name}' contains no entities to replicate.")
        end

        entities.each do |entity_name|
          entity = application.repository.entity_by_name(entity_name)
          entity.attributes.select { |a| a.reference? && a.replicant? }.each do |a|
            referenced_entity = a.referenced_entity

            agls = a.replicant.automatic_dataset_links

            next if agls.any? { |dataset_link| dataset_link.source_dataset.to_s == self.name.to_s }

            # Unclear on how to handle this next scenario. Assume a subtype is visible?
            next if referenced_entity.abstract?

            # If linked entity is part of current dataset then all is ok.
            next if entities.any? { |e| e == referenced_entity.qualified_name }

            # If entity is part of a Required Type Dataset then all is ok
            next if self.type_dataset_transitively_includes_entity?(referenced_entity.qualified_name)

            next if self.instance_dataset? &&
              !self.inward_dataset_links.empty? &&
              self.inward_dataset_links.all? do |dataset_link|
                application.repository.replicant.dataset_by_name(dataset_link.source_dataset).included_entity_types.any? { |e| e == referenced_entity.qualified_name }
              end

            next if a.replicant.skip_link_checks.include?(self.name)

            Domgen.error("Dataset '#{self.name}' has a link from '#{a.qualified_name}' to entity '#{referenced_entity.qualified_name}' that is not an instance-level Dataset Link and is not transitively part of any Required Type Dataset. Immediate Required Type Datasets include: #{self.required_type_datasets.collect { |e| e.name }.inspect} and not in current Dataset [#{entities.join(', ')}].")
          end
        end
      end

      protected

      def add_dependent_dataset(dataset)
        @dependent_datasets << dataset
      end

      def register_routing_key(routing_key)
        key = routing_key.name.to_s
        Domgen.error("Attempted to register duplicate routing key link on attribute '#{routing_key.replicant_attribute.attribute.qualified_name}' on dataset '#{self.name}'") if @routing_keys[key]
        @routing_keys[key] = routing_key
      end

      def register_outward_dataset_link(dataset_link)
        target_dataset_name = dataset_link.target_dataset
        key = "#{target_dataset_name}-#{dataset_link.replicant_attribute.attribute.qualified_name.to_s}"
        Domgen.error("Attempted to register duplicate outward Dataset Link on attribute '#{dataset_link.replicant_attribute.attribute.qualified_name}' on dataset '#{self.name}'") if @outward_dataset_links[key]
        @outward_dataset_links[key] = dataset_link
      end

      def register_inward_dataset_link(dataset_link)
        source_dataset_name = dataset_link.source_dataset
        key = "#{source_dataset_name}-#{dataset_link.replicant_attribute.attribute.qualified_name.to_s}"
        Domgen.error("Attempted to register duplicate inward Dataset Link on attribute '#{dataset_link.replicant_attribute.attribute.qualified_name}' on dataset '#{self.name}' from dataset '#{source_dataset_name}'") if @inward_dataset_links[key]
        @inward_dataset_links[key] = dataset_link
      end
    end

    class DatasetLink < Domgen.ParentedElement(:replicant_attribute)
      def initialize(replicant_attribute, name, source_dataset, target_dataset, options, &block)
        repository = replicant_attribute.attribute.entity.data_module.repository
        unless repository.replicant.dataset_by_name?(source_dataset)
          Domgen.error("Source Dataset '#{source_dataset}' specified for Dataset Link on #{replicant_attribute.attribute.name} does not exist")
        end
        unless repository.replicant.dataset_by_name?(target_dataset)
          Domgen.error("Target Dataset '#{target_dataset}' specified for Dataset Link on #{replicant_attribute.attribute.name} does not exist")
        end
        unless replicant_attribute.attribute.reference? || replicant_attribute.attribute.primary_key?
          Domgen.error("Attempted to define a Dataset Link on non-reference, non-primary key attribute '#{replicant_attribute.attribute.qualified_name}'")
        end
        @name = name
        @source_dataset = source_dataset
        @target_dataset = target_dataset
        @auto = true
        @always_follow = source_dataset.to_s != target_dataset.to_s
        default_always_follow = false
        @always_follow = default_always_follow
        @exclude_target = nil
        super(replicant_attribute, options, &block)
        repository.replicant.dataset_by_name(source_dataset).send(:register_outward_dataset_link, self)
        repository.replicant.dataset_by_name(target_dataset).send(:register_inward_dataset_link, self)
        configred_exclude_target = options[:exclude_target] || options['exclude_target']
        if configred_exclude_target && !replicant_attribute.attribute.entity.data_module.repository.replicant.dataset_by_name(target_dataset).instance_dataset?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' marked as exclude_target=true but the target Dataset is a Type Dataset.")
        end
        configured_auto = options[:auto] || options['auto']
        if configured_auto
          Domgen.error("Dataset Link on #{replicant_attribute.attribute.qualified_name} from #{source_dataset} to #{target_dataset} specified auto=true property but this is now the default")
        end
        configured_always_follow = options[:always_follow] || options['always_follow']
        if !configured_always_follow.nil? && (!!configured_always_follow == default_always_follow)
          Domgen.error("Dataset Link on #{replicant_attribute.attribute.qualified_name} from #{source_dataset} to #{target_dataset} specified always_follow=#{configured_always_follow} property but this matched the default value")
        end

        if repository.replicant.dataset_by_name(target_dataset).instance_dataset? && self.exclude_target? && !self.replicant_attribute.attribute.primary_key?
          if self.replicant_attribute.attribute.inverse.replicant.excluded_dataset_traversals.include?(target_dataset)
            Domgen.error("#{replicant_attribute.attribute.qualified_name} explicitly excludes dataset #{target_dataset} but also has a Dataset Link named #{name} that references target that implicitly adds exclude. Remove explicit exclude as it is not needed.")
          else
            self.replicant_attribute.attribute.inverse.replicant.implicitly_excluded_dataset_traversals << target_dataset
          end
        end
      end

      attr_reader :name
      attr_reader :source_dataset
      attr_reader :target_dataset

      attr_accessor :path

      attr_writer :auto

      def auto?
        !!@auto
      end

      # Set this to true if this Dataset Link may require a different selection of a target Dataset that is already
      # required by the source Dataset. Setting this parameter forces collection of routing data and allows a later
      # stage to filter already present Subscription Dependencies.
      attr_writer :always_follow

      def always_follow?
        !!@always_follow
      end

      attr_writer :exclude_target

      # Should we exclude the target entity from source dataset? Typically done for automatically
      # traversing datasets but sometimes you may wish to override this.
      def exclude_target?
        Domgen.error("Invoked exclude_target? on #{self} which is not an Instance Dataset") unless self.replicant_attribute.attribute.entity.data_module.repository.replicant.dataset_by_name(target_dataset).instance_dataset?
        @exclude_target.nil? ? self.auto? : !!@exclude_target
      end

      attr_writer :target_filter_parameter_copied_from_source_filter_parameter

      def target_filter_parameter_copied_from_source_filter_parameter?
        !!@target_filter_parameter_copied_from_source_filter_parameter
      end

      attr_writer :target_filter_parameter_derived_from_source_filter_parameter

      def target_filter_parameter_derived_from_source_filter_parameter?
        !!@target_filter_parameter_derived_from_source_filter_parameter
      end

      def target_filter_parameter_requires_source_filter_parameter?
        self.target_filter_parameter_derived_from_source_filter_parameter? || self.target_filter_parameter_copied_from_source_filter_parameter?
      end

      attr_writer :target_filter_parameter_requires_source_entity

      def target_filter_parameter_requires_source_entity?
        !!@target_filter_parameter_requires_source_entity
      end

      attr_writer :target_filter_parameter_requires_source_dataset_root_id

      # This indicates that the source Dataset should be an Instance Dataset and the Dataset Root identifier is used
      # when deriving the target Filter Parameter.
      def target_filter_parameter_requires_source_dataset_root_id?
        !!@target_filter_parameter_requires_source_dataset_root_id
      end

      attr_writer :target_dataset_key_strategy

      def target_dataset_key_strategy
        @target_dataset_key_strategy
      end

      def target_dataset_key_derived_from_target_filter_parameter?
        :target_filter_parameter == @target_dataset_key_strategy
      end

      def to_s
        "DatasetLink[#{source_dataset} => #{target_dataset}](auto=#{auto?}, exclude_target=#{@exclude_target.nil? ? self.auto? : !!@exclude_target}, path=#{path.inspect}, name=#{name})"
      end

      def post_verify
        entity = self.replicant_attribute.attribute.primary_key? ? self.replicant_attribute.attribute.entity : self.replicant_attribute.attribute.referenced_entity

        # Need to make sure that the path is valid
        if self.path
          prefix = "Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.name}' with path element"
          self.path.to_s.split.each_with_index do |attribute_name_path_element, i|
            other = entity.attribute_by_name(attribute_name_path_element)
            Domgen.error("#{prefix} #{attribute_name_path_element} is nullable") if other.nullable? && i != 0
            Domgen.error("#{prefix} #{attribute_name_path_element} is not immutable") unless other.immutable?
            Domgen.error("#{prefix} #{attribute_name_path_element} is not a reference") unless other.reference?
            entity = other.referenced_entity
          end
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.name}' with path element does not identify the root of the target dataset") if entity.qualified_name != entity.data_module.repository.replicant.dataset_by_name(self.target_dataset).dataset_root_entity_type
        end

        repository = replicant_attribute.attribute.entity.data_module.repository
        source_dataset = repository.replicant.dataset_by_name(self.source_dataset)
        target_dataset = repository.replicant.dataset_by_name(self.target_dataset)

        # Need to make sure both Datasets are Instance Datasets
        prefix = "Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.name}'"
        Domgen.error("#{prefix} must have an Instance Dataset on the LHS if the target Dataset is not Unfiltered") unless source_dataset.instance_dataset? || target_dataset.unfiltered?
        Domgen.error("#{prefix} must have an Instance Dataset on the RHS") unless target_dataset.instance_dataset?

        # Need to make sure that the other side is the Dataset Root Entity Type
        unless target_dataset.dataset_root_entity_type != entity.name
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' links to an Entity Type that is not the Dataset Root Entity Type")
        end

        elements = (source_dataset.instance_dataset? ? source_dataset.reachable_entity_types.sort : source_dataset.candidate_entity_types)
        unless elements.include?(self.replicant_attribute.attribute.entity.qualified_name)
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' attempts to link to a dataset when the source entity is not part of the source dataset - #{elements.inspect}")
        end

        elements = (target_dataset.instance_dataset? ? target_dataset.reachable_entity_types.sort : target_dataset.candidate_entity_types)
        unless elements.include?(entity.qualified_name)
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' attempts to link to a dataset when the target entity is not part of the target dataset - #{elements.inspect}")
        end

        if self.target_filter_parameter_copied_from_source_filter_parameter?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has set target_filter_parameter_copied_from_source_filter_parameter=true but the source Dataset is not Parameter-Filtered") unless source_dataset.parameter_filtered?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has set target_filter_parameter_copied_from_source_filter_parameter=true but the target Dataset is not Parameter-Filtered") unless target_dataset.parameter_filtered?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has set target_filter_parameter_copied_from_source_filter_parameter=true but has also set target_filter_parameter_requires_source_entity=true. Remove one setting.") if self.target_filter_parameter_requires_source_entity?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has set target_filter_parameter_copied_from_source_filter_parameter=true but has also set target_filter_parameter_requires_source_dataset_root_id=true. Remove one setting.") if self.target_filter_parameter_requires_source_dataset_root_id?
        end

        if self.target_filter_parameter_derived_from_source_filter_parameter?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has set target_filter_parameter_derived_from_source_filter_parameter=true but the source Dataset is not Parameter-Filtered") unless source_dataset.parameter_filtered?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has set target_filter_parameter_derived_from_source_filter_parameter=true but the target Dataset is not Parameter-Filtered") unless target_dataset.parameter_filtered?
        end

        if self.target_filter_parameter_requires_source_entity?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has set target_filter_parameter_requires_source_entity=true but the target Dataset is not Parameter-Filtered") unless target_dataset.parameter_filtered?
        end

        if self.target_filter_parameter_requires_source_dataset_root_id?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has set target_filter_parameter_requires_source_dataset_root_id=true but the target Dataset is not Parameter-Filtered") unless target_dataset.parameter_filtered?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has set target_filter_parameter_requires_source_dataset_root_id=true but the source Dataset is not an Instance Dataset") unless source_dataset.instance_dataset?
        end

        unless [nil, :target_filter_parameter].include?(self.target_dataset_key_strategy)
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has invalid target_dataset_key_strategy=#{self.target_dataset_key_strategy.inspect}. Valid values are: :target_filter_parameter")
        end

        if self.target_dataset_key_derived_from_target_filter_parameter?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has set target_dataset_key_strategy=:target_filter_parameter but the target dataset is not keyed") unless target_dataset.keyed?
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has set target_dataset_key_strategy=:target_filter_parameter but the target Dataset is not Parameter-Filtered") unless target_dataset.parameter_filtered?
        end

        if target_dataset.parameter_filtered? && (!self.target_filter_parameter_requires_source_entity? && !self.target_filter_parameter_copied_from_source_filter_parameter? && !self.target_filter_parameter_derived_from_source_filter_parameter? && !self.target_filter_parameter_requires_source_dataset_root_id?)
          Domgen.error("Dataset Link from '#{self.source_dataset}' to '#{self.target_dataset}' via '#{self.replicant_attribute.attribute.qualified_name}' has a Parameter-Filtered target Dataset but has not specified a strategy for deriving the target Filter Parameter. Please specify one of: target_filter_parameter_requires_source_entity, target_filter_parameter_copied_from_source_filter_parameter, target_filter_parameter_derived_from_source_filter_parameter, target_filter_parameter_requires_source_dataset_root_id")
        end
      end
    end

    class RoutingKey < Domgen.ParentedElement(:replicant_attribute)
      def initialize(replicant_attribute, name, dataset, options, &block)
        repository = replicant_attribute.attribute.entity.data_module.repository
        unless repository.replicant.dataset_by_name?(dataset)
          Domgen.error("Dataset '#{dataset}' specified for routing key #{name} on #{replicant_attribute.attribute.name} does not exist")
        end
        @name = name
        @dataset = repository.replicant.dataset_by_name(dataset)
        super(replicant_attribute, options, &block)
        repository.replicant.dataset_by_name(dataset).send :register_routing_key, self
      end

      # A unique name for routing key within the dataset
      attr_reader :name

      # The dataset that routing key is used by
      attr_reader :dataset

      # The path is the chain of references along which routing key walks
      # Each link in chain must be a reference. Must be empty if initial
      # attribute is not a reference. A null in the path means nokey is
      # selected
      def path
        @path || []
      end

      def path=(path)
        Domgen.error("Path parameter '#{path.inspect}' specified for routing key #{name} on #{replicant_attribute.attribute.name} is not an array") unless path.is_a?(Array)
        path.each do |path_key|
          self.multivalued = true if is_inverse_path_element?(path_key) || is_path_element_recursive?(path_key)
        end
        @path = path
      end

      def is_path_element_recursive?(path_element)
        path_element.to_s =~ /^\*.*/
      end

      def is_inverse_path_element?(path_element)
        !!(path_element.to_s =~ /^<.*/)
      end

      def get_attribute_name_from_path_element?(path_element)
        is_inverse_path_element?(path_element) || is_path_element_recursive?(path_element) ? path_element[1, path_element.length] : path_element
      end

      # The name of the attribute that is used in referenced entity. This
      # will raise an exception if the initial attribute is not a reference, otherwise
      # it must match a name in the target entity
      def attribute_name
        Domgen.error("attribute_name invoked for routing key #{name} on #{replicant_attribute.attribute.name} when attribute is not a reference or inverse reference") unless reference? || inverse_start?
        return @attribute_name unless @attribute_name.nil?
        referenced_entity.primary_key.name
      end

      def attribute_name=(attribute_name)
        @attribute_name = attribute_name
      end

      def attribute_name?
        !@attribute_name.nil?
      end

      def reference?
        self.path.size > 0 || self.replicant_attribute.attribute.reference?
      end

      def referenced_attribute
        reference? || inverse_start? ? self.referenced_entity.attribute_by_name(self.attribute_name) : replicant_attribute.attribute
      end

      def referenced_entity
        Domgen.error("referenced_entity invoked on routing key #{name} on #{replicant_attribute.attribute.name} when attribute is not a reference or inverse reference") unless reference? || inverse_start?
        a = replicant_attribute.attribute
        e = self.replicant_attribute.attribute.reference? ? self.replicant_attribute.attribute.referenced_entity : a.entity
        path.each do |path_element|
          attr_name = get_attribute_name_from_path_element?(path_element)
          if is_inverse_path_element?(path_element)
            a = e.arez.referencing_client_side_attributes.select { |attr| attr.inverse.name.to_s == attr_name.to_s }[0]
            e = a.entity
          else
            a = e.attribute_by_name(attr_name)
            e = a.referenced_entity
          end
        end
        e
      end

      def inverse_start?
        self.replicant_attribute.attribute.primary_key? && self.path.size > 0
      end

      def target_attribute
        ((!self.inverse_start? && self.reference?) || self.attribute_name?) ? self.referenced_entity.attribute_by_name(self.attribute_name) : self.replicant_attribute.attribute
      end

      attr_writer :multivalued

      def multivalued?
        @multivalued.nil? ? false : !!@multivalued
      end

      def target_nullsafe?
        return true unless self.reference?
        return false if self.inverse_start?
        return self.replicant_attribute.attribute.reference? if self.path.size == 0

        a = replicant_attribute.attribute
        self.path.each do |path_element|
          return false if is_path_element_recursive?(path_element)
          return false if is_inverse_path_element?(path_element)
          a = a.referenced_entity.attribute_by_name(get_attribute_name_from_path_element?(path_element))
          return false if a.nullable?
        end
        return !a.nullable?
      end

      def post_verify
        # The next check could be removed if we were willing to update the client-side session context to walk down and unlink
        # child entities when an intermediate entity is delinked. In which case the dataset would not need to worry about leaf nodes
        # at all anymore
        Domgen.error("Routing key '#{self.name}' on #{self.replicant_attribute.attribute.name} is not immutable, not on a leaf Entity Type within an Instance Dataset and not a set_once") unless self.dataset.type_dataset? || self.replicant_attribute.attribute.immutable? || self.dataset.leaf_entity_types.include?(self.replicant_attribute.attribute.entity.qualified_name.to_s)
        Domgen.error("Routing key #{self.name} on #{self.replicant_attribute.attribute.qualified_name} specifies Unfiltered Dataset '#{self.dataset.name}'.") if self.dataset.unfiltered?
        Domgen.error("Routing key #{self.name} on #{self.replicant_attribute.attribute.qualified_name} specifies dataset '#{self.dataset.name}' that entity is not currently part of.") unless self.dataset.included_entity_types.include?(self.replicant_attribute.attribute.entity.qualified_name)

        if self.attribute_name?
          Domgen.error("Routing key #{self.name} on #{self.replicant_attribute.attribute.qualified_name} specifies attribute_name '#{attribute_name}' when attribute is not a reference or inverse reference") unless reference? || inverse_start?

          if 0 == self.path.size
            Domgen.error("Routing key #{self.name} on #{self.replicant_attribute.attribute.qualified_name} specifies attribute_name '#{attribute_name}' when the attribute is not immutable") if !self.referenced_attribute.immutable? && !self.referenced_attribute.set_once?
          end
        end

        if self.path.size > 0
          a = self.replicant_attribute.attribute
          e = self.replicant_attribute.attribute.reference? ? self.replicant_attribute.attribute.referenced_entity : a.entity
          path.each do |path_key|
            is_inverse = is_inverse_path_element?(path_key)
            path_element = get_attribute_name_from_path_element?(path_key)
            last_path_attribute = path.last == path_key

            if is_inverse
              candidates = e.arez.referencing_client_side_attributes.select { |attr| attr.inverse.name.to_s == path_element.to_s }
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{replicant_attribute.attribute.name} does not reference a client side attribute") if candidates.empty?
              a = candidates[0]
              e = a.entity
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{replicant_attribute.attribute.name} inverse reference is not immutable #{a.qualified_name}") unless a.immutable?
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{replicant_attribute.attribute.name} inverse reference is not multiplicity :many. This has not been implemented yet") unless a.inverse.multiplicity == :many
            else
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{replicant_attribute.attribute.name} does not refer to a valid attribute of #{e.qualified_name}") unless e.attribute_by_name?(path_element)
              a = e.attribute_by_name(path_element)
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{replicant_attribute.attribute.name} references an attribute that is not a reference #{a.qualified_name}") unless a.reference?
              Domgen.error("Path element '#{path_key}' specified for routing key #{name} on #{replicant_attribute.attribute.name} references an attribute that is not immutable #{a.qualified_name}") unless a.immutable?
              e = a.referenced_entity
            end

            if self.attribute_name? && last_path_attribute
              Domgen.error("Routing key #{self.name} on #{self.replicant_attribute.attribute.qualified_name} specifies attribute_name '#{attribute_name}' when the attribute is not immutable") if !self.referenced_attribute.immutable? && !self.referenced_attribute.set_once?
            end
          end
        end
      end
    end

    class FilterParameter < Domgen.ParentedElement(:dataset)
      attr_reader :filter_parameter_type

      include Characteristic

      def initialize(dataset, filter_parameter_type, options, &block)
        @filter_parameter_type = filter_parameter_type
        super(dataset, options, &block)
      end

      def name
        'FilterParameter'
      end

      def qualified_name
        "#{dataset.qualified_name}$#{name}"
      end

      def mode
        @mode
      end

      def mode=(mode)
        valid_values = [:fixed, :updatable]
        Domgen.error("Invalid Filter Parameter mode set on #{qualified_name}. Value: #{mode}. Valid values: #{valid_values}") unless valid_values.include?(mode)
        @mode = mode
      end

      def fixed?
        :fixed == mode
      end

      def updatable?
        :updatable == mode
      end

      def equiv?(other_filter_parameter)
        return false if other_filter_parameter.filter_parameter_type != self.filter_parameter_type
        return false if other_filter_parameter.collection_type != self.collection_type
        return false if other_filter_parameter.struct? && other_filter_parameter.referenced_struct.name != self.referenced_struct.name
        return false if other_filter_parameter.reference? && other_filter_parameter.referenced_entity.name != self.referenced_entity.name
        return true
      end

      def to_s
        "FilterParameter[#{self.qualified_name}]"
      end

      def characteristic_type_key
        filter_parameter_type
      end

      def characteristic_container
        dataset
      end

      def struct_by_name(name)
        self.dataset.application.repository.struct_by_name(name)
      end

      def entity_by_name(name)
        self.dataset.application.repository.entity_by_name(name)
      end
    end
  end

  FacetManager.facet(:replicant => [:ce, :arez, :action]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      attr_writer :schema_id

      def schema_id
        @schema_id || 1
      end

      attr_writer :client_component_package

      def client_component_package
        @client_component_package || "#{client_package}.components"
      end

      def client_ioc_package
        repository.gwt.client_ioc_package
      end

      attr_writer :server_comm_package

      def server_comm_package
        @server_comm_package || "#{server_package}.net"
      end

      attr_writer :client_comm_package

      def client_comm_package
        @client_comm_package || "#{client_package}.net"
      end

      def shared_comm_package
        @shared_comm_package || "#{shared_package}.net"
      end

      attr_writer :shared_comm_package

      def modules_package
        repository.gwt.modules_package
      end

      attr_writer :server_web_package

      def server_web_package
        @server_web_package || "#{server_package}.web"
      end

      java_artifact :gwt_client_session_context, :comm, :client, :replicant, '#{repository.name}GwtSessionContext'
      java_artifact :gwt_client_session_context_impl, :comm, :client, :replicant, '#{gwt_client_session_context_name}Impl'
      java_artifact :client_router, :comm, :client, :replicant, '#{repository.name}ClientRouter'
      java_artifact :system_constants, :comm, :shared, :replicant, '#{repository.name}SchemaConstants'
      java_artifact :dataset_constants, :comm, :shared, :replicant, '#{repository.name}DatasetConstants'
      java_artifact :entity_type_constants, :comm, :shared, :replicant, '#{repository.name}EntityTypeConstants'
      java_artifact :schema_sting_fragment, :comm, :client, :replicant, '#{repository.name}SystemSchemaFragment'
      java_artifact :schema_filter_tools, :comm, :client, :replicant, '#{repository.name}FilterTools'
      java_artifact :system_metadata, :comm, :server, :replicant, '#{repository.name}MetaData'
      java_artifact :session_context_impl, :comm, :server, :replicant, '#{repository.name}SessionContextImpl'
      java_artifact :abstract_session_context_impl, :comm, :server, :replicant, 'Abstract#{session_context_impl_name}'
      java_artifact :schema_test, :comm, :client, :replicant, 'Simple#{repository.name}SchemaTest'
      java_artifact :aggregate_remote_service_sting_fragment, :ioc, :client, :replicant, '#{repository.name}RemoteServicesFragment'
      java_artifact :aggregate_remote_service_sting_test_fragment, :ioc, :client, :replicant, '#{repository.name}RemoteServicesTestFragment'
      java_artifact :server_net_module, :comm, :server, :replicant, '#{repository.name}ReplicantNetModule'
      java_artifact :server_entity_test_module, :comm, :server, :replicant, '#{repository.name}ReplicantEntityModule'
      java_artifact :integration_module, :comm, :server, :replicant, '#{repository.name}IntegrationModule'

      attr_writer :include_standard_integration_test_module

      def include_standard_integration_test_module?
        @include_standard_integration_test_module.nil? ? true : !!@include_standard_integration_test_module
      end

      def auto_register_change_listener=(auto_register_change_listener)
        @auto_register_change_listener = !!auto_register_change_listener
      end

      def auto_register_change_listener?
        @auto_register_change_listener.nil? ? true : @auto_register_change_listener
      end

      def datasets
        dataset_map.values
      end

      def datasets_code_spaced
        datasets = self.datasets
        max_code = datasets.max_by {|dataset| dataset.code}.code
        code_to_dataset = {}
        datasets.each do |dataset|
          code_to_dataset[dataset.code] = dataset
        end
        result = []
        (max_code + 1).times do |i|
          result << code_to_dataset[i]
        end
        result
      end

      def dataset(name, options = {}, &block)
        Domgen::Replicant::Dataset.new(self, options.delete(:code) || dataset_map.size, name, options, &block)
      end

      def dataset_by_name(name)
        dataset = dataset_map[name.to_s]
        Domgen.error("Unable to locate dataset #{name}") unless dataset
        dataset
      end

      def dataset_by_name?(name)
        !!dataset_map[name.to_s]
      end

      def message_broker=(message_broker)
        Domgen.error('message_broker invalid. Expected to be in format DataModule.ServiceName') if self.message_broker.to_s.split('.').length != 2
        @message_broker = message_broker
      end

      def message_broker
        @message_broker || "#{self.replicant_control_data_module}.#{repository.name}ReplicantMessageBroker"
      end

      def replicant_control_data_module=(replicant_control_data_module)
        @replicant_control_data_module = replicant_control_data_module
      end

      def replicant_control_data_module
        @replicant_control_data_module || (self.repository.data_module_by_name?(self.repository.name) ? self.repository.name : Domgen.error('replicant_control_data_module unspecified and unable to derive default.'))
      end

      def generate_aggregate_remote_service_sting_fragment?
        !remote_service_sting_fragments.empty?
      end

      def remote_service_sting_fragments
        self.repository.data_modules.select{|dm|dm.replicant? && dm.replicant.generate_remote_service_sting_fragment?}
      end

      def pre_complete
        unless repository.application.user_experience? || 1 != repository.replicant.schema_id
          Domgen.error('repository.replicant.schema_id must be explicitly set to a value other than 1 as the application expects to be used as a library.')
        end
        toprocess = []
        self.datasets.each do |dataset|
          if dataset.parameter_filtered?
            if dataset.filter_parameter.enumeration?
              dataset.filter_parameter.enumeration.part_of_filter = true
            elsif dataset.filter_parameter.struct?
              struct = dataset.filter_parameter.referenced_struct
              toprocess << struct unless toprocess.include?(struct)
            end
          end
        end

        process_filter_structs([], toprocess)
      end

      def process_filter_structs(processed, toprocess)
        until toprocess.empty?
          struct = toprocess.pop
          process_filter_struct(processed, toprocess, struct)
        end
      end

      def process_filter_struct(processed, toprocess, struct)
        return if processed.include?(struct)
        struct.replicant.part_of_filter = true
        struct.fields.select { |field| field.replicant? }.each do |field|
          if field.enumeration?
            field.enumeration.replicant.part_of_filter = true
          elsif field.struct?
            struct = field.referenced_struct
            toprocess << struct unless toprocess.include?(struct)
          end
        end
      end

      def pre_verify
        code_to_dataset_map = {}
        repository.replicant.datasets.each do |dataset|
          (code_to_dataset_map[dataset.code] ||= []) << dataset
        end
        code_to_dataset_map.each do |code, datasets|
          if datasets.size > 1
            Domgen.error("Multiple Datasets map to the same code #{code} : #{datasets.collect{|dataset|dataset.name}.inspect}")
          end
        end
        if repository.gwt?
          repository.gwt.sting_includes << qualified_schema_sting_fragment_name
          repository.gwt.sting_includes << qualified_gwt_client_session_context_impl_name
        end

        repository.ejb.add_test_module(self.server_net_module_name, self.qualified_server_net_module_name) if repository.ejb?
        if self.datasets.size == 0
          Domgen.error('replicant facet enabled but no datasets defined')
        end

        # It seems reasonable to restrict the set of methods that are annotated with replicate to those that are replication
        # enabled. Unfortunately, Rose does not configure this explicitly yet, and we have not had time to fix it. When we
        # fix rose then only add @Replicate when replicant enabled...
        repository.data_modules.select { |data_module| data_module.ejb? }.each do |data_module|
          data_module.services.select { |service| service.ejb? && service.ejb.generate_boundary? }.each do |service|
            service.methods.each do |method|
              if method.service.ejb?
                if method.ejb.generate_boundary?
                  method.ejb.boundary_annotations << 'replicant.server.ee.Replicate'
                end
                if method.ejb.internal_boundary_service?
                  method.ejb.internal_boundary_annotations << 'replicant.server.ee.Replicate'
                end
              end
            end
          end
        end
      end

      def post_complete
        repository.jpa.add_test_module(repository.replicant.server_entity_test_module_name, repository.replicant.qualified_server_entity_test_module_name)
        index = 0
        repository.data_modules.select { |data_module| data_module.replicant? }.each do |data_module|
          data_module.entities.each do |entity|
            if entity.replicant? && entity.concrete?
              entity.replicant.transport_id = index
              index += 1
            end
          end
        end
        repository.replicant.datasets.select(&:instance_dataset?).each do |dataset|
          root = repository.entity_by_name(dataset.dataset_root_entity_type)
          entity_list = [root]
          dataset.leaf_entity_types << root.qualified_name.to_s
          while entity_list.size > 0
            entity = entity_list.pop
            unless dataset.reachable_entity_types.include?(entity.qualified_name.to_s)
              dataset.reachable_entity_types << entity.qualified_name.to_s
              entity.referencing_attributes.each do |a|
                if a.replicant?
                  if a.inverse.replicant.all_excluded_dataset_traversals.include?(dataset.name)
                    # Record the excluded Dataset Traversal so the model can reject exclusions that were unnecessary.
                    a.inverse.replicant.excluded_dataset_traversals_encountered << dataset.name
                  elsif a.inverse.replicant.traversable?
                    dataset.leaf_entity_types.delete(entity.qualified_name.to_s)
                    a.inverse.replicant.dataset_traversals = a.inverse.replicant.dataset_traversals + [dataset.name]
                    Domgen.error("#{a.qualified_name} is not immutable but is on path in dataset #{dataset.name}") unless a.immutable?
                    unless dataset.reachable_entity_types.include?(a.entity.qualified_name.to_s)
                      entity_list << a.entity
                      dataset.leaf_entity_types << a.entity.qualified_name.to_s
                    end
                  end
                end
              end
            end
          end
        end
        repository.replicant.datasets.each(&:post_verify)

        repository.data_modules.select { |dm| dm.replicant? }.each do |data_module|
          data_module.entities.select { |e| e.replicant? }.each do |entity|
            entity.referencing_attributes.select { |a| a.replicant? }.each do |a|
              a.inverse.replicant.excluded_dataset_traversals.each do |dataset_traversal|
                unless a.inverse.replicant.excluded_dataset_traversals_encountered.include?(dataset_traversal)
                  Domgen.error("#{a.qualified_name} defined an 'inverse.replicant.excluded_dataset_traversals' property that includes Dataset #{dataset_traversal} but the relationship was not encountered during its Dataset Traversal")
                end
              end
            end
          end
        end

        unreplicated_entities = []
        repository.data_modules.select { |data_module| data_module.arez? }.each do |data_module|
          data_module.entities.select { |entity| entity.arez? && entity.concrete? }.each do |entity|
            unreplicated_entities << entity.qualified_name
          end
        end
        repository.replicant.datasets.each do |dataset|
          dataset.included_entity_types.each do |included_entity|
            unreplicated_entities.delete(included_entity.to_s)
          end
        end
        unless unreplicated_entities.empty?
          Domgen.error("Several Entities have the arez facet enabled but are not part of any Replicant Dataset. Entities:\n#{unreplicated_entities.join("\n")}")
        end
      end

      private

      def filter_options(dataset)
        filter_options = {}
        if dataset.parameter_filtered?
          filter_options =
            {
              :collection_type => dataset.filter_parameter.collection_type,
              :nullable => dataset.filter_parameter.nullable?
            }
          filter_options[:referenced_entity] = dataset.filter_parameter.referenced_entity if dataset.filter_parameter.reference?
          filter_options[:referenced_struct] = dataset.filter_parameter.referenced_struct if dataset.filter_parameter.struct?
        end
        filter_options
      end

      def register_dataset(name, dataset)
        dataset_map[name.to_s] = dataset
      end

      def dataset_map
        @datasets ||= {}
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::ReplicantJavaPackage

      java_artifact :mapper, :entity, :client, :replicant, '#{data_module.name}Mapper'
      java_artifact :encoder, :entity, :server, :replicant, '#{data_module.name}Encoder'
      java_artifact :remote_service_sting_fragment, :service, :client, :replicant, '#{data_module.name}RemoteServiceFragment'
      java_artifact :remote_service_sting_test_fragment, :service, :client, :replicant, '#{data_module.name}RemoteServiceTestFragment'

      def generate_remote_service_sting_fragment?
        !remote_service_implementations.empty?
      end

      def remote_service_implementations
        data_module.services.select{|service| service.replicant?}
      end

      def replicated_entities
        data_module.entities.select{|service| service.replicant?}
      end

      def replicated_entities?
        !self.replicated_entities.empty?
      end

      attr_writer :support_default_parameters

      def support_default_parameters?
        @support_default_parameters.nil? ? false : !!@support_default_parameters
      end
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      attr_writer :service_name

      def service_name
        @service_name || service.name
      end

      def qualified_service_name
        "#{service.data_module.replicant.client_service_package}.#{service_name}"
      end

      attr_writer :service_impl_name

      def service_impl_name
        @service_impl_name || "#{service.name}RemoteImpl"
      end

      def qualified_service_impl_name
        "#{service.data_module.replicant.client_service_package}.#{service_impl_name}"
      end

      def mock_service_name
        "Mock#{service_name}"
      end

      def qualified_mock_service_name
        "#{service.data_module.replicant.client_service_package}.#{mock_service_name}"
      end


    end

    facet.enhance(Parameter) do
      include Domgen::Java::ReplicantJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    facet.enhance(Parameter) do
      def characteristic_transport_type
        if parameter.collection?
          collection_transport_type
        elsif parameter.datetime? || parameter.integer? || parameter.reference?
          'double'
        elsif parameter.struct?
          parameter.replicant.java_component_type(:boundary)
        else
          parameter.replicant.java_component_type(:transport)
        end
      end

      def collection_transport_type
        base_type =
          if parameter.datetime? || parameter.integer? || parameter.reference?
            'double'
          elsif parameter.struct?
            parameter.replicant.java_component_type(:boundary)
          else
            parameter.replicant.java_component_type(:transport)
          end
        "#{base_type}[]"
      end

      def to_characteristic_transport_type
        param = Domgen::Naming.camelize(parameter.name)
        if parameter.collection?
          to_collection_transport_type
        elsif parameter.datetime?
          "#{param}.getTime()"
        elsif parameter.enumeration? && parameter.enumeration.numeric_values?
          "#{param}.ordinal()"
        elsif parameter.enumeration? && parameter.enumeration.textual_values?
          "#{param}.name()"
        elsif parameter.date?
          "#{param}.toString()"
        else
          param
        end
      end

      def to_collection_transport_type
        param = Domgen::Naming.camelize(parameter.name)
        if parameter.integer? || parameter.reference?
          "#{param}.stream().mapToDouble(Integer::intValue).toArray()"
        elsif parameter.datetime?
          "#{param}.stream().mapToDouble(d -> d.getTime()).toArray()"
        elsif parameter.enumeration? && parameter.enumeration.numeric_values? && parameter.nullable?
          "#{param}.stream().map(e -> e.ordinal()).toArray( Integer[]::new )"
        elsif parameter.enumeration? && parameter.enumeration.numeric_values?
          "#{param}.stream().mapToInt(e -> e.ordinal()).toArray()"
        elsif parameter.enumeration? && parameter.enumeration.textual_values?
          "#{param}.stream().map(e -> e.name()).toArray( String[]::new )"
        elsif parameter.date?
          "#{param}.stream().map(d -> d.toString()).toArray(String[]::new)"
        else
          "#{param}.toArray( new #{parameter.replicant.java_component_type}[ 0 ])"
        end
      end
    end

    facet.enhance(Result) do
      include Domgen::Java::ReplicantJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    facet.enhance(Exception) do
      include Domgen::Java::ReplicantJavaCharacteristic
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.replicant.client_service_package}.#{name}"
      end

      def json_decoder_name
        "#{name}JsonDecoder"
      end

      def qualified_json_decoder_name
        "#{exception.data_module.replicant.client_service_package}.#{json_decoder_name}"
      end

      attr_writer :module_local

      def module_local?
        @module_local.nil? ? false : !!@module_local
      end

      def non_module_local_parent_qualified_name
        e = self.exception
        while e
          return e.replicant.qualified_name unless module_local?
          e = e.extends.nil? ? nil : e.data_module.exception_by_name(e.extends)
        end
        return self.exception.java.standard_extends
      end

      attr_writer :support_default_parameters

      def support_default_parameters?
        @support_default_parameters.nil? ? exception.data_module.replicant.support_default_parameters? : !!@support_default_parameters
      end
    end

    facet.enhance(ExceptionParameter) do
      include Domgen::Java::ReplicantJavaCharacteristic
      def get_from_json_extension(json)
          case
          when parameter.enumeration? then "#{json}.getAsAny( \"#{parameter.name}\" ).asInt()"
          when parameter.datetime? then "new java.util.Date( #{json}.getAsAny( \"#{parameter.name}\" ).asLong() )"
          when parameter.integer? then "#{json}.getAsAny( \"#{parameter.name}\" ).asInt()"
          when parameter.reference? then "#{json}.getAsAny( \"#{parameter.name}\" ).asInt()"
          when parameter.boolean? then "#{json}.getAsAny( \"#{parameter.name}\" ).asBoolean()"
          else "#{json}.getAsAny( \"#{parameter.name}\" ).asString()"
          end
      end

      def characteristic
        parameter
      end
    end

    facet.enhance(Entity) do
      include Domgen::Java::BaseJavaGenerator

      def transport_id
        Domgen.error('Attempted to invoke transport_id on abstract entity') if entity.abstract?
        @transport_id
      end

      def transport_id=(transport_id)
        Domgen.error('Attempted to assign transport_id on abstract entity') if entity.abstract?
        @transport_id = transport_id
      end

      def interfaces
        @interfaces ||= []
      end

      def dataset_root_entity_type?
        entity.data_module.repository.replicant.datasets.any? { |dataset| dataset.instance_dataset? && dataset.dataset_root_entity_type.to_s == entity.qualified_name.to_s }
      end

      def instance_datasets_with_root_entity_type
        entity.data_module.repository.replicant.datasets.select { |dataset| dataset.instance_dataset? && dataset.dataset_root_entity_type.to_s == entity.qualified_name.to_s }
      end

      def type_datasets_including_entity_type
        entity.data_module.repository.replicant.datasets.select { |dataset| !dataset.instance_dataset? && dataset.candidate_entity_types.include?(entity.qualified_name.to_s) }
      end

      def include_in_type_dataset(dataset)
        dataset = entity.data_module.repository.replicant.dataset_by_name(dataset)
        entity_type = entity.qualified_name.to_s
        Domgen.error("Attempted to include Entity Type '#{entity_type}' in Instance Dataset '#{dataset.name}' with Dataset Root Entity Type '#{dataset.dataset_root_entity_type}'.") if dataset.instance_dataset?
        dataset.candidate_entity_types << entity_type
      end

      def root_of_instance_dataset(dataset)
        dataset = entity.data_module.repository.replicant.dataset_by_name(dataset)
        entity_type = entity.qualified_name
        Domgen.error("Attempted to override Dataset Root Entity Type '#{dataset.dataset_root_entity_type}' for Instance Dataset '#{dataset.name}' with '#{entity_type}'.") if dataset.instance_dataset?
        Domgen.error("Attempted to designate Entity Type '#{entity_type}' as the Dataset Root Entity Type for Type Dataset '#{dataset.name}' with candidate Entity Types #{dataset.candidate_entity_types.inspect}.") unless dataset.candidate_entity_types.empty?
        dataset.dataset_root_entity_type = entity_type
      end

      def test_create_default(defaults)
        (@test_create_defaults ||= []) << Domgen::Replicant::DefaultValues.new(entity, defaults)
      end

      def test_create_defaults
        @test_create_defaults.nil? ? [] : @test_create_defaults.dup
      end

      def outgoing_links_from(dataset)
        entity.referencing_attributes.select{|a| a.replicant? && a.inverse.traversable? && a.inverse.replicant.dataset_traversals.include?(dataset.name) && !a.replicant.dataset_links.any?{|g| g.source_dataset == dataset && !g.exclude_target? }}
      end

      def datasets
        entity.data_module.repository.replicant.datasets.select do |dataset|
          (dataset.instance_dataset? && dataset.reachable_entity_types.include?(entity.qualified_name.to_s)) ||
            (!dataset.instance_dataset? && dataset.candidate_entity_types.include?(entity.qualified_name.to_s)) ||
            entity.attributes.any? { |a| a.replicant? && a.replicant.routing_keys.any? { |routing_key| routing_key.dataset.name.to_s == dataset.name.to_s } }
        end
      end

      def requires_updater?
        !self.entity.extends.nil? || self.entity.declared_attributes.any?{|attribute| attribute.replicant? && !attribute.immutable?}
      end

      def pre_verify
        if entity.data_module.repository.replicant.auto_register_change_listener? && entity.jpa?
          entity.jpa.entity_listeners << 'replicant.server.ee.ReplicantEntityChangeListener'
        end
      end
    end

    facet.enhance(Attribute) do

      def skip_link_checks
        @skip_link_checks ||= []
      end

      attr_writer :skip_link_checks

      def eager?
        !lazy?
      end

      def lazy=(lazy)
        Domgen.error("Attempted to make non-reference #{attribute.qualified_name} lazy") if lazy && !attribute.reference?
        @lazy = lazy
      end

      def lazy?
        attribute.reference? && (@lazy.nil? ? false : @lazy)
      end

      def routing_keys_for_datasets=(datasets)
        Domgen.error('routing_keys_for_datasets should be an array of symbols') unless datasets.is_a?(Array) && datasets.all? { |dataset| dataset.is_a?(Symbol) }
        Domgen.error('routing_keys_for_datasets should only contain valid Datasets') unless datasets.all? { |dataset| attribute.entity.data_module.repository.replicant.dataset_by_name(dataset) }
        datasets.each do |dataset|
          routing_key(dataset)
        end
      end

      def routing_keys_map
        @routing_keys ||= {}
      end

      def routing_keys
        routing_keys_map.values
      end

      def routing_key(dataset, options = {})
        params = options.dup
        name = params.delete(:name) || attribute.qualified_name.gsub('.', '_')
        routing_keys_map["#{dataset}#{name}"] = Domgen::Replicant::RoutingKey.new(self, name, dataset, params)
      end

      def automatic_dataset_links
        dataset_links_map.values.select { |dataset_link| dataset_link.auto? }
      end

      def dataset_links
        dataset_links_map.values
      end

      def dataset_link(source_dataset, target_dataset, options = {}, &block)
        key = "#{source_dataset}->#{target_dataset}"
        Domgen.error("Dataset Link already defined between #{source_dataset} and #{target_dataset} on attribute '#{attribute.qualified_name}'") if dataset_links_map[key]
        dataset_links_map[key] = Domgen::Replicant::DatasetLink.new(self, "#{key}:#{attribute.qualified_name}", source_dataset, target_dataset, options, &block)
      end

      include Domgen::Java::ReplicantJavaCharacteristic

      def post_verify
        self.dataset_links.each do |dataset_link|
          dataset_link.post_verify
        end
        self.routing_keys.each do |routing_key|
          routing_key.post_verify
        end
        if self.attribute.reference?
          referenced_entity = self.attribute.referenced_entity
          Domgen.error("#{self.attribute.qualified_name} has specified an inverse.replicant.excluded_dataset_traversals values but the referenced entity has no replicant facet enabled") if !self.attribute.inverse.replicant.excluded_dataset_traversals.empty? && !referenced_entity.replicant?
          self.attribute.inverse.replicant.excluded_dataset_traversals.each do |dataset_name|
            a = self.attribute
            repository_replicant_facet = a.entity.data_module.repository.replicant
            Domgen.error("#{a.qualified_name} has specified an inverse.replicant.excluded_dataset_traversals value for dataset named '#{dataset_name}' but no such dataset exists") unless repository_replicant_facet.dataset_by_name?(dataset_name)
            dataset = repository_replicant_facet.dataset_by_name(dataset_name)
            Domgen.error("#{a.qualified_name} has specified an inverse.replicant.excluded_dataset_traversals value for Dataset named '#{dataset_name}' but the Dataset is not an Instance Dataset") unless dataset.instance_dataset?
            Domgen.error("#{a.qualified_name} has specified an inverse.replicant.excluded_dataset_traversals value for dataset named '#{dataset_name}' but referenced entity #{referenced_entity.qualified_name} is not part of the specified dataset") unless dataset.included_entity_types.include?(referenced_entity.qualified_name)
          end
        end
      end

      protected

      def dataset_links_map
        @dataset_links ||= {}
      end

      def characteristic
        attribute
      end
    end

    facet.enhance(InverseElement) do
      def traversable=(traversable)
        Domgen.error("traversable #{traversable} is invalid") unless inverse.class.inverse_traversable_types.include?(traversable)
        @traversable = traversable
      end

      def traversable?
        @traversable.nil? ? (self.inverse.traversable? && self.inverse.attribute.referenced_entity.replicant?) : !!@traversable
      end

      def all_excluded_dataset_traversals
        self.implicitly_excluded_dataset_traversals + self.excluded_dataset_traversals
      end

      def excluded_dataset_traversals_encountered
        @excluded_dataset_traversals_encountered ||= []
      end

      def implicitly_excluded_dataset_traversals
        @implicitly_excluded_dataset_traversals ||= []
      end

      def excluded_dataset_traversals
        @excluded_dataset_traversals ||= []
      end

      def excluded_dataset_traversals=(excluded_dataset_traversals)
        @excluded_dataset_traversals = excluded_dataset_traversals
      end

      # Dataset Traversals that include this relationship.
      def dataset_traversals=(dataset_traversals)
        Domgen.error('dataset_traversals should be an array of symbols') unless dataset_traversals.is_a?(Array) && dataset_traversals.all? { |m| m.is_a?(Symbol) }
        Domgen.error('dataset_traversals should only be set when traversable?') unless inverse.traversable?
        Domgen.error('dataset_traversals should only contain valid datasets') unless dataset_traversals.all? { |m| inverse.attribute.entity.data_module.repository.replicant.dataset_by_name(m) }
        @dataset_traversals = dataset_traversals
      end

      def dataset_traversals
        @dataset_traversals || []
      end

      def pre_complete
        if self.inverse.traversable? && !self.inverse.attribute.referenced_entity.replicant?
          self.inverse.disable_facet(:replicant)
        end
      end
    end

    facet.enhance(EnumerationSet) do
      def part_of_filter?
        !!@part_of_filter
      end

      attr_writer :part_of_filter
    end

    facet.enhance(Struct) do
      def part_of_filter?
        !!@part_of_filter
      end

      attr_writer :part_of_filter

      def filter_for_dataset(dataset_key, options = {})
        struct.data_module.repository.replicant.dataset_by_name(dataset_key).filter(:struct, options.merge(:referenced_struct => struct.qualified_name))
      end
    end
  end
end
