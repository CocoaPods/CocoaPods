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

        attr_reader :project

        def initialize(target, project)
          @target = target
          @project = project
        end

        def generate!
          validate

          # TODO clean up
          if target.is_a?(AggregateTarget)
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
          UI.message "- Generating xcconfig file" do
            path = target.xcconfig_path
            gen = Generator::XCConfig::AggregateXCConfig.new(target)
            gen.save_as(path)
            target.xcconfig = gen.xcconfig
            xcconfig_file_ref = add_file_to_support_group(path)

            target.target.build_configurations.each do |c|
              c.base_configuration_reference = xcconfig_file_ref
            end
          end
        end


        # Generates the contents of the xcconfig file and saves it to disk.
        #
        # @return [void]
        #
        def create_xcconfig_file_pods
          public_gen = Generator::XCConfig::PublicPodXCConfig.new(target)
          UI.message "- Generating public xcconfig file" do
            path = target.xcconfig_path
            public_gen.save_as(path)
            add_file_to_support_group(path)
          end

          UI.message "- Generating private xcconfig file" do
            path = target.xcconfig_private_path
            private_gen = Generator::XCConfig::PrivatePodXCConfig.new(target, public_gen.xcconfig)
            private_gen.save_as(path)
            xcconfig_file_ref = add_file_to_support_group(path)

            target.target.build_configurations.each do |c|
              c.base_configuration_reference = xcconfig_file_ref
            end
          end
        end


        # Generates a header which allows to inspect at compile time the installed
        # pods and the installed specifications of a pod.
        #
        def create_target_environment_header
          UI.message "- Generating target environment header" do
            path = target.target_environment_header_path
            generator = Generator::TargetEnvironmentHeader.new(target.pod_targets.map { |l| l.specs }.flatten)
            generator.save_as(path)
            add_file_to_support_group(path)
          end
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
          if target.target_definition.podfile.generate_bridge_support?
            UI.message "- Generating BridgeSupport metadata" do
              path = target.bridge_support_path
              headers = target.target.headers_build_phase.files.map { |bf| bf.file_ref.real_path }
              generator = Generator::BridgeSupport.new(headers)
              generator.save_as(path)
              add_file_to_support_group(path)
              @bridge_support_file = path
            end
          end
        end

        # Generates the acknowledgement files (markdown and plist) for the target.
        #
        # @return [void]
        #
        def create_acknowledgements
          Generator::Acknowledgements.generators.each do |generator_class|
            UI.message "- Generating acknowledgements" do
              basepath = target.acknowledgements_basepath
              path = generator_class.path_from_basepath(basepath)
              file_accessors = target.pod_targets.map(&:file_accessors).flatten
              generator = generator_class.new(file_accessors)
              generator.save_as(path)
              add_file_to_support_group(path)
            end
          end
        end

        # Creates a script that copies the resources to the bundle of the client
        # target.
        #
        # @note   The bridge support file needs to be created before the prefix
        #         header, otherwise it will not be added to the resources script.
        #
        # @return [void]
        #
        def create_copy_resources_script
          UI.message "- Generating copy resources script" do
            path = target.copy_resources_script_path
            file_accessors = target.pod_targets.map(&:file_accessors).flatten
            resource_paths = file_accessors.map { |accessor| accessor.resources.flatten.map { |res| res.relative_path_from(path.dirname) }}.flatten
            resource_bundles = file_accessors.map { |accessor| accessor.resource_bundles.keys.map {|name| "${BUILT_PRODUCTS_DIR}/#{name}.bundle" } }.flatten
            resources = []
            resources.concat(resource_paths)
            resources.concat(resource_bundles)
            resources << bridge_support_file.relative_path_from(project.path.dirname) if bridge_support_file
            generator = Generator::CopyResourcesScript.new(resources, target.platform)
            generator.save_as(path)
            add_file_to_support_group(path)
          end
        end

        # Creates a prefix header file which imports `UIKit` or `Cocoa` according
        # to the platform of the target. This file also include any prefix header
        # content reported by the specification of the pods.
        #
        # @return [void]
        #
        def create_prefix_header
          UI.message "- Generating prefix header" do
            path = target.prefix_header_path
            generator = Generator::PrefixHeader.new(target.file_accessors, target.platform)
            generator.imports << target.target_environment_header_path.basename
            generator.save_as(path)
            add_file_to_support_group(path)

            target.target.build_configurations.each do |c|
              relative_path = path.relative_path_from(project.path.dirname)
              c.build_settings['GCC_PREFIX_HEADER'] = relative_path.to_s
            end
          end
        end


        # Generates a dummy source file for each target so libraries that contain
        # only categories build.
        #
        # @return [void]
        #
        def create_dummy_source
          UI.message "- Generating dummy source file" do
            path = target.dummy_source_path
            generator = Generator::DummySource.new(target.label)
            generator.save_as(path)
            file_reference = add_file_to_support_group(path)
            existing = target.target.source_build_phase.files_references.include?(file_reference)
            unless existing
              target.target.source_build_phase.add_file_reference(file_reference)
            end
          end
        end




        private

        # @!group Private helpers.
        #---------------------------------------------------------------------#

        # @return [PBXGroup] the group where the file references to the support
        #         files should be stored.
        #
        def support_files_group
          # TODO
          unless @support_files_group
            if target.is_a?(AggregateTarget)
              #TODO move to Pods
              @support_files_group = project.support_files_group[target.name] || project.support_files_group.new_group(target.name)
            else
              pod_name = target.pod_name
              @support_files_group = project.group_for_spec(pod_name, :support_files)
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
