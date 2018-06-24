# frozen_string_literal: true

module Pod
  class Target
    # @since 1.5.0
    class BuildSettings
      #-------------------------------------------------------------------------#

      # @!group Constants

      # @return [Set<String>]
      #   The build settings that should be treated as arrays, rather than strings.
      #
      PLURAL_SETTINGS = %w(
        ALTERNATE_PERMISSIONS_FILES
        ARCHS
        BUILD_VARIANTS
        EXCLUDED_SOURCE_FILE_NAMES
        FRAMEWORK_SEARCH_PATHS
        GCC_PREPROCESSOR_DEFINITIONS
        GCC_PREPROCESSOR_DEFINITIONS_NOT_USED_IN_PRECOMPS
        HEADER_SEARCH_PATHS
        INFOPLIST_PREPROCESSOR_DEFINITIONS
        LD_RUNPATH_SEARCH_PATHS
        LIBRARY_SEARCH_PATHS
        OTHER_CFLAGS
        OTHER_CPLUSPLUSFLAGS
        OTHER_LDFLAGS
        OTHER_SWIFT_FLAGS
        REZ_SEARCH_PATHS
        SECTORDER_FLAGS
        SWIFT_ACTIVE_COMPILATION_CONDITIONS
        SWIFT_INCLUDE_PATHS
        WARNING_CFLAGS
        WARNING_LDFLAGS
      ).to_set.freeze

      # @return [String]
      #   The variable for the configuration build directory used when building pod targets.
      #
      CONFIGURATION_BUILD_DIR_VARIABLE = '${PODS_CONFIGURATION_BUILD_DIR}'.freeze

      #-------------------------------------------------------------------------#

      # @!group DSL

      # Creates a method that calculates a part of the build settings for the {#target}.
      #
      # @!visibility private
      #
      # @param [Symbol,String] method_name
      #   The name of the method to define
      #
      # @param [Boolean] build_setting
      #   Whether the method name should be added (upcased) to {.build_setting_names}
      #
      # @param [Boolean] memoized
      #   Whether the method should be memoized
      #
      # @param [Boolean] sorted
      #   Whether the return value should be sorted
      #
      # @param [Boolean] uniqued
      #   Whether the return value should be uniqued
      #
      # @param [Boolean] compacted
      #   Whether the return value should be compacted
      #
      # @param [Boolean] frozen
      #   Whether the return value should be frozen
      #
      # @param [Boolean, Symbol] from_search_paths_aggregate_targets
      #   If truthy, the method from {Aggregate} that should be used to concatenate build settings from
      #   {::Pod::AggregateTarget#search_paths_aggregate_target}
      #
      # @param [Symbol] from_pod_targets_to_link
      #   If truthy, the `_to_import` values from `BuildSettings#pod_targets_to_link` will be concatenated
      #
      # @param [Block] implementation
      #
      # @macro  [attach] define_build_settings_method
      #         @!method $1
      #
      #         The `$1` build setting for the {#target}.
      #
      #         The return value from this method will be: `${1--1}`.
      #
      def self.define_build_settings_method(method_name, build_setting: false,
                                            memoized: false, sorted: false, uniqued: false, compacted: false, frozen: true,
                                            from_search_paths_aggregate_targets: false, from_pod_targets_to_link: false,
                                            &implementation)

        memoized_key = "#{self}##{method_name}".freeze

        (@build_settings_names ||= Set.new) << method_name.to_s.upcase if build_setting

        raw_method_name = :"_raw_#{method_name}"
        define_method(raw_method_name, &implementation)
        private(raw_method_name)

        dup_before_freeze = frozen && (from_pod_targets_to_link || from_search_paths_aggregate_targets || uniqued || sorted)

        define_method(method_name) do
          if memoized
            @__memoized ||= {}
            retval = @__memoized.fetch(memoized_key, :not_found)
            return retval if :not_found != retval
          end

          retval = send(raw_method_name)
          if retval.nil?
            @__memoized[memoized_key] = retval if memoized
            return
          end

          retval = retval.dup if dup_before_freeze && retval.frozen?

          retval.concat(pod_targets_to_link.flat_map { |pod_target| pod_target.build_settings.public_send("#{method_name}_to_import") }) if from_pod_targets_to_link
          retval.concat(search_paths_aggregate_target_pod_target_build_settings.flat_map(&from_search_paths_aggregate_targets)) if from_search_paths_aggregate_targets

          retval.compact! if compacted
          retval.uniq! if uniqued
          retval.sort! if sorted
          retval.freeze if frozen

          @__memoized[memoized_key] = retval if memoized

          retval
        end
      end
      private_class_method :define_build_settings_method

      class << self
        #-------------------------------------------------------------------------#

        # @!group Public API

        # @return [Set<String>] a set of all the build settings names that will
        # be present in the #xcconfig
        #
        attr_reader :build_settings_names
      end

      #-------------------------------------------------------------------------#

      # @!group Public API

      # @return [Target]
      #  The target this build settings object is generating build settings for
      #
      attr_reader :target

      # Initialize a new instance
      #
      # @param [Target] target
      #   see {#target}
      #
      def initialize(target)
        @target = target
      end

      # @return [Xcodeproj::Config]
      define_build_settings_method :xcconfig, :memoized => true do
        settings = add_inherited_to_plural(to_h)
        Xcodeproj::Config.new(settings)
      end

      # @return [Xcodeproj::Config]
      #
      # @!visibility private
      # @see #__clear__
      # @see #xcconfig
      def generate
        __clear__
        xcconfig
      end

      # Saves the generated xcconfig to the given path
      #
      # @return [Xcodeproj::Config]
      #
      # @see #xcconfig
      #
      # @param [String,Pathname] path
      #   The path the xcconfig will be saved to
      #
      def save_as(path)
        xcconfig.save_as(path)
      end

      #-------------------------------------------------------------------------#

      # @!group Paths

      # @return [String]
      define_build_settings_method :pods_build_dir, :build_setting => true do
        '${BUILD_DIR}'
      end

      # @return [String]
      define_build_settings_method :pods_configuration_build_dir, :build_setting => true do
        '${PODS_BUILD_DIR}/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)'
      end

      #-------------------------------------------------------------------------#

      # @!group Code Signing

      # @return [String]
      define_build_settings_method :code_sign_identity, :build_setting => true do
        return unless target.requires_frameworks?
        return unless target.platform.to_sym == :osx
        ''
      end

      #-------------------------------------------------------------------------#

      # @!group Frameworks

      # @return [Array<String>]
      define_build_settings_method :frameworks do
        []
      end

      # @return [Array<String>]
      define_build_settings_method :weak_frameworks do
        []
      end

      # @return [Array<String>]
      define_build_settings_method :framework_search_paths, :build_setting => true, :memoized => true do
        framework_search_paths_to_import_developer_frameworks(frameworks)
      end

      # @param [Array<String>] frameworks
      #   The list of framework names
      #
      # @return [Array<String>]
      #   the `FRAMEWORK_SEARCH_PATHS` needed to import developer frameworks
      def framework_search_paths_to_import_developer_frameworks(frameworks)
        if frameworks.include?('XCTest') || frameworks.include?('SenTestingKit')
          %w[ $(PLATFORM_DIR)/Developer/Library/Frameworks ]
        else
          []
        end
      end

      #-------------------------------------------------------------------------#

      # @!group Libraries

      # @return [Array<String>]
      define_build_settings_method :libraries do
        []
      end

      #-------------------------------------------------------------------------#

      # @!group Clang

      # @return [Array<String>]
      define_build_settings_method :gcc_preprocessor_definitions, :build_setting => true do
        %w( COCOAPODS=1 )
      end

      # @return [Array<String>]
      define_build_settings_method :other_cflags, :build_setting => true, :memoized => true do
        module_map_files.map { |f| "-fmodule-map-file=#{f}" }
      end

      # @return [Array<String>]
      define_build_settings_method :module_map_files do
        []
      end

      #-------------------------------------------------------------------------#

      # @!group Swift

      # @return [Boolean]
      #   Whether `OTHER_SWIFT_FLAGS` should be generated when the target
      #   does not use swift.
      #
      def other_swift_flags_without_swift?
        false
      end

      # @return [Array<String>]
      define_build_settings_method :other_swift_flags, :build_setting => true, :memoized => true do
        return unless target.uses_swift? || other_swift_flags_without_swift?
        flags = %w(-D COCOAPODS)
        flags.concat module_map_files.flat_map { |f| ['-Xcc', "-fmodule-map-file=#{f}"] }
        flags
      end

      #-------------------------------------------------------------------------#

      # @!group Linking

      # @return [Boolean]
      define_build_settings_method :requires_objc_linker_flag? do
        false
      end

      # @return [Boolean]
      define_build_settings_method :requires_fobjc_arc? do
        false
      end

      # @return [Array<String>]
      #   the `LD_RUNPATH_SEARCH_PATHS` needed for dynamically linking the {#target}
      #
      # @param [Boolean] requires_host_target
      #
      # @param [Boolean] test_bundle
      #
      def _ld_runpath_search_paths(requires_host_target: false, test_bundle: false)
        if target.platform.symbolic_name == :osx
          ["'@executable_path/../Frameworks'",
           test_bundle ? "'@loader_path/../Frameworks'" : "'@loader_path/Frameworks'"]
        else
          paths = [
            "'@executable_path/Frameworks'",
            "'@loader_path/Frameworks'",
          ]
          paths << "'@executable_path/../../Frameworks'" if requires_host_target
          paths
        end
      end
      private :_ld_runpath_search_paths

      # @return [Array<String>]
      define_build_settings_method :other_ldflags, :build_setting => true, :memoized => true do
        ld_flags = []
        ld_flags << '-ObjC' if requires_objc_linker_flag?
        if requires_fobjc_arc?
          ld_flags << '-fobjc-arc'
        end
        libraries.each { |l| ld_flags << %(-l"#{l}") }
        frameworks.each { |f| ld_flags << '-framework' << %("#{f}") }
        weak_frameworks.each { |f| ld_flags << '-weak_framework' << %("#{f}") }
        ld_flags
      end

      #-------------------------------------------------------------------------#

      # @!group Private Methods

      # Clears all memoized settings.
      # @!visibility private
      # @return [Void]
      def __clear__
        @__memoized = nil
      end

      private

      # @return [Hash<String => String|Array<String>>]
      def to_h
        hash = {}
        self.class.build_settings_names.sort.each do |setting|
          hash[setting] = public_send(setting.downcase)
        end
        hash
      end

      # @return [Hash<String => String>]
      def add_inherited_to_plural(hash)
        Hash[hash.map do |key, value|
          next [key, '$(inherited)'] if value.nil?
          if PLURAL_SETTINGS.include?(key)
            raise ArgumentError, "#{key} is a plural setting, cannot have #{value.inspect} as its value" unless value.is_a? Array

            value = "$(inherited) #{quote_array(value)}"
          else
            raise ArgumentError, "#{key} is not a plural setting, cannot have #{value.inspect} as its value" unless value.is_a? String
          end

          [key, value]
        end]
      end

      # @return [Array<String>]
      #
      # @param  [Array<String>] array
      #
      def quote_array(array)
        array.map do |element|
          case element
          when /\A([\w-]+?)=(.+)\z/
            key = Regexp.last_match(1)
            value = Regexp.last_match(2)
            value = %("#{value}") if value =~ /[^\w\d]/
            %(#{key}=#{value})
          when /[\$\[\]\ ]/
            %("#{element}")
          else
            element
          end
        end.join(' ')
      end

      # @param [Hash] xcconfig_values_by_consumer_by_key
      #
      # @param [#to_s] attribute
      #   The name of the attribute being merged
      #
      # @return [Hash<String, String>]
      #
      def merged_xcconfigs(xcconfig_values_by_consumer_by_key, attribute)
        xcconfig_values_by_consumer_by_key.each_with_object({}) do |(key, values_by_consumer), xcconfig|
          uniq_values = values_by_consumer.values.uniq
          values_are_bools = uniq_values.all? { |v| v =~ /\A(yes|no)\z/i }
          if values_are_bools
            # Boolean build settings
            if uniq_values.count > 1
              UI.warn "Can't merge #{attribute} for pod targets: " \
                "#{values_by_consumer.keys.map(&:name)}. Boolean build " \
                "setting #{key} has different values."
            else
              xcconfig[key] = uniq_values.first
            end
          elsif PLURAL_SETTINGS.include? key
            # Plural build settings
            xcconfig[key] = uniq_values.join(' ')
          elsif uniq_values.count > 1
            # Singular build settings
            UI.warn "Can't merge #{attribute} for pod targets: " \
              "#{values_by_consumer.keys.map(&:name)}. Singular build " \
              "setting #{key} has different values."
          else
            xcconfig[key] = uniq_values.first
          end
        end
      end

      # Filters out pod targets whose `specs` are a subset of
      # another target's.
      #
      # @param [Array<PodTarget>] pod_targets
      #
      # @return [Array<PodTarget>]
      #
      def select_maximal_pod_targets(pod_targets)
        subset_targets = []
        pod_targets.uniq.combination(2) do |a, b|
          if (a.specs - b.specs).empty?
            subset_targets << a
          elsif (b.specs - a.specs).empty?
            subset_targets << b
          end
        end
        pod_targets - subset_targets
      end

      # A subclass that generates build settings for a {PodTarget}
      class PodTargetSettings < BuildSettings
        #-------------------------------------------------------------------------#

        # @!group Public API

        # @see BuildSettings.build_settings_names
        def self.build_settings_names
          @build_settings_names | BuildSettings.build_settings_names
        end

        # @return [Boolean]
        #   whether settings are being generated for a test bundle
        #
        attr_reader :test_xcconfig
        alias test_xcconfig? test_xcconfig

        # @return [Specification]
        #   The test specification these build settings are for or `nil`.
        #
        attr_reader :test_spec

        # Initializes a new instance
        #
        # @param [PodTarget] target
        #   see {#target}
        #
        # @param [Specification] test_spec
        #  see {#test_spec}
        #
        def initialize(target, test_spec = nil)
          super(target)
          @test_spec = test_spec
          @test_xcconfig = !test_spec.nil?
        end

        # @return [Xcodeproj::Xconfig]
        define_build_settings_method :xcconfig, :memoized => true do
          xcconfig = super()
          xcconfig.merge(merged_pod_target_xcconfigs)
        end

        #-------------------------------------------------------------------------#

        # @!group Paths

        # @return [String]
        define_build_settings_method :pods_root, :build_setting => true do
          '${SRCROOT}'
        end

        # @return [String]
        define_build_settings_method :pods_target_srcroot, :build_setting => true do
          target.pod_target_srcroot
        end

        #-------------------------------------------------------------------------#

        # @!group Frameworks

        # @return [Array<String>]
        define_build_settings_method :consumer_frameworks, :memoized => true do
          spec_consumers.flat_map(&:frameworks)
        end

        # @return [Array<String>]
        define_build_settings_method :frameworks, :memoized => true, :sorted => true, :uniqued => true do
          return [] if (!target.requires_frameworks? || target.static_framework?) && !test_xcconfig?

          frameworks = vendored_dynamic_frameworks.map { |l| File.basename(l, '.framework') }
          frameworks.concat vendored_static_frameworks.map { |l| File.basename(l, '.framework') } unless test_xcconfig?
          frameworks.concat consumer_frameworks
          frameworks.concat dependent_targets.flat_map { |pt| pt.build_settings.dynamic_frameworks_to_import }
          frameworks.concat dependent_targets.flat_map { |pt| pt.build_settings.static_frameworks_to_import } if test_xcconfig?
          frameworks
        end

        # @return [Array<String>]
        define_build_settings_method :static_frameworks_to_import, :memoized => true do
          static_frameworks_to_import = []
          static_frameworks_to_import.concat vendored_static_frameworks.map { |f| File.basename(f, '.framework') } unless target.should_build? && target.requires_frameworks? && !target.static_framework?
          static_frameworks_to_import << target.product_basename if target.should_build? && target.requires_frameworks? && target.static_framework?
          static_frameworks_to_import
        end

        # @return [Array<String>]
        define_build_settings_method :dynamic_frameworks_to_import, :memoized => true do
          dynamic_frameworks_to_import = vendored_dynamic_frameworks.map { |f| File.basename(f, '.framework') }
          dynamic_frameworks_to_import << target.product_basename if target.should_build? && target.requires_frameworks? && !target.static_framework?
          dynamic_frameworks_to_import.concat consumer_frameworks
          dynamic_frameworks_to_import
        end

        # @return [Array<String>]
        define_build_settings_method :weak_frameworks, :memoized => true do
          return [] if (!target.requires_frameworks? || target.static_framework?) && !test_xcconfig?

          weak_frameworks = spec_consumers.flat_map(&:weak_frameworks)
          weak_frameworks.concat dependent_targets.flat_map { |pt| pt.build_settings.weak_frameworks_to_import }
          weak_frameworks
        end

        # @return [Array<String>]
        define_build_settings_method :frameworks_to_import, :memoized => true, :sorted => true, :uniqued => true do
          static_frameworks_to_import + dynamic_frameworks_to_import
        end

        # @return [Array<String>]
        define_build_settings_method :weak_frameworks_to_import, :memoized => true, :sorted => true, :uniqued => true do
          []
        end

        # @return [Array<String>]
        define_build_settings_method :framework_search_paths, :build_setting => true, :memoized => true, :sorted => true, :uniqued => true do
          paths = super().dup
          paths.concat dependent_targets.flat_map { |t| t.build_settings.framework_search_paths_to_import }
          paths.concat framework_search_paths_to_import
          paths.delete(target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE)) unless test_xcconfig?
          paths
        end

        # @return [Array<String>]
        define_build_settings_method :vendored_framework_search_paths, :memoized => true do
          file_accessors.flat_map(&:vendored_frameworks).map { |f| File.join '${PODS_ROOT}', f.dirname.relative_path_from(target.sandbox.root) }
        end

        # @return [Array<String>]
        define_build_settings_method :framework_search_paths_to_import, :memoized => true do
          paths = framework_search_paths_to_import_developer_frameworks(consumer_frameworks)
          paths.concat vendored_framework_search_paths
          return paths unless target.requires_frameworks? && target.should_build?

          paths + [target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE)]
        end

        # @return [Array<String>]
        define_build_settings_method :vendored_static_frameworks, :memoized => true do
          file_accessors.flat_map(&:vendored_static_frameworks)
        end

        # @return [Array<String>]
        define_build_settings_method :vendored_dynamic_frameworks, :memoized => true do
          file_accessors.flat_map(&:vendored_dynamic_frameworks)
        end

        #-------------------------------------------------------------------------#

        # @!group Libraries

        # @return [Array<String>]
        define_build_settings_method :libraries, :memoized => true, :sorted => true, :uniqued => true do
          return [] if (!target.requires_frameworks? || target.static_framework?) && !test_xcconfig?

          libraries = libraries_to_import.dup
          libraries.concat dependent_targets.flat_map { |pt| pt.build_settings.dynamic_libraries_to_import }
          libraries.concat dependent_targets.flat_map { |pt| pt.build_settings.static_libraries_to_import } if test_xcconfig?
          libraries
        end

        # @return [Array<String>]
        define_build_settings_method :static_libraries_to_import, :memoized => true do
          static_libraries_to_import = vendored_static_libraries.map { |l| File.basename(l, l.extname).sub(/\Alib/, '') }
          static_libraries_to_import << target.product_basename if target.should_build? && !target.requires_frameworks?
          static_libraries_to_import
        end

        # @return [Array<String>]
        define_build_settings_method :dynamic_libraries_to_import, :memoized => true do
          vendored_dynamic_libraries.map { |l| File.basename(l, l.extname).sub(/\Alib/, '') } +
          spec_consumers.flat_map(&:libraries)
        end

        # @return [Array<String>]
        define_build_settings_method :libraries_to_import, :memoized => true, :sorted => true, :uniqued => true do
          static_libraries_to_import + dynamic_libraries_to_import
        end

        # @return [Array<String>]
        define_build_settings_method :library_search_paths, :build_setting => true, :memoized => true, :sorted => true, :uniqued => true do
          return [] if (!target.requires_frameworks? || target.static_framework?) && !test_xcconfig?

          vendored = library_search_paths_to_import.dup
          vendored.concat dependent_targets.flat_map { |t| t.build_settings.vendored_dynamic_library_search_paths }
          if test_xcconfig?
            vendored.concat dependent_targets.flat_map { |t| t.build_settings.library_search_paths_to_import }
          else
            vendored.delete(target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE))
          end
          vendored
        end

        # @return [Array<String>]
        define_build_settings_method :vendored_static_libraries, :memoized => true do
          file_accessors.flat_map(&:vendored_static_libraries)
        end

        # @return [Array<String>]
        define_build_settings_method :vendored_dynamic_libraries, :memoized => true do
          file_accessors.flat_map(&:vendored_dynamic_libraries)
        end

        # @return [Array<String>]
        define_build_settings_method :vendored_static_library_search_paths, :memoized => true do
          vendored_static_libraries.map { |f| File.join '${PODS_ROOT}', f.dirname.relative_path_from(target.sandbox.root) }
        end

        # @return [Array<String>]
        define_build_settings_method :vendored_dynamic_library_search_paths, :memoized => true do
          vendored_dynamic_libraries.map { |f| File.join '${PODS_ROOT}', f.dirname.relative_path_from(target.sandbox.root) }
        end

        # @return [Array<String>]
        define_build_settings_method :library_search_paths_to_import, :memoized => true do
          vendored_library_search_paths = vendored_static_library_search_paths + vendored_dynamic_library_search_paths
          return vendored_library_search_paths if target.requires_frameworks? || !target.should_build?

          vendored_library_search_paths << target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE)
        end

        #-------------------------------------------------------------------------#

        # @!group Clang

        # @return [Array<String>]
        define_build_settings_method :module_map_files, :memoized => true do
          dependent_targets.map { |t| t.build_settings.module_map_file_to_import }.compact.sort
        end

        # @return [Array<String>]
        define_build_settings_method :module_map_file_to_import, :memoized => true do
          return unless target.should_build?
          return if target.requires_frameworks?
          return unless target.defines_module?

          if target.uses_swift?
            # for swift, we have a custom build phase that copies in the module map, appending the .Swift module
            "${PODS_CONFIGURATION_BUILD_DIR}/#{target.label}/#{target.product_module_name}.modulemap"
          else
            "${PODS_ROOT}/#{target.module_map_path.relative_path_from(target.sandbox.root)}"
          end
        end

        # @return [Array<String>]
        define_build_settings_method :header_search_paths, :build_setting => true, :memoized => true, :sorted => true do
          target.header_search_paths(test_xcconfig?)
        end

        #-------------------------------------------------------------------------#

        # @!group Swift

        # @return [Array<String>]
        define_build_settings_method :other_swift_flags, :build_setting => true, :memoized => true do
          return unless target.uses_swift?
          flags = super()
          flags << '-suppress-warnings' if target.inhibit_warnings?
          if !target.requires_frameworks? && target.defines_module? && !test_xcconfig?
            flags.concat %w( -import-underlying-module -Xcc -fmodule-map-file=${SRCROOT}/${MODULEMAP_FILE} )
          end
          flags
        end

        # @return [Array<String>]
        define_build_settings_method :swift_include_paths, :build_setting => true, :memoized => true, :sorted => true, :uniqued => true do
          paths = dependent_targets.flat_map { |t| t.build_settings.swift_include_paths_to_import }
          paths.concat swift_include_paths_to_import if test_xcconfig?
          paths
        end

        # @return [Array<String>]
        define_build_settings_method :swift_include_paths_to_import, :memoized => true do
          return [] unless target.uses_swift? && !target.requires_frameworks?

          [target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE)]
        end

        #-------------------------------------------------------------------------#

        # @!group Linking

        # @return [Boolean] whether the `-ObjC` linker flag is required.
        #
        # @note this is only true when generating build settings for a test bundle
        #
        def requires_objc_linker_flag?
          test_xcconfig?
        end

        # @return [Boolean] whether the `-fobjc-arc` linker flag is required.
        #
        define_build_settings_method :requires_fobjc_arc?, :memoized => true do
          target.podfile.set_arc_compatibility_flag? &&
          file_accessors.any? { |fa| fa.spec_consumer.requires_arc? }
        end

        # @return [Array<String>]
        define_build_settings_method :ld_runpath_search_paths, :build_setting => true, :memoized => true do
          return unless test_xcconfig?
          _ld_runpath_search_paths(:test_bundle => true)
        end

        #-------------------------------------------------------------------------#

        # @!group Packaging

        # @return [String]
        define_build_settings_method :skip_install, :build_setting => true do
          'YES'
        end

        # @return [String]
        define_build_settings_method :product_bundle_identifier, :build_setting => true do
          'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
        end

        # @return [String]
        define_build_settings_method :configuration_build_dir, :build_setting => true, :memoized => true do
          return if test_xcconfig?
          target.configuration_build_dir(CONFIGURATION_BUILD_DIR_VARIABLE)
        end

        #-------------------------------------------------------------------------#

        # @!group Target Properties

        # @return [Array<PodTarget>]
        define_build_settings_method :dependent_targets, :memoized => true do
          select_maximal_pod_targets(
            if test_xcconfig?
              target.all_dependent_targets
            else
              target.recursive_dependent_targets
            end,
          )
        end

        # Returns the +pod_target_xcconfig+ for the pod target and its spec
        # consumers grouped by keys
        #
        # @return [Hash{String,Hash{Target,String}]
        #
        def pod_target_xcconfig_values_by_consumer_by_key
          spec_consumers.each_with_object({}) do |spec_consumer, hash|
            spec_consumer.pod_target_xcconfig.each do |k, v|
              (hash[k] ||= {})[spec_consumer] = v
            end
          end
        end

        # Merges the +pod_target_xcconfig+ for all pod targets into a
        # single hash and warns on conflicting definitions.
        #
        # @return [Hash{String, String}]
        #
        define_build_settings_method :merged_pod_target_xcconfigs, :memoized => true do
          merged_xcconfigs(pod_target_xcconfig_values_by_consumer_by_key, :pod_target_xcconfig)
        end

        # @return [Array<Sandbox::FileAccessor>]
        define_build_settings_method :file_accessors, :memoized => true do
          target.file_accessors.select { |fa| fa.spec.test_specification? == test_xcconfig? }
        end

        # @return [Array<Specification::Consumer>]
        define_build_settings_method :spec_consumers, :memoized => true do
          target.spec_consumers.select { |c| c.spec.test_specification? == test_xcconfig? }
        end

        #-------------------------------------------------------------------------#

        # @!group Private Methods

        def __clear__
          super
          dependent_targets.each { |pt| pt.build_settings.__clear__ }
        end
      end

      # A subclass that generates build settings for a `PodTarget`
      class AggregateTargetSettings < BuildSettings
        #-------------------------------------------------------------------------#

        # @!group Public API

        # @see BuildSettings.build_settings_names
        def self.build_settings_names
          @build_settings_names | BuildSettings.build_settings_names
        end

        # @return [String]
        #   The build configuration these settings will be used for
        attr_reader :configuration_name

        # Intializes a new instance
        #
        # @param [AggregateTarget] target
        #   see {#target}
        #
        # @param [String] configuration_name
        #   see {#configuration_name}
        #
        def initialize(target, configuration_name)
          super(target)
          @configuration_name = configuration_name
        end

        # @return [Xcodeproj::Config] xcconfig
        define_build_settings_method :xcconfig, :memoized => true do
          xcconfig = super()
          xcconfig.merge(merged_user_target_xcconfigs)
        end

        #-------------------------------------------------------------------------#

        # @!group Paths

        # @return [String]
        define_build_settings_method :pods_podfile_dir_path, :build_setting => true, :memoized => true do
          target.podfile_dir_relative_path
        end

        # @return [String]
        define_build_settings_method :pods_root, :build_setting => true, :memoized => true do
          target.relative_pods_root
        end

        #-------------------------------------------------------------------------#

        # @!group Frameworks

        # @return [Array<String>]
        define_build_settings_method :frameworks, :memoized => true, :sorted => true, :uniqued => true, :from_pod_targets_to_link => true, :from_search_paths_aggregate_targets => :dynamic_frameworks_to_import do
          []
        end

        # @return [Array<String>]
        define_build_settings_method :weak_frameworks, :memoized => true, :sorted => true, :uniqued => true, :from_pod_targets_to_link => true, :from_search_paths_aggregate_targets => :weak_frameworks do
          []
        end

        # @return [Array<String>]
        define_build_settings_method :framework_search_paths, :build_setting => true, :memoized => true, :sorted => true, :uniqued => true, :from_pod_targets_to_link => true, :from_search_paths_aggregate_targets => :framework_search_paths_to_import do
          []
        end

        #-------------------------------------------------------------------------#

        # @!group Libraries

        # @return [Array<String>]
        define_build_settings_method :libraries, :memoized => true, :sorted => true, :uniqued => true, :from_pod_targets_to_link => true, :from_search_paths_aggregate_targets => :dynamic_libraries_to_import do
          []
        end

        # @return [Array<String>]
        define_build_settings_method :library_search_paths, :build_setting => true, :memoized => true, :sorted => true, :uniqued => true, :from_pod_targets_to_link => true, :from_search_paths_aggregate_targets => :vendored_dynamic_library_search_paths do
          []
        end

        #-------------------------------------------------------------------------#

        # @!group Clang

        # @return [Array<String>]
        define_build_settings_method :header_search_paths, :build_setting => true, :memoized => true, :sorted => true, :uniqued => true do
          paths = []

          if !target.requires_frameworks? || !pod_targets.all?(&:should_build?)
            paths.concat target.sandbox.public_headers.search_paths(target.platform)
          end

          paths.concat target.search_paths_aggregate_targets.flat_map { |at| at.build_settings(configuration_name).header_search_paths }

          paths
        end

        # @return [Array<String>]
        define_build_settings_method :other_cflags, :build_setting => true, :memoized => true do
          flags = super()
          flags +
            header_search_paths.flat_map { |p| ['-isystem', p] } +
            framework_header_paths_for_iquote.flat_map { |p| ['-iquote', p] }
        end

        # @return [Array<String>]
        define_build_settings_method :framework_header_paths_for_iquote, :memoized => true, :sorted => true, :uniqued => true do
          paths = pod_targets.
                    select { |pt| pt.should_build? && pt.requires_frameworks? }.
                    map { |pt| "#{pt.build_product_path}/Headers" }
          paths.concat target.search_paths_aggregate_targets.flat_map { |at| at.build_settings(configuration_name).framework_header_paths_for_iquote }
          paths
        end

        # @return [Array<String>]
        define_build_settings_method :module_map_files, :memoized => true, :sorted => true, :uniqued => true, :compacted => true, :from_search_paths_aggregate_targets => :module_map_file_to_import do
          pod_targets.map { |t| t.build_settings.module_map_file_to_import }
        end

        #-------------------------------------------------------------------------#

        # @!group Swift

        # @see BuildSettings#other_swift_flags_without_swift?
        def other_swift_flags_without_swift?
          module_map_files.any?
        end

        # @return [Array<String>]
        define_build_settings_method :swift_include_paths, :build_setting => true, :memoized => true, :sorted => true, :uniqued => true, :from_pod_targets_to_link => true, :from_search_paths_aggregate_targets => :swift_include_paths_to_import do
          []
        end

        # @return [String]
        define_build_settings_method :always_embed_swift_standard_libraries, :build_setting => true, :memoized => true do
          return unless must_embed_swift?
          return if target_swift_version < EMBED_STANDARD_LIBRARIES_MINIMUM_VERSION

          'YES'
        end

        # @return [String]
        define_build_settings_method :embedded_content_contains_swift, :build_setting => true, :memoized => true do
          return unless must_embed_swift?
          return if target_swift_version >= EMBED_STANDARD_LIBRARIES_MINIMUM_VERSION

          'YES'
        end

        # @return [Boolean]
        define_build_settings_method :must_embed_swift?, :memoized => true do
          !target.requires_host_target? && pod_targets.any?(&:uses_swift?)
        end

        #-------------------------------------------------------------------------#

        # @!group Linking

        # @return [Array<String>]
        define_build_settings_method :ld_runpath_search_paths, :build_setting => true, :memoized => true, :uniqued => true do
          return unless target.requires_frameworks? || any_vendored_dynamic_artifacts?
          symbol_type = target.user_targets.map(&:symbol_type).uniq.first
          test_bundle = symbol_type == :octest_bundle || symbol_type == :unit_test_bundle || symbol_type == :ui_test_bundle
          _ld_runpath_search_paths(:requires_host_target => target.requires_host_target?, :test_bundle => test_bundle)
        end

        # @return [Boolean]
        define_build_settings_method :any_vendored_dynamic_artifacts?, :memoized => true do
          pod_targets.any? do |pt|
            pt.file_accessors.any? do |fa|
              fa.vendored_dynamic_artifacts.any?
            end
          end
        end

        # @return [Boolean]
        define_build_settings_method :requires_objc_linker_flag?, :memoized => true do
          includes_static_libs = !target.requires_frameworks?
          includes_static_libs || pod_targets.flat_map(&:file_accessors).any? { |fa| !fa.vendored_static_artifacts.empty? }
        end

        # @return [Boolean]
        define_build_settings_method :requires_fobjc_arc?, :memoized => true do
          target.podfile.set_arc_compatibility_flag? &&
          target.spec_consumers.any?(&:requires_arc?)
        end

        #-------------------------------------------------------------------------#

        # @!group Target Properties

        # @return [Version] the SWIFT_VERSION of the target being integrated
        #
        define_build_settings_method :target_swift_version, :memoized => true, :frozen => false do
          swift_version = target.target_definition.swift_version
          swift_version = nil if swift_version.blank?
          Version.new(swift_version)
        end

        EMBED_STANDARD_LIBRARIES_MINIMUM_VERSION = Version.new('2.3')
        private_constant :EMBED_STANDARD_LIBRARIES_MINIMUM_VERSION

        # Returns the {PodTarget}s which are active for the current
        # configuration name.
        #
        # @return [Array<PodTarget>]
        #
        define_build_settings_method :pod_targets, :memoized => true do
          target.pod_targets_for_build_configuration(configuration_name)
        end

        # @return [Array<PodTarget>]
        define_build_settings_method :pod_targets_to_link, :memoized => true do
          pod_targets -
            target.search_paths_aggregate_targets.flat_map { |at| at.build_settings(configuration_name).pod_targets_to_link }
        end

        # @return [Array<PodTarget>]
        define_build_settings_method :search_paths_aggregate_target_pod_target_build_settings, :memoized => true, :uniqued => true do
          pod_targets = target.search_paths_aggregate_targets.flat_map { |at| at.build_settings(configuration_name).pod_targets }
          pod_targets = select_maximal_pod_targets(pod_targets)
          pod_targets.flat_map(&:build_settings)
        end

        # Returns the +user_target_xcconfig+ for all pod targets and their spec
        # consumers grouped by keys
        #
        # @return [Hash{String,Hash{Target,String}]
        #
        def user_target_xcconfig_values_by_consumer_by_key
          pod_targets.each_with_object({}) do |target, hash|
            target.spec_consumers.each do |spec_consumer|
              spec_consumer.user_target_xcconfig.each do |k, v|
                # TODO: Need to decide how we are going to ensure settings like these
                # are always excluded from the user's project.
                #
                # See https://github.com/CocoaPods/CocoaPods/issues/1216
                next if k == 'USE_HEADERMAP'
                (hash[k] ||= {})[spec_consumer] = v
              end
            end
          end
        end

        # Merges the +user_target_xcconfig+ for all pod targets into a
        # single hash and warns on conflicting definitions.
        #
        # @return [Hash{String, String}]
        #
        define_build_settings_method :merged_user_target_xcconfigs, :memoized => true do
          merged_xcconfigs(user_target_xcconfig_values_by_consumer_by_key, :user_target_xcconfig)
        end

        #-------------------------------------------------------------------------#

        # @!group Private Methods

        def __clear__
          super
          pod_targets.each { |pt| pt.build_settings.__clear__ }
          target.search_paths_aggregate_targets.each { |at| at.build_settings(configuration_name).__clear__ }
        end
      end
    end
  end
end
