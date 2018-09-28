require 'cocoapods/target/framework_paths'

module Pod
  # Stores the information relative to the target used to compile a single Pod.
  # A pod can have one or more activated spec, subspecs and test specs.
  #
  class PodTarget < Target
    # @return [Array<Specification>] the spec, subspecs and test specs of the target.
    #
    attr_reader :specs

    # @return [Array<Specification>] All of the test specs within this target.
    #         Subset of #specs.
    #
    attr_reader :test_specs

    # @return [Array<Specification>] All of the specs within this target that are not test specs.
    #         Subset of #specs.
    #
    attr_reader :non_test_specs

    # @return [Array<TargetDefinition>] the target definitions of the Podfile
    #         that generated this target.
    #
    attr_reader :target_definitions

    # @return [Array<Sandbox::FileAccessor>] the file accessors for the
    #         specifications of this target.
    #
    attr_reader :file_accessors

    # @return [String] the suffix used for this target when deduplicated. May be `nil`.
    #
    # @note This affects the value returned by #configuration_build_dir
    #       and accessors relying on this as #build_product_path.
    #
    attr_reader :scope_suffix

    # @return [HeadersStore] the header directory for the target.
    #
    attr_reader :build_headers

    # @return [Array<PodTarget>] the targets that this target has a dependency
    #         upon.
    #
    attr_accessor :dependent_targets

    # @return [Hash{String=>Array<PodTarget>}] all target dependencies by test spec name.
    #
    attr_accessor :test_dependent_targets_by_spec_name

    # Initialize a new instance
    #
    # @param [Sandbox] sandbox @see Target#sandbox
    # @param [Boolean] host_requires_frameworks @see Target#host_requires_frameworks
    # @param [Hash{String=>Symbol}] user_build_configurations @see Target#user_build_configurations
    # @param [Array<String>] archs @see Target#archs
    # @param [Platform] platform @see Target#platform
    # @param [Array<TargetDefinition>] target_definitions @see #target_definitions
    # @param [Array<Sandbox::FileAccessor>] file_accessors @see #file_accessors
    # @param [String] scope_suffix @see #scope_suffix
    #
    def initialize(sandbox, host_requires_frameworks, user_build_configurations, archs, platform, specs,
                   target_definitions, file_accessors = [], scope_suffix = nil)
      super(sandbox, host_requires_frameworks, user_build_configurations, archs, platform)
      raise "Can't initialize a PodTarget without specs!" if specs.nil? || specs.empty?
      raise "Can't initialize a PodTarget without TargetDefinition!" if target_definitions.nil? || target_definitions.empty?
      raise "Can't initialize a PodTarget with only abstract TargetDefinitions!" if target_definitions.all?(&:abstract?)
      raise "Can't initialize a PodTarget with an empty string scope suffix!" if scope_suffix == ''
      @specs = specs.dup.freeze
      @target_definitions = target_definitions
      @file_accessors = file_accessors
      @scope_suffix = scope_suffix
      @test_specs, @non_test_specs = @specs.partition(&:test_specification?)
      @build_headers = Sandbox::HeadersStore.new(sandbox, 'Private', :private)
      @dependent_targets = []
      @test_dependent_targets_by_spec_name = {}
      @build_config_cache = {}
    end

    # Scopes the current target based on the existing pod targets within the cache.
    #
    # @param [Hash{Array => PodTarget}] cache
    #        the cached target for a previously scoped target.
    #
    # @return [Array<PodTarget>] a scoped copy for each target definition.
    #
    def scoped(cache = {})
      target_definitions.map do |target_definition|
        cache_key = [specs, target_definition]
        if cache[cache_key]
          cache[cache_key]
        else
          target = PodTarget.new(sandbox, host_requires_frameworks, user_build_configurations, archs, platform, specs, [target_definition], file_accessors, target_definition.label)
          target.dependent_targets = dependent_targets.flat_map { |pt| pt.scoped(cache) }.select { |pt| pt.target_definitions == [target_definition] }
          target.test_dependent_targets_by_spec_name = Hash[test_dependent_targets_by_spec_name.map do |spec_name, test_pod_targets|
            scoped_test_pod_targets = test_pod_targets.flat_map do |test_pod_target|
              test_pod_target.scoped(cache).select { |pt| pt.target_definitions == [target_definition] }
            end
            [spec_name, scoped_test_pod_targets]
          end]
          cache[cache_key] = target
        end
      end
    end

    # @return [String] the label for the target.
    #
    def label
      if scope_suffix.nil? || scope_suffix[0] == '.'
        "#{root_spec.name}#{scope_suffix}"
      else
        "#{root_spec.name}-#{scope_suffix}"
      end
    end

    # @return [String] the Swift version for the target. If the pod author has provided a Swift version
    #                  then that is the one returned, otherwise the Swift version is determined by the user
    #                  targets that include this pod target.
    #
    def swift_version
      spec_swift_version || target_definitions.map(&:swift_version).compact.uniq.first
    end

    # @return [String] the Swift version within the root spec. Might be `nil` if none is set.
    #
    def spec_swift_version
      root_spec.swift_version
    end

    # @return [Podfile] The podfile which declares the dependency.
    #
    def podfile
      target_definitions.first.podfile
    end

    # @return [String] The name to use for the source code module constructed
    #         for this target, and which will be used to import the module in
    #         implementation source files.
    #
    def product_module_name
      root_spec.module_name
    end

    # @return [Bool] Whether or not this target should be built.
    #
    # A target should not be built if it has no source files.
    #
    def should_build?
      return @should_build if defined? @should_build
      accessors = file_accessors.reject { |fa| fa.spec.test_specification? }
      source_files = accessors.flat_map(&:source_files)
      source_files -= accessors.flat_map(&:headers)
      @should_build = !source_files.empty?
    end

    # @return [Array<Specification::Consumer>] the specification consumers for
    #         the target.
    #
    def spec_consumers
      specs.map { |spec| spec.consumer(platform) }
    end

    # @return [Array<Specification::Consumer>] the test specification consumers for
    #         the target.
    #
    def test_spec_consumers
      test_specs.map { |test_spec| test_spec.consumer(platform) }
    end

    # @return [Boolean] Whether the target uses Swift code. This excludes source files from test specs.
    #
    def uses_swift?
      return @uses_swift if defined? @uses_swift
      @uses_swift = begin
        file_accessors.reject { |a| a.spec.test_specification? }.any? do |file_accessor|
          file_accessor.source_files.any? { |sf| sf.extname == '.swift' }
        end
      end
    end

    # Checks whether a particular test specification uses Swift or not.
    #
    # @param  [Specification] test_spec
    #         The test spec to query against.
    #
    # @return [Boolean] Whether the target uses Swift code within the requested test spec.
    #
    def uses_swift_for_test_spec?(test_spec)
      @uses_swift_for_test_type ||= {}
      return @uses_swift_for_test_type[test_spec.name] if @uses_swift_for_test_type.key?(test_spec.name)
      @uses_swift_for_test_type[test_spec.name] = begin
        file_accessors.select { |a| a.spec.test_specification? && a.spec == test_spec }.any? do |file_accessor|
          file_accessor.source_files.any? { |sf| sf.extname == '.swift' }
        end
      end
    end

    # @return [Boolean] Whether the target should build a static framework.
    #
    def static_framework?
      requires_frameworks? && root_spec.static_framework
    end

    # @return [Boolean] Whether the target defines a "module"
    #         (and thus will need a module map and umbrella header).
    #
    # @note   Static library targets can temporarily opt in to this behavior by setting
    #         `DEFINES_MODULE = YES` in their specification's `pod_target_xcconfig`.
    #
    def defines_module?
      return @defines_module if defined?(@defines_module)
      return @defines_module = true if uses_swift? || requires_frameworks?

      explicit_target_definitions = target_definitions.select { |td| td.dependencies.any? { |d| d.root_name == pod_name } }
      tds_by_answer = explicit_target_definitions.group_by { |td| td.build_pod_as_module?(pod_name) }

      if tds_by_answer.size > 1
        UI.warn "Unable to determine whether to build `#{label}` as a module due to a conflict " \
          "between the following target definitions:\n\t- #{tds_by_answer.map do |a, td|
                                                              "`#{td.to_sentence}` #{a ? "requires `#{label}` as a module" : "does not require `#{label}` as a module"}"
                                                            end.join("\n\t- ")}\n\n" \
          "Defaulting to skip building `#{label}` as a module."
      elsif tds_by_answer.keys.first == true || target_definitions.all? { |td| td.build_pod_as_module?(pod_name) }
        return @defines_module = true
      end

      @defines_module = non_test_specs.any? { |s| s.consumer(platform).pod_target_xcconfig['DEFINES_MODULE'] == 'YES' }
    end

    # @return [Array<Hash{Symbol=>String}>] An array of hashes where each hash represents a single script phase.
    #
    def script_phases
      spec_consumers.flat_map(&:script_phases)
    end

    # @return [Boolean] Whether the target contains any script phases.
    #
    def contains_script_phases?
      !script_phases.empty?
    end

    # @return [Boolean] Whether the target has any tests specifications.
    #
    def contains_test_specifications?
      !test_specs.empty?
    end

    # @return [Hash{String=>Array<FrameworkPaths>}] The vendored and non vendored framework paths this target
    #         depends upon keyed by spec name. For the root spec and subspecs the framework path of the target itself
    #         is included.
    #
    def framework_paths
      @framework_paths ||= begin
        file_accessors.each_with_object({}) do |file_accessor, hash|
          frameworks = file_accessor.vendored_dynamic_artifacts.map do |framework_path|
            relative_path_to_sandbox = framework_path.relative_path_from(sandbox.root)
            framework_source = "${PODS_ROOT}/#{relative_path_to_sandbox}"
            # Until this can be configured, assume the dSYM file uses the file name as the framework.
            # See https://github.com/CocoaPods/CocoaPods/issues/1698
            dsym_name = "#{framework_path.basename}.dSYM"
            dsym_path = Pathname.new("#{framework_path.dirname}/#{dsym_name}")
            dsym_source = if dsym_path.exist?
                            "${PODS_ROOT}/#{relative_path_to_sandbox}.dSYM"
                          end
            FrameworkPaths.new(framework_source, dsym_source)
          end
          if !file_accessor.spec.test_specification? && should_build? && requires_frameworks? && !static_framework?
            frameworks << FrameworkPaths.new(build_product_path('${BUILT_PRODUCTS_DIR}'))
          end
          hash[file_accessor.spec.name] = frameworks
        end
      end
    end

    # @return [Hash{String=>Array<String>}] The resource and resource bundle paths this target depends upon keyed by
    #         spec name.
    #
    def resource_paths
      @resource_paths ||= begin
        file_accessors.each_with_object({}) do |file_accessor, hash|
          resource_paths = file_accessor.resources.map { |res| "${PODS_ROOT}/#{res.relative_path_from(sandbox.project.path.dirname)}" }
          prefix = Pod::Target::BuildSettings::CONFIGURATION_BUILD_DIR_VARIABLE
          prefix = configuration_build_dir unless file_accessor.spec.test_specification?
          resource_bundle_paths = file_accessor.resource_bundles.keys.map { |name| "#{prefix}/#{name.shellescape}.bundle" }
          hash[file_accessor.spec.name] = resource_paths + resource_bundle_paths
        end
      end
    end

    # Returns the corresponding native product type to use given the test type.
    # This is primarily used when creating the native targets in order to produce the correct test bundle target
    # based on the type of tests included.
    #
    # @param  [Symbol] test_type
    #         The test type to map to provided by the test specification DSL.
    #
    # @return [Symbol] The native product type to use.
    #
    def product_type_for_test_type(test_type)
      case test_type
      when :unit
        :unit_test_bundle
      else
        raise Informative, "Unknown test type `#{test_type}`."
      end
    end

    # @return [Specification] The root specification for the target.
    #
    def root_spec
      specs.first.root
    end

    # @return [String] The name of the Pod that this target refers to.
    #
    def pod_name
      root_spec.name
    end

    # @return [Pathname] the absolute path of the LLVM module map file that
    #         defines the module structure for the compiler.
    #
    def module_map_path
      basename = "#{label}.modulemap"
      if requires_frameworks?
        super
      elsif file_accessors.any?(&:module_map)
        build_headers.root + product_module_name + basename
      else
        sandbox.public_headers.root + product_module_name + basename
      end
    end

    # @return [Pathname] the absolute path of the prefix header file.
    #
    def prefix_header_path
      support_files_dir + "#{label}-prefix.pch"
    end

    # @param  [String] bundle_name
    #         The name of the bundle product, which is given by the +spec+.
    #
    # @return [String] The derived name of the resource bundle target.
    #
    def resources_bundle_target_label(bundle_name)
      "#{label}-#{bundle_name}"
    end

    # @param  [Specification] test_spec
    #         The test spec to use for producing the test label.
    #
    # @return [String] The derived name of the test target.
    #
    def test_target_label(test_spec)
      "#{label}-#{test_spec.test_type.capitalize}-#{test_spec.name.split('/')[1..-1].join('-')}"
    end

    # @param  [Specification] test_spec
    #         The test spec this embed frameworks script path is for.
    #
    # @return [Pathname] The absolute path of the copy resources script for the given test type.
    #
    def copy_resources_script_path_for_test_spec(test_spec)
      support_files_dir + "#{test_target_label(test_spec)}-resources.sh"
    end

    # @param  [Specification] test_spec
    #         The test spec this embed frameworks script path is for.
    #
    # @return [Pathname] The absolute path of the embed frameworks script for the given test type.
    #
    def embed_frameworks_script_path_for_test_spec(test_spec)
      support_files_dir + "#{test_target_label(test_spec)}-frameworks.sh"
    end

    # @param  [Specification] test_spec
    #         The test spec this Info.plist path is for.
    #
    # @return [Pathname] The absolute path of the Info.plist for the given test type.
    #
    def info_plist_path_for_test_spec(test_spec)
      support_files_dir + "#{test_target_label(test_spec)}-Info.plist"
    end

    # @param  [Specification] test_spec
    #         The test spec this prefix header path is for.
    #
    # @return [Pathname] the absolute path of the prefix header file for the given test type.
    #
    def prefix_header_path_for_test_spec(test_spec)
      support_files_dir + "#{test_target_label(test_spec)}-prefix.pch"
    end

    # @return [Array<String>] The names of the Pods on which this target
    #         depends.
    #
    def dependencies
      spec_consumers.flat_map do |consumer|
        consumer.dependencies.map { |dep| Specification.root_name(dep.name) }
      end.uniq
    end

    # @return [Array<PodTarget>] the recursive targets that this target has a
    #         dependency upon.
    #
    def recursive_dependent_targets
      @recursive_dependent_targets ||= _add_recursive_dependent_targets(Set.new).delete(self).to_a
    end

    def _add_recursive_dependent_targets(set)
      dependent_targets.each do |target|
        target._add_recursive_dependent_targets(set) if set.add?(target)
      end

      set
    end
    protected :_add_recursive_dependent_targets

    # @param [Specification] test_spec
    #        the test spec to scope dependencies for
    #
    # @return [Array<PodTarget>] the recursive targets that this target has a
    #         test dependency upon.
    #
    def recursive_test_dependent_targets(test_spec)
      @recursive_test_dependent_targets ||= {}
      @recursive_test_dependent_targets[test_spec] ||= _add_recursive_test_dependent_targets(test_spec, Set.new).to_a
    end

    def _add_recursive_test_dependent_targets(test_spec, set)
      raise ArgumentError, 'Must give a test spec' unless test_spec
      return unless dependent_targets = test_dependent_targets_by_spec_name[test_spec.name]

      dependent_targets.each do |target|
        target._add_recursive_dependent_targets(set) if set.add?(target)
      end

      set
    end
    private :_add_recursive_test_dependent_targets

    # @param [Specification] test_spec
    #        the test spec to scope dependencies for
    #
    # @return [Array<PodTarget>] the canonical list of dependent targets this target has a dependency upon.
    #         This list includes the target itself as well as its recursive dependent and test dependent targets.
    #
    def dependent_targets_for_test_spec(test_spec)
      [self, *recursive_dependent_targets, *recursive_test_dependent_targets(test_spec)].uniq
    end

    # Checks if warnings should be inhibited for this pod.
    #
    # @return [Bool]
    #
    def inhibit_warnings?
      return @inhibit_warnings if defined? @inhibit_warnings
      whitelists = target_definitions.map do |target_definition|
        target_definition.inhibits_warnings_for_pod?(root_spec.name)
      end.uniq

      if whitelists.empty?
        @inhibit_warnings = false
        false
      elsif whitelists.count == 1
        @inhibit_warnings = whitelists.first
        whitelists.first
      else
        UI.warn "The pod `#{pod_name}` is linked to different targets " \
          "(#{target_definitions.map(&:label)}), which contain different " \
          'settings to inhibit warnings. CocoaPods does not currently ' \
          'support different settings and will fall back to your preference ' \
          'set in the root target definition.'
        podfile.root_target_definitions.first.inhibits_warnings_for_pod?(root_spec.name)
      end
    end

    # @param  [String] dir
    #         The directory (which might be a variable) relative to which
    #         the returned path should be. This must be used if the
    #         $CONFIGURATION_BUILD_DIR is modified.
    #
    # @return [String] The absolute path to the configuration build dir
    #
    def configuration_build_dir(dir = BuildSettings::CONFIGURATION_BUILD_DIR_VARIABLE)
      "#{dir}/#{label}"
    end

    # @param  [String] dir
    #         @see #configuration_build_dir
    #
    # @return [String] The absolute path to the build product
    #
    def build_product_path(dir = BuildSettings::CONFIGURATION_BUILD_DIR_VARIABLE)
      "#{configuration_build_dir(dir)}/#{product_name}"
    end

    # @return [String] The source path of the root for this target relative to `$(PODS_ROOT)`
    #
    def pod_target_srcroot
      "${PODS_ROOT}/#{sandbox.pod_dir(pod_name).relative_path_from(sandbox.root)}"
    end

    # @return [String] The version associated with this target
    #
    def version
      version = root_spec.version
      [version.major, version.minor, version.patch].join('.')
    end

    # @param [Boolean] include_dependent_targets_for_test_spec
    #        whether to include header search paths for test dependent targets
    #
    # @param [Boolean] include_private_headers
    #        whether to include header search paths for private headers of this
    #        target
    #
    # @return [Array<String>] The set of header search paths this target uses.
    #
    def header_search_paths(include_dependent_targets_for_test_spec: nil, include_private_headers: true)
      header_search_paths = []
      header_search_paths.concat(build_headers.search_paths(platform, nil, false)) if include_private_headers
      header_search_paths.concat(sandbox.public_headers.search_paths(platform, pod_name, uses_modular_headers?))
      dependent_targets = recursive_dependent_targets
      dependent_targets += recursive_test_dependent_targets(include_dependent_targets_for_test_spec) if include_dependent_targets_for_test_spec
      dependent_targets.uniq.each do |dependent_target|
        header_search_paths.concat(sandbox.public_headers.search_paths(platform, dependent_target.pod_name, defines_module? && dependent_target.uses_modular_headers?(false)))
      end
      header_search_paths.uniq
    end

    protected

    # Returns whether the pod target should use modular headers.
    #
    # @param  [Boolean] only_if_defines_modules
    #         whether the use of modular headers should require the target to define a module
    #
    # @note  This must return false when a pod has a `header_mappings_dir` or `header_dir`,
    #        as that allows the spec to customize the header structure, and
    #        therefore it might not be expecting the module name to be prepended
    #        to imports at all.
    #
    def uses_modular_headers?(only_if_defines_modules = true)
      return false if only_if_defines_modules && !defines_module?
      spec_consumers.none?(&:header_mappings_dir) && spec_consumers.none?(&:header_dir)
    end

    private

    def create_build_settings
      BuildSettings::PodTargetSettings.new(self)
    end
  end
end
