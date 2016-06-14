module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # Controller class responsible of creating and configuring the static
        # library target in Pods project. It also creates the support file needed
        # by the target.
        #
        class TargetInstaller
          # @return [Sandbox] sandbox the sandbox where the support files should
          #         be generated.
          #
          attr_reader :sandbox

          # @return [Target] The library whose target needs to be generated.
          #
          attr_reader :target

          # @param  [Project] project @see project
          # @param  [Target]  target  @see target
          #
          def initialize(sandbox, target)
            @sandbox = sandbox
            @target = target
          end

          private

          #-----------------------------------------------------------------------#

          # @!group Installation steps

          # Adds the target for the library to the Pods project with the
          # appropriate build configurations.
          #
          # @note   The `PODS_HEADERS_SEARCH_PATHS` overrides the xcconfig.
          #
          # @return [void]
          #
          def add_target
            product_type = target.product_type
            name = target.label
            platform = target.platform.name
            language = target.uses_swift? ? :swift : :objc
            @native_target = project.new_target(product_type, name, platform, deployment_target, nil, language)

            product_name = target.product_name
            product = @native_target.product_reference
            product.name = product_name

            target.user_build_configurations.each do |bc_name, type|
              @native_target.add_build_configuration(bc_name, type)
            end

            @native_target.build_configurations.each do |configuration|
              configuration.build_settings.merge!(custom_build_settings)
            end

            target.native_target = @native_target
          end

          # @return [String] The deployment target.
          #
          def deployment_target
            target.platform.deployment_target.to_s
          end

          # Returns the customized build settings which are overridden in the build
          # settings of the user target.
          #
          # @return [Hash{String => String}]
          #
          def custom_build_settings
            settings = {}

            unless target.archs.empty?
              settings['ARCHS'] = target.archs
            end

            if target.requires_frameworks?
              settings['PRODUCT_NAME'] = target.product_module_name
            else
              settings.merge!('OTHER_LDFLAGS' => '', 'OTHER_LIBTOOLFLAGS' => '')
            end

            settings
          end

          # Creates the directory where to store the support files of the target.
          #
          def create_support_files_dir
            target.support_files_dir.mkdir
          end

          # Creates the Info.plist file which sets public framework attributes
          #
          # @return [void]
          #
          def create_info_plist_file
            path = target.info_plist_path
            UI.message "- Generating Info.plist file at #{UI.path(path)}" do
              generator = Generator::InfoPlistFile.new(target)
              generator.save_as(path)
              add_file_to_support_group(path)

              native_target.build_configurations.each do |c|
                relative_path = path.relative_path_from(sandbox.root)
                c.build_settings['INFOPLIST_FILE'] = relative_path.to_s
              end
            end
          end

          # Creates the module map file which ensures that the umbrella header is
          # recognized with a customized path
          #
          # @yield_param [Generator::ModuleMap]
          #              yielded once to configure the private headers
          #
          # @return [void]
          #
          def create_module_map
            path = target.module_map_path
            UI.message "- Generating module map file at #{UI.path(path)}" do
              generator = Generator::ModuleMap.new(target)
              yield generator if block_given?
              generator.save_as(path)
              add_file_to_support_group(path)

              native_target.build_configurations.each do |c|
                relative_path = path.relative_path_from(sandbox.root)
                c.build_settings['MODULEMAP_FILE'] = relative_path.to_s
              end
            end
          end

          # Generates a header which ensures that all header files are exported
          # in the module map
          #
          # @yield_param [Generator::UmbrellaHeader]
          #              yielded once to configure the imports
          #
          def create_umbrella_header
            path = target.umbrella_header_path
            UI.message "- Generating umbrella header at #{UI.path(path)}" do
              generator = Generator::UmbrellaHeader.new(target)
              yield generator if block_given?
              generator.save_as(path)

              # Add the file to the support group and the native target,
              # so it will been added to the header build phase
              file_ref = add_file_to_support_group(path)
              native_target.add_file_references([file_ref])

              # Make the umbrella header public
              build_file = native_target.headers_build_phase.build_file(file_ref)
              build_file.settings ||= {}
              build_file.settings['ATTRIBUTES'] = ['Public']
            end
          end

          # Generates a dummy source file for each target so libraries that contain
          # only categories build.
          #
          # @return [void]
          #
          def create_dummy_source
            path = target.dummy_source_path
            generator = Generator::DummySource.new(target.label)
            generator.save_as(path)
            file_reference = add_file_to_support_group(path)
            native_target.source_build_phase.add_file_reference(file_reference)
          end

          # @return [PBXNativeTarget] the target generated by the installation
          #         process.
          #
          # @note   Generated by the {#add_target} step.
          #
          attr_reader :native_target

          private

          #-----------------------------------------------------------------------#

          # @!group Private helpers.

          # @return [Project] the Pods project of the sandbox.
          #
          def project
            sandbox.project
          end

          # @return [PBXGroup] the group where the file references to the support
          #         files should be stored.
          #
          attr_reader :support_files_group

          # Adds a reference to the given file in the support group of this target.
          #
          # @param  [Pathname] path
          #         The path of the file to which the reference should be added.
          #
          # @return [PBXFileReference] the file reference of the added file.
          #
          def add_file_to_support_group(path)
            support_files_group.new_file(path)
          end

          #-----------------------------------------------------------------------#
        end
      end
    end
  end
end
