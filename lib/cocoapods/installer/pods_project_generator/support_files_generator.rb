module Pod
  class Installer
    class PodsProjectGenerator

      # Generates the support files for the given target
      #
      class SupportFilesGenerator

        # TODO: move generators in name-space
        # TODO: remove unused file references to the support group

        # @return [Target] The target whose support files need to be generated.
        #
        attr_reader :target

        attr_reader :sandbox

        def initialize(target, sandbox)
          @target = target
          @sandbox = sandbox
        end

        def project
          sandbox.project
        end

        def generate!
          validate
          # TODO clean up
          if target.aggregate?
            create_xcconfig_file_aggregate
            create_target_environment_header
            create_bridge_support_file
            create_copy_resources_script
            create_acknowledgements
          else
            create_xcconfig_file_pods
            create_prefix_header
          end
          create_dummy_source
        end


        private

        # @!group Generation Steps
        #---------------------------------------------------------------------#

        def validate
          unless target.target
            raise "[SupportFilesGenerator] Missing native target for `#{target}`"
          end
        end

        # Generates the contents of the xcconfig file and saves it to disk.
        #
        # @return [void]
        #
        def create_xcconfig_file_aggregate
          path = file_path(:public_xcconfig)
          gen = Generator::XCConfig::AggregateXCConfig.new(target, sandbox.root)
          gen.save_as(path)
          target.xcconfig = gen.xcconfig
          xcconfig_file_ref = add_file_to_support_group(path)
          target.xcconfig_path = path

          target.target.build_configurations.each do |c|
            c.base_configuration_reference = xcconfig_file_ref
          end
        end

        # Generates the contents of the xcconfig file and saves it to disk.
        #
        # @return [void]
        #
        def create_xcconfig_file_pods
          public_gen = Generator::XCConfig::PublicPodXCConfig.new(target, sandbox.root)
          path = file_path(:public_xcconfig)
          public_gen.save_as(path)
          add_file_to_support_group(path)
          target.xcconfig_path = path

          path = file_path(:private_xcconfig)
          private_gen = Generator::XCConfig::PrivatePodXCConfig.new(target, public_gen.xcconfig)
          private_gen.save_as(path)
          xcconfig_file_ref = add_file_to_support_group(path)

          target.target.build_configurations.each do |c|
            c.base_configuration_reference = xcconfig_file_ref
          end
        end

        # Generates a header which allows to inspect at compile time the
        # installed pods and the installed specifications of a pod.
        #
        def create_target_environment_header
          path = file_path(:environment_header, target.root)
          generator = Generator::TargetEnvironmentHeader.new(target.children.map { |l| l.specs }.flatten)
          generator.save_as(path)
          add_file_to_support_group(path)
        end

        # Generates the bridge support metadata if requested by the {Podfile}.
        #
        # @note   The bridge support metadata is added to the resources of the
        #         target because it is needed for environments interpreted at
        #         runtime.
        #
        # @return [void]
        #
        def create_bridge_support_file
          if target.generate_bridge_support?
            path = file_path(:bridge_support)
            headers = target.target.headers_build_phase.files.map { |bf| bf.file_ref.real_path }
            generator = Generator::BridgeSupport.new(headers)
            generator.save_as(path)
            add_file_to_support_group(path)
            @bridge_support_file = path
          end
        end

        # Generates the acknowledgement files (markdown and plist) for the target.
        #
        # @return [void]
        #
        def create_acknowledgements
          Generator::Acknowledgements.generators.each do |generator_class|
            basepath = file_path(:acknowledgements)
            path = generator_class.path_from_basepath(basepath)
            file_accessors = target.children.map(&:file_accessors).flatten
            generator = generator_class.new(file_accessors)
            generator.save_as(path)
            add_file_to_support_group(path)
          end
        end

        # Creates a script that copies the resources to the bundle of the
        # client target.
        #
        # @note   The bridge support file needs to be created before the prefix
        #         header, otherwise it will not be added to the resources
        #         script.
        #
        # @return [void]
        #
        def create_copy_resources_script
          path = file_path(:copy_resources_script)
          file_accessors = target.children.map(&:file_accessors).flatten
          resource_paths = file_accessors.map { |accessor| accessor.resources.flatten.map { |res| res.relative_path_from(path.dirname) }}.flatten
          resource_bundles = file_accessors.map { |accessor| accessor.resource_bundles.keys.map {|name| "${BUILT_PRODUCTS_DIR}/#{name}.bundle" } }.flatten
          resources = []
          resources.concat(resource_paths)
          resources.concat(resource_bundles)
          resources << bridge_support_file.relative_path_from(project.path.dirname) if bridge_support_file
          generator = Generator::CopyResourcesScript.new(resources, target.platform)
          generator.save_as(path)
          add_file_to_support_group(path)
          target.copy_resources_script_path = path
        end

        # Creates a prefix header file which imports `UIKit` or `Cocoa` according
        # to the platform of the target. This file also include any prefix header
        # content reported by the specification of the pods.
        #
        # @return [void]
        #
        def create_prefix_header
          path = file_path(:prefix_header)
          generator = Generator::PrefixHeader.new(target.file_accessors, target.platform)
          generator.imports << file_path(:environment_header, target.root).basename
          generator.save_as(path)
          add_file_to_support_group(path)
          target.prefix_header_path = path

          target.target.build_configurations.each do |c|
            relative_path = path.relative_path_from(project.path.dirname)
            c.build_settings['GCC_PREFIX_HEADER'] = relative_path.to_s
          end
        end


        # Generates a dummy source file for each target so libraries that contain
        # only categories build.
        #
        # @return [void]
        #
        def create_dummy_source
          path = file_path(:dummy_source)
          generator = Generator::DummySource.new(target.name)
          generator.save_as(path)
          file_reference = add_file_to_support_group(path)
          existing = target.target.source_build_phase.files_references.include?(file_reference)
          unless existing
            target.target.source_build_phase.add_file_reference(file_reference)
          end
        end


        private

        # @!group Paths
        #---------------------------------------------------------------------#

        # @return [Hash{Symbol=>String}] The name of the support files by key.
        #
        SUPPORT_FILES_NAMES = {
          :acknowledgements      => "acknowledgements",
          :bridge_support        => "metadata.bridgesupport",
          :copy_resources_script => "resources.sh",
          :dummy_source          => "dummy.m",
          :environment_header    => "environment.h",
          :prefix_header         => "prefix.pch",
          :private_xcconfig      => "private.xcconfig",
          :public_xcconfig       => "public.xcconfig",
        }

        # @return [Pathname] The absolute path of the support file with the
        #         given extension.
        #
        def file_path(key, target_for_path = nil)
          target_for_path ||= target
          file_name = SUPPORT_FILES_NAMES[key]
          raise "Unrecognized key `#{key}`" unless file_name
          target_for_path.support_files_root + "#{target_for_path.name}-#{file_name}"
        end


        private

        # @!group Private helpers
        #---------------------------------------------------------------------#

        # @return [PBXGroup] the group where the file references to the support
        #         files should be stored.
        #
        def support_files_group
          unless @support_files_group
            if target.aggregate?
              aggregate_name = target.name
              @support_files_group = project.add_aggregate_group(aggregate_name, project.path.dirname)
            else
              aggregate_name = target.root.name
              pod_name = target.pod_name
              unless project.aggregate_group(aggregate_name)
                # TODO
                project.add_aggregate_group(aggregate_name, project.path.dirname)
              end
              @support_files_group = project.add_aggregate_pod_group(aggregate_name, pod_name, project.path.dirname)
            end
          end
          @support_files_group
        end

        # Adds a reference to the given file in the support group of this
        # target unless it already exists.
        #
        # @param  [Pathname] path
        #         The path of the file to which the reference should be added.
        #
        # @return [PBXFileReference] the file reference of the added file.
        #
        def add_file_to_support_group(path)
          existing = support_files_group.children.find { |reference| reference.real_path == path }
          if existing
            existing
          else
            support_files_group.new_file(path)
          end
        end

        # @return [Pathname] the path of the bridge support file relative to the
        #         project.
        #
        # @return [Nil] if no bridge support file was generated.
        #
        attr_reader :bridge_support_file

        #---------------------------------------------------------------------#

      end
    end
  end
end
