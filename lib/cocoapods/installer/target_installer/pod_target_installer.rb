module Pod
  class Installer
    # Creates the target for the Pods libraries in the Pods project and the
    # relative support files.
    #
    class PodTargetInstaller < TargetInstaller
      # Creates the target in the Pods project and the relative support files.
      #
      # @return [void]
      #
      def install!
        UI.message "- Installing target `#{target.name}` #{target.platform}" do
          add_target
          create_support_files_dir
          add_files_to_build_phases
          add_resources_bundle_targets
          create_xcconfig_file
          create_prefix_header
          create_dummy_source
        end
      end

      private

      #-----------------------------------------------------------------------#

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

          other_source_files = file_accessor.source_files.select { |sf| sf.extname == '.d' }

          {
            true => file_accessor.arc_source_files,
            false => file_accessor.non_arc_source_files,
          }.each do |arc, files|
            files = files - other_source_files
            flags = compiler_flags_for_consumer(consumer, arc)
            regular_file_refs = files.map { |sf| project.reference_for_path(sf) }
            native_target.add_file_references(regular_file_refs, flags)
          end

          other_file_refs = other_source_files.map { |sf| project.reference_for_path(sf) }
          native_target.add_file_references(other_file_refs, nil)
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
        target.file_accessors.each do |file_accessor|
          file_accessor.resource_bundles.each do |bundle_name, paths|
            # Add a dependency on an existing Resource Bundle target if possible
            if bundle_target = project.targets.find { |target| target.name == bundle_name }
              native_target.add_dependency(bundle_target)
              next
            end
            file_references = paths.map { |sf| project.reference_for_path(sf) }
            bundle_target = project.new_resources_bundle(bundle_name, file_accessor.spec_consumer.platform_name)
            bundle_target.add_resources(file_references)

            target.user_build_configurations.each do |bc_name, type|
              bundle_target.add_build_configuration(bc_name, type)
            end

            native_target.add_dependency(bundle_target)
          end
        end
      end

      # Generates the contents of the xcconfig file and saves it to disk.
      #
      # @return [void]
      #
      def create_xcconfig_file
        path = target.xcconfig_path
        public_gen = Generator::XCConfig::PublicPodXCConfig.new(target)
        public_gen.save_as(path)
        add_file_to_support_group(path)

        path = target.xcconfig_private_path
        private_gen = Generator::XCConfig::PrivatePodXCConfig.new(target, public_gen.xcconfig)
        private_gen.save_as(path)
        xcconfig_file_ref = add_file_to_support_group(path)

        native_target.build_configurations.each do |c|
          c.base_configuration_reference = xcconfig_file_ref
        end
      end

      # Creates a prefix header file which imports `UIKit` or `Cocoa` according
      # to the platform of the target. This file also include any prefix header
      # content reported by the specification of the pods.
      #
      # @return [void]
      #
      def create_prefix_header
        path = target.prefix_header_path
        generator = Generator::PrefixHeader.new(target.file_accessors, target.platform)
        generator.imports << target.target_environment_header_path.basename
        generator.save_as(path)
        add_file_to_support_group(path)

        native_target.build_configurations.each do |c|
          relative_path = path.relative_path_from(project.path.dirname)
          c.build_settings['GCC_PREFIX_HEADER'] = relative_path.to_s
        end
      end

      ENABLE_OBJECT_USE_OBJC_FROM = {
        :ios => Version.new('6'),
        :osx => Version.new('10.8'),
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
      def compiler_flags_for_consumer(consumer, arc)
        flags = consumer.compiler_flags.dup
        if !arc
          flags << '-fno-objc-arc'
        else
          platform_name = consumer.platform_name
          spec_deployment_target = consumer.spec.deployment_target(platform_name)
          if spec_deployment_target.nil? || Version.new(spec_deployment_target) < ENABLE_OBJECT_USE_OBJC_FROM[platform_name]
            flags << '-DOS_OBJECT_USE_OBJC=0'
          end
        end
        if target_definition.inhibits_warnings_for_pod?(consumer.spec.root.name)
          flags << '-w -Xanalyzer -analyzer-disable-checker -Xanalyzer deadcode'
        end
        flags * ' '
      end

      # Adds a reference to the given file in the support group of this target.
      #
      # @param  [Pathname] path
      #         The path of the file to which the reference should be added.
      #
      # @return [PBXFileReference] the file reference of the added file.
      #
      def add_file_to_support_group(path)
        pod_name = target.pod_name
        dir = target.support_files_dir
        group = project.pod_support_files_group(pod_name, dir)
        group.new_file(path)
      end

      #-----------------------------------------------------------------------#
    end
  end
end
