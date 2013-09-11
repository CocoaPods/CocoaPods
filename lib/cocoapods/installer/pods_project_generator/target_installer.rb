module Pod
  class Installer
    class PodsProjectGenerator

      # Controller class responsible of creating and configuring the static
      # target.native_target in Pods project. It also creates the support file needed
      # by the target.
      #
      # Creates the target for the Pods libraries in the Pods project and the
      # relative support files.
      #
      #
      class TargetInstaller

        # @return [Project] The project where the target should be installed.
        #
        attr_reader :project

        # @return [Target] The target whose native target needs to be
        #         generated.
        #
        attr_reader :target

        # @param  [Project] project @see project
        # @param  [Target] target @see target
        #
        def initialize(project, target)
          @project = project
          @target = target
        end

        # Creates the target in the Pods project and the relative support
        # files.
        #
        # @return [void]
        #
        def install!
          add_target
          unless target.aggregate?
            add_files_to_build_phases
            add_resources_bundle_targets
            link_to_system_frameworks
          end
        end


        private

        # @!group Installation steps
        #---------------------------------------------------------------------#

        # Adds the target for the target to the Pods project with the
        # appropriate build configurations.
        #
        # @note   The `PODS_HEADERS_SEARCH_PATHS` overrides the xcconfig.
        #
        # @return [void]
        #
        def add_target
          name = target.name
          platform = target.platform.name
          deployment_target = target.platform.deployment_target.to_s
          @native_target = project.new_target(:static_library, name, platform, deployment_target)

          settings = {}
          if target.platform.requires_legacy_ios_archs?
            settings['ARCHS'] = "armv6 armv7"
          end

          @native_target.build_settings('Debug').merge!(settings)
          @native_target.build_settings('Release').merge!(settings)

          target.user_build_configurations.each do |bc_name, type|
            @native_target.add_build_configuration(bc_name, type)
          end

          target.native_target = @native_target
        end

        # Adds the build files of the pods to the target and adds a reference to
        # the frameworks of the Pods.
        #
        # @note   The Frameworks are used only for presentation purposes as the
        #         xcconfig is the authoritative source about their information.
        #
        # @return [void]
        #
        def add_files_to_build_phases
          target.file_accessors.each do |file_accessor|
            consumer = file_accessor.spec_consumer
            flags = compiler_flags_for_consumer(consumer, target.inhibits_warnings?)
            source_files = file_accessor.source_files
            file_refs = source_files.map { |sf| project.reference_for_path(sf) }
            target.native_target.add_file_references(file_refs, flags)
          end
        end

        # Adds the resources of the Pods to the Pods project.
        #
        # @note   The source files are grouped by Pod and in turn by subspec
        #         (recursively) in the resources group.
        #
        # @return [void]
        #
        def add_resources_bundle_targets
          # TODO: Move to a dedicated installer
          target.file_accessors.each do |file_accessor|
            file_accessor.resource_bundles.each do |bundle_name, paths|
              file_references = paths.map { |sf| project.reference_for_path(sf) }
              bundle_target = project.new_resources_bundle(bundle_name, file_accessor.spec_consumer.platform_name)
              bundle_target.add_resources(file_references)

              target.user_build_configurations.each do |bc_name, type|
                bundle_target.add_build_configuration(bc_name, type)
              end

              target.add_dependency(bundle_target)
            end
          end
        end

        # Add a file reference to the system frameworks if needed and links the
        # target to them.
        #
        # This is done only for informative purposes as the xcconfigs are the
        # authoritative source of the build settings.
        #
        # @return [void]
        #
        def link_to_system_frameworks
          target.native_target.add_system_frameworks(target.frameworks)
          target.native_target.add_system_libraries(target.libraries)
        end


        private

        # @!group Private helpers
        #---------------------------------------------------------------------#

        # The minimum deployment targets where the `OS_OBJECT_USE_OBJC` flag
        # should be used per platform name.
        #
        ENABLE_OBJECT_USE_OBJC_FROM = {
          :ios => Version.new('6'),
          :osx => Version.new('10.8')
        }

        # Returns the compiler flags for the source files of the given specification.
        #
        # The following behavior is regarding the `OS_OBJECT_USE_OBJC` flag. When
        # set to `0`, it will allow code to use `dispatch_release()` on >= iOS 6.0
        # and OS X 10.8.
        #
        # * New libraries that do *not* require ARC don’t need to care about this
        #   issue at all.
        #
        # * New libraries that *do* require ARC _and_ have a deployment target of
        #   >= iOS 6.0 or OS X 10.8:
        #
        #   These no longer use `dispatch_release()` and should *not* have the
        #   `OS_OBJECT_USE_OBJC` flag set to `0`.
        #
        #   **Note:** this means that these libraries *have* to specify the
        #             deployment target in order to function well.
        #
        # * New libraries that *do* require ARC, but have a deployment target of
        #   < iOS 6.0 or OS X 10.8:
        #
        #   These contain `dispatch_release()` calls and as such need the
        #   `OS_OBJECT_USE_OBJC` flag set to `1`.
        #
        #   **Note:** libraries that do *not* specify a platform version are
        #             assumed to have a deployment target of < iOS 6.0 or OS X 10.8.
        #
        #  For more information, see: http://opensource.apple.com/source/libdispatch/libdispatch-228.18/os/object.h
        #
        # @param  [Specification::Consumer] consumer
        #         The consumer for the specification for which the compiler flags
        #         are needed.
        #
        # @return [String] The compiler flags.
        #
        def compiler_flags_for_consumer(consumer, inhibits_warnings = false)
          flags = consumer.compiler_flags.dup
          if consumer.requires_arc
            flags << '-fobjc-arc'
            platform_name = consumer.platform_name
            spec_deployment_target = consumer.spec.deployment_target(platform_name)
            if spec_deployment_target.nil? || Version.new(spec_deployment_target) < ENABLE_OBJECT_USE_OBJC_FROM[platform_name]
              flags << '-DOS_OBJECT_USE_OBJC=0'
            end
          end
          if inhibits_warnings
            flags << '-w -Xanalyzer -analyzer-disable-checker'
          end
          flags.join(" ")
        end

        #---------------------------------------------------------------------#

      end
    end
  end
end

