require 'shellwords'

module Pod
  class Installer
    # Creates the targets which aggregate the Pods libraries in the Pods
    # project and the relative support files.
    #
    class AggregateTargetInstaller < TargetInstaller
      # Creates the target in the Pods project and the relative support files.
      #
      # @return [void]
      #
      def install!
        UI.message "- Installing target `#{target.name}` #{target.platform}" do
          add_target
          create_support_files_dir
          create_support_files_group
          create_xcconfig_file
          if target.requires_frameworks?
            create_info_plist_file
            create_module_map
            create_umbrella_header
            create_embed_frameworks_script
          end
          create_target_environment_header
          create_bridge_support_file
          create_copy_resources_script
          create_acknowledgements
          create_dummy_source
        end
      end

      #-----------------------------------------------------------------------#

      private

      # Ensure that vendored static frameworks and libraries are not linked
      # twice to the aggregate target, which shares the xcconfig of the user
      # target.
      #
      def custom_build_settings
        settings = {
          'OTHER_LDFLAGS'      => '',
          'OTHER_LIBTOOLFLAGS' => '',
          'PODS_ROOT'          => '$(SRCROOT)',
        }
        super.merge(settings)
      end

      # Creates the group that holds the references to the support files
      # generated by this installer.
      #
      # @return [void]
      #
      def create_support_files_group
        parent = project.support_files_group
        name = target.name
        dir = target.support_files_dir
        @support_files_group = parent.new_group(name, dir)
      end

      # Generates the contents of the xcconfig file and saves it to disk.
      #
      # @return [void]
      #
      def create_xcconfig_file
        native_target.build_configurations.each do |configuration|
          path = target.xcconfig_path(configuration.name)
          gen = Generator::XCConfig::AggregateXCConfig.new(target, configuration.name)
          gen.save_as(path)
          target.xcconfigs[configuration.name] = gen.xcconfig
          xcconfig_file_ref = add_file_to_support_group(path)
          configuration.base_configuration_reference = xcconfig_file_ref
        end
      end

      # Generates a header which allows to inspect at compile time the installed
      # pods and the installed specifications of a pod.
      #
      def create_target_environment_header
        path = target.target_environment_header_path
        generator = Generator::TargetEnvironmentHeader.new(target.specs_by_build_configuration)
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
        if target_definition.podfile.generate_bridge_support?
          path = target.bridge_support_path
          headers = native_target.headers_build_phase.files.map { |bf| sandbox.root + bf.file_ref.path }
          generator = Generator::BridgeSupport.new(headers)
          generator.save_as(path)
          add_file_to_support_group(path)
          @bridge_support_file = path.relative_path_from(sandbox.root)
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
        path = target.copy_resources_script_path
        library_targets = target.pod_targets.reject do |pod_target|
          pod_target.should_build? && pod_target.requires_frameworks?
        end
        resources_by_config = {}
        target.user_build_configurations.keys.each do |config|
          file_accessors = library_targets.select { |t| t.include_in_build_config?(config) }.flat_map(&:file_accessors)
          resource_paths = file_accessors.flat_map { |accessor| accessor.resources.flat_map { |res| res.relative_path_from(project.path.dirname) } }
          resource_bundles = file_accessors.flat_map { |accessor| accessor.resource_bundles.keys.map { |name| "${BUILT_PRODUCTS_DIR}/#{Shellwords.shellescape(name)}.bundle" } }
          resources_by_config[config] = resource_paths + resource_bundles
          resources_by_config[config] << bridge_support_file if bridge_support_file
        end
        generator = Generator::CopyResourcesScript.new(resources_by_config, target.platform)
        generator.save_as(path)
        add_file_to_support_group(path)
      end

      # Creates a script that embeds the frameworks to the bundle of the client
      # target.
      #
      # @note   We can't use Xcode default copy bundle resource phase, because
      #         we need to ensure that we only copy the resources, which are
      #         relevant for the current build configuration.
      #
      # @return [void]
      #
      def create_embed_frameworks_script
        path = target.embed_frameworks_script_path
        frameworks_by_config = {}
        target.user_build_configurations.keys.each do |config|
          frameworks_by_config[config] = target.pod_targets.select do |pod_target|
            pod_target.include_in_build_config?(config) && pod_target.should_build?
          end.map(&:product_name)
        end
        generator = Generator::EmbedFrameworksScript.new(target_definition, frameworks_by_config)
        generator.save_as(path)
        add_file_to_support_group(path)
      end

      # Generates the acknowledgement files (markdown and plist) for the target.
      #
      # @return [void]
      #
      def create_acknowledgements
        basepath = target.acknowledgements_basepath
        Generator::Acknowledgements.generators.each do |generator_class|
          path = generator_class.path_from_basepath(basepath)
          file_accessors = target.pod_targets.map(&:file_accessors).flatten
          generator = generator_class.new(file_accessors)
          generator.save_as(path)
          add_file_to_support_group(path)
        end
      end

      # @return [Pathname] the path of the bridge support file relative to the
      #         sandbox.
      #
      # @return [Nil] if no bridge support file was generated.
      #
      attr_reader :bridge_support_file

      #-----------------------------------------------------------------------#
    end
  end
end
