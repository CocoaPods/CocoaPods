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
    # @param [Platform] platform @see #platform
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

    # @return [String] the Swift version for the target. If the pod author has provided a swift version
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

      return @should_build = true if contains_script_phases?

      source_files = file_accessors.flat_map(&:source_files)
      source_files -= file_accessors.flat_map(&:headers)
      @should_build = !source_files.empty?
    end

    # @return [Array<Specification::Consumer>] the specification consumers for
    #         the target.
    #
    def spec_consumers
      specs.map { |spec| spec.consumer(platform) }
    end

    # @return [Boolean] Whether the target uses Swift code.
    #
    def uses_swift?
      return @uses_swift if defined? @uses_swift
      @uses_swift = begin
        file_accessors.any? do |file_accessor|
          file_accessor.source_files.any? { |sf| sf.extname == '.swift' }
        end
      end
    end

    # @return [Boolean] Whether the target should build a static framework.
    #
    def static_framework?
      root_spec.static_framework
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
      return @defines_module = true if target_definitions.any? { |td| td.build_pod_as_module?(pod_name) }

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

    # @return [Array<Symbol>] All of the test supported types within this target.
    #
    def supported_test_types
      test_specs.map(&:test_type).uniq
    end

    # Returns the framework paths associated with this target. By default all paths include the framework paths
    # that are part of test specifications.
    #
    # @param  [Boolean] include_test_spec_paths
    #         Whether to include framework paths from test specifications or not.
    #
    # @return [Array<Hash{Symbol => [String]}>] The vendored and non vendored framework paths
    #         this target depends upon.
    #
    def framework_paths(include_test_spec_paths = true)
      @framework_paths ||= {}
      return @framework_paths[include_test_spec_paths] if @framework_paths.key?(include_test_spec_paths)
      @framework_paths[include_test_spec_paths] = begin
        accessors = file_accessors
        accessors = accessors.reject { |a| a.spec.test_specification? } unless include_test_spec_paths
        frameworks = []
        accessors.flat_map(&:vendored_dynamic_artifacts).map do |framework_path|
          relative_path_to_sandbox = framework_path.relative_path_from(sandbox.root)
          framework = { :name => framework_path.basename.to_s,
                        :input_path => "${PODS_ROOT}/#{relative_path_to_sandbox}",
                        :output_path => "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/#{framework_path.basename}" }
          # Until this can be configured, assume the dSYM file uses the file name as the framework.
          # See https://github.com/CocoaPods/CocoaPods/issues/1698
          dsym_name = "#{framework_path.basename}.dSYM"
          dsym_path = Pathname.new("#{framework_path.dirname}/#{dsym_name}")
          if dsym_path.exist?
            framework[:dsym_name] = dsym_name
            framework[:dsym_input_path] = "${PODS_ROOT}/#{relative_path_to_sandbox}.dSYM"
            framework[:dsym_output_path] = "${DWARF_DSYM_FOLDER_PATH}/#{dsym_name}"
          end
          frameworks << framework
        end
        if should_build? && requires_frameworks? && !static_framework?
          frameworks << { :name => product_name,
                          :input_path => build_product_path('${BUILT_PRODUCTS_DIR}'),
                          :output_path => "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/#{product_name}" }
        end
        frameworks
      end
    end

    # Returns the resource paths associated with this target. By default all paths include the resource paths
    # that are part of test specifications.
    #
    # @param  [Boolean] include_test_spec_paths
    #         Whether to include resource paths from test specifications or not.
    #
    # @return [Array<String>] The resource and resource bundle paths this target depends upon.
    #
    def resource_paths(include_test_spec_paths = true)
      @resource_paths ||= {}
      return @resource_paths[include_test_spec_paths] if @resource_paths.key?(include_test_spec_paths)
      @resource_paths[include_test_spec_paths] = begin
        accessors = file_accessors
        accessors = accessors.reject { |a| a.spec.test_specification? } unless include_test_spec_paths
        resource_paths = accessors.flat_map do |accessor|
          accessor.resources.flat_map { |res| "${PODS_ROOT}/#{res.relative_path_from(sandbox.project.path.dirname)}" }
        end
        resource_bundles = accessors.flat_map do |accessor|
          prefix = BuildSettings::CONFIGURATION_BUILD_DIR_VARIABLE
          prefix = configuration_build_dir unless accessor.spec.test_specification?
          accessor.resource_bundles.keys.map { |name| "#{prefix}/#{name.shellescape}.bundle" }
        end
        resource_paths + resource_bundles
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

    # Returns the corresponding test type given the product type.
    #
    # @param  [Symbol] product_type
    #         The product type to map to a test type.
    #
    # @return [Symbol] The native product type to use.
    #
    def test_type_for_product_type(product_type)
      case product_type
      when :unit_test_bundle
        :unit
      else
        raise Informative, "Unknown product type `#{product_type}`."
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

    # @param  [String] bundle_name
    #         The name of the bundle product, which is given by the +spec+.
    #
    # @return [String] The derived name of the resource bundle target.
    #
    def resources_bundle_target_label(bundle_name)
      "#{label}-#{bundle_name}"
    end

    # @param  [Symbol] test_type
    #         The test type to use for producing the test label.
    #
    # @return [String] The derived name of the test target.
    #
    def test_target_label(test_type)
      "#{label}-#{test_type.capitalize}-Tests"
    end

    # @param  [Symbol] test_type
    #         The test type to use for producing the test label.
    #
    # @return [String] The label of the app host label to use given the platform and test type.
    #
    def app_host_label(test_type)
      "AppHost-#{Platform.string_name(platform.symbolic_name)}-#{test_type.capitalize}-Tests"
    end

    # @param  [Symbol] test_type
    #         The test type this Info.plist path is for.
    #
    # @return [Pathname] The absolute path of the Info.plist to use for an app host.
    #
    def app_host_info_plist_path_for_test_type(test_type)
      support_files_dir + "#{app_host_label(test_type)}-Info.plist"
    end

    # @param  [Symbol] test_type
    #         The test type this embed frameworks script path is for.
    #
    # @return [Pathname] The absolute path of the copy resources script for the given test type.
    #
    def copy_resources_script_path_for_test_type(test_type)
      support_files_dir + "#{test_target_label(test_type)}-resources.sh"
    end

    # @param  [Symbol] test_type
    #         The test type this embed frameworks script path is for.
    #
    # @return [Pathname] The absolute path of the embed frameworks script for the given test type.
    #
    def embed_frameworks_script_path_for_test_type(test_type)
      support_files_dir + "#{test_target_label(test_type)}-frameworks.sh"
    end

    # @param  [Symbol] test_type
    #         The test type this Info.plist path is for.
    #
    # @return [Pathname] The absolute path of the Info.plist for the given test type.
    #
    def info_plist_path_for_test_type(test_type)
      support_files_dir + "#{test_target_label(test_type)}-Info.plist"
    end

    # @return [Pathname] the absolute path of the prefix header file.
    #
    def prefix_header_path
      support_files_dir + "#{label}-prefix.pch"
    end

    # @param  [Symbol] test_type
    #         The test type prefix header path is for.
    #
    # @return [Pathname] the absolute path of the prefix header file for the given test type.
    #
    def prefix_header_path_for_test_type(test_type)
      support_files_dir + "#{test_target_label(test_type)}-prefix.pch"
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
      @recursive_dependent_targets ||= begin
        targets = dependent_targets.clone

        targets.each do |target|
          target.dependent_targets.each do |t|
            targets.push(t) unless t == self || targets.include?(t)
          end
        end

        targets
      end
    end

    # @return [Array<PodTarget>] the recursive targets that this target has a
    #         test dependency upon.
    #
    def recursive_test_dependent_targets
      @recursive_test_dependent_targets ||= begin
        targets = test_dependent_targets_by_spec_name.values.flatten.clone

        targets.each do |target|
          target.test_dependent_targets_by_spec_name.values.flatten.each do |t|
            targets.push(t) unless t == self || targets.include?(t)
          end
        end

        targets
      end
    end

    # @return [Array<PodTarget>] the canonical list of dependent targets this target has a dependency upon.
    #         This list includes the target itself as well as its recursive dependent and test dependent targets.
    #
    def all_dependent_targets
      [self, *recursive_dependent_targets, *recursive_test_dependent_targets].uniq
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

    # @param [Boolean] include_test_dependent_targets
    #        whether to include header search paths for test dependent targets
    #
    # @return [Array<String>] The set of header search paths this target uses.
    #
    def header_search_paths(include_test_dependent_targets = false)
      header_search_paths = []
      header_search_paths.concat(build_headers.search_paths(platform, nil, false))
      header_search_paths.concat(sandbox.public_headers.search_paths(platform, pod_name, uses_modular_headers?))
      dependent_targets = recursive_dependent_targets
      dependent_targets += recursive_test_dependent_targets if include_test_dependent_targets
      dependent_targets.each do |dependent_target|
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
      BuildSettings::PodTargetSettings.new(self, false)
    end
  end
end
