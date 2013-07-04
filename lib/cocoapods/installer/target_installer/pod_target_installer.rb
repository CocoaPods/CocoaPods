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
        UI.message "- Installing target `#{library.name}` #{library.platform}" do
          add_target
          add_files_to_build_phases
          create_suport_files_group
          create_xcconfig_file
          create_prefix_header
          create_dummy_source
        end
      end

      #-----------------------------------------------------------------------#

      private

      # Adds the build files of the pods to the target and adds a reference to
      # the frameworks of the Pods.
      #
      # @note   The Frameworks are used only for presentation purposes as the
      #         xcconfig is the authoritative source about their information.
      #
      # @return [void]
      #
      def add_files_to_build_phases
        UI.message "- Adding Build files" do
          library.file_accessors.each do |file_accessor|
            consumer = file_accessor.spec_consumer
            flags = compiler_flags_for_consumer(consumer)
            source_files = file_accessor.source_files
            file_refs = source_files.map { |sf| project.file_reference(sf) }
            target.add_file_references(file_refs, flags)

            file_accessor.spec_consumer.frameworks.each do |framework|
              project.add_system_framework(framework, target)
            end
          end
        end
      end

      # Generates the contents of the xcconfig file and saves it to disk.
      #
      # @return [void]
      #
      def create_xcconfig_file
        path = library.xcconfig_path
        public_gen = Generator::PublicPodXCConfig.new(library)
        UI.message "- Generating public xcconfig file at #{UI.path(path)}" do
          public_gen.save_as(path)
          add_file_to_support_group(path)
        end

        path = library.xcconfig_private_path
        private_gen = Generator::PrivatePodXCConfig.new(library, public_gen.xcconfig)
        UI.message "- Generating private xcconfig file at #{UI.path(path)}" do
          private_gen.save_as(path)
          xcconfig_file_ref = add_file_to_support_group(path)

          target.build_configurations.each do |c|
            c.base_configuration_reference = xcconfig_file_ref
          end
        end
      end

      # Creates a prefix header file which imports `UIKit` or `Cocoa` according
      # to the platform of the target. This file also include any prefix header
      # content reported by the specification of the pods.
      #
      # @return [void]
      #
      def create_prefix_header
        path = library.prefix_header_path
        UI.message "- Generating prefix header at #{UI.path(path)}" do
          generator = Generator::PrefixHeader.new(library.file_accessors, library.platform)
          generator.imports << library.target_environment_header_path.basename
          generator.save_as(path)
          add_file_to_support_group(path)

          target.build_configurations.each do |c|
            relative_path = path.relative_path_from(sandbox.root)
            c.build_settings['GCC_PREFIX_HEADER'] = relative_path.to_s
          end
        end
      end

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
      def compiler_flags_for_consumer(consumer)
        flags = consumer.compiler_flags.dup
        if consumer.requires_arc
          flags << '-fobjc-arc'
          platform_name = consumer.platform_name
          spec_deployment_target = consumer.spec.deployment_target(platform_name)
          if spec_deployment_target.nil? || Version.new(spec_deployment_target) < ENABLE_OBJECT_USE_OBJC_FROM[platform_name]
            flags << '-DOS_OBJECT_USE_OBJC=0'
          end
        end
        if target_definition.inhibits_warnings_for_pod?(consumer.spec.root.name)
          flags << '-w -Xanalyzer -analyzer-disable-checker'
        end
        flags * " "
      end

      #-----------------------------------------------------------------------#

    end
  end
end
