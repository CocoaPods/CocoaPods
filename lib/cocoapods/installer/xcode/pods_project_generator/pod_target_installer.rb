module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # Creates the target for the Pods libraries in the Pods project and the
        # relative support files.
        #
        class PodTargetInstaller < TargetInstaller
          # Creates the target in the Pods project and the relative support files.
          #
          # @return [void]
          #
          def install!
            unless target.should_build?
              add_resources_bundle_targets
              return
            end

            UI.message "- Installing target `#{target.name}` #{target.platform}" do
              add_target
              create_support_files_dir
              add_test_targets if target.contains_test_specifications?
              add_resources_bundle_targets
              add_files_to_build_phases
              create_xcconfig_file
              create_test_xcconfig_files if target.contains_test_specifications?
              if target.requires_frameworks?
                create_info_plist_file
                create_module_map
                create_umbrella_header do |generator|
                  file_accessors = target.file_accessors
                  file_accessors = file_accessors.reject { |f| f.spec.test_specification? } if target.contains_test_specifications?
                  generator.imports += if header_mappings_dir
                                         file_accessors.flat_map(&:public_headers).map do |pathname|
                                           pathname.relative_path_from(header_mappings_dir)
                                         end
                                       else
                                         file_accessors.flat_map(&:public_headers).map(&:basename)
                                       end
                end
                create_build_phase_to_symlink_header_folders
              end
              create_prefix_header
              create_dummy_source
            end
          end

          private

          # Remove the default headers folder path settings for static library pod
          # targets.
          #
          # @return [Hash{String => String}]
          #
          def custom_build_settings
            settings = super
            unless target.requires_frameworks?
              settings['PRIVATE_HEADERS_FOLDER_PATH'] = ''
              settings['PUBLIC_HEADERS_FOLDER_PATH'] = ''
            end

            settings['CODE_SIGN_IDENTITY[sdk=appletvos*]'] = ''
            settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = ''
            settings['CODE_SIGN_IDENTITY[sdk=watchos*]'] = ''

            settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) '

            if target.swift_version
              settings['SWIFT_VERSION'] = target.swift_version
            end
            settings
          end

          # Filters the given resource file references discarding empty paths which are
          # added by their parent directory. This will also include references to the parent [PBXVariantGroup]
          # for all resources underneath it.
          #
          # @param  [Array<Pathname>] resource_file_references
          #         The array of all resource file references to filter.
          #
          # @yield_param  [Array<PBXFileReference>} The filtered resource file references to be installed
          #               in the copy resources phase.
          #
          # @yield_param  [Array<PBXFileReference>} The filtered resource file references to be installed
          #               in the compile sources phase.
          #
          # @note   Core Data model directories (.xcdatamodeld) used to be added to the
          #         `Copy Resources` build phase like all other resources, since they would
          #         compile correctly in either the resources or compile phase. In recent
          #         versions of xcode, there's an exception for data models that generate
          #         headers. These need to be added to the compile sources phase of a real
          #         target for the headers to be built in time for code in the target to
          #         use them. These kinds of models generally break when added to resource
          #         bundles.
          #
          def filter_resource_file_references(resource_file_references)
            file_references = resource_file_references.map do |resource_file_reference|
              ref = project.reference_for_path(resource_file_reference)

              # Some nested files are not directly present in the Xcode project, such as the contents
              # of an .xcdatamodeld directory. These files are implicitly included by including their
              # parent directory.
              next if ref.nil?

              # For variant groups, the variant group itself is added, not its members.
              next ref.parent if ref.parent.is_a?(Xcodeproj::Project::Object::PBXVariantGroup)

              ref
            end.compact.uniq
            compile_phase_matcher = lambda { |ref| !(ref.path =~ /.*\.xcdatamodeld/i).nil? }
            resources_phase_refs = file_references.reject(&compile_phase_matcher)
            compile_phase_refs = file_references.select(&compile_phase_matcher)
            yield resources_phase_refs, compile_phase_refs
          end

          #-----------------------------------------------------------------------#

          SOURCE_FILE_EXTENSIONS = Sandbox::FileAccessor::SOURCE_FILE_EXTENSIONS

          # Adds the build files of the pods to the target and adds a reference to
          # the frameworks of the Pods.
          #
          # @note   The Frameworks are used only for presentation purposes as the
          #         xcconfig is the authoritative source about their information.
          #
          # @note   Core Data model directories (.xcdatamodeld) defined in the `resources`
          #         property are currently added to the `Copy Resources` build phase like
          #         all other resources. The Xcode UI adds these to the `Compile Sources`
          #         build phase, but they will compile correctly either way.
          #
          # @return [void]
          #
          def add_files_to_build_phases
            target.file_accessors.each do |file_accessor|
              consumer = file_accessor.spec_consumer

              native_target = target.native_target_for_spec(consumer.spec)
              headers = file_accessor.headers
              public_headers = file_accessor.public_headers
              private_headers = file_accessor.private_headers
              other_source_files = file_accessor.source_files.reject { |sf| SOURCE_FILE_EXTENSIONS.include?(sf.extname) }

              {
                true => file_accessor.arc_source_files,
                false => file_accessor.non_arc_source_files,
              }.each do |arc, files|
                files = files - headers - other_source_files
                flags = compiler_flags_for_consumer(consumer, arc)
                regular_file_refs = project_file_references_array(files, 'source')
                native_target.add_file_references(regular_file_refs, flags)
              end

              header_file_refs = project_file_references_array(headers, 'header')
              native_target.add_file_references(header_file_refs) do |build_file|
                add_header(build_file, public_headers, private_headers, native_target)
              end

              other_file_refs = project_file_references_array(other_source_files, 'other source')
              native_target.add_file_references(other_file_refs, nil)

              next unless target.requires_frameworks?

              filter_resource_file_references(file_accessor.resources.flatten) do |resource_phase_refs, compile_phase_refs|
                native_target.add_file_references(compile_phase_refs, nil)
                native_target.add_resources(resource_phase_refs)
              end
            end
          end

          # Adds the test targets for the library to the Pods project with the
          # appropriate build configurations.
          #
          # @return [void]
          #
          def add_test_targets
            target.supported_test_types.each do |test_type|
              product_type = target.product_type_for_test_type(test_type)
              name = target.test_target_label(test_type)
              platform_name = target.platform.name
              language = target.uses_swift? ? :swift : :objc
              native_test_target = project.new_target(product_type, name, platform_name, deployment_target, nil, language)
              native_test_target.product_reference.name = name

              target.user_build_configurations.each do |bc_name, type|
                native_test_target.add_build_configuration(bc_name, type)
              end

              native_test_target.build_configurations.each do |configuration|
                configuration.build_settings.merge!(custom_build_settings)
                # target_installer will automatically add an empty `OTHER_LDFLAGS`. For test
                # targets those are set via a test xcconfig file instead.
                configuration.build_settings.delete('OTHER_LDFLAGS')
                # target_installer will automatically set the product name to the module name if the target
                # requires frameworks. For tests we always use the test target name as the product name
                # irrelevant to whether we use frameworks or not.
                configuration.build_settings['PRODUCT_NAME'] = name
              end

              # Test native targets also need frameworks and resources to be copied over to their xctest bundle.
              create_test_target_embed_frameworks_script(test_type)
              create_test_target_copy_resources_script(test_type)

              target.test_native_targets << native_test_target
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
                label = target.resources_bundle_target_label(bundle_name)
                bundle_target = project.new_resources_bundle(label, file_accessor.spec_consumer.platform_name)
                bundle_target.product_reference.tap do |bundle_product|
                  bundle_file_name = "#{bundle_name}.bundle"
                  bundle_product.name = bundle_file_name
                  bundle_product.path = bundle_file_name
                end

                filter_resource_file_references(paths) do |resource_phase_refs, compile_phase_refs|
                  # Resource bundles are only meant to have resources, so install everything
                  # into the resources phase. See note in filter_resource_file_references.
                  bundle_target.add_resources(resource_phase_refs + compile_phase_refs)
                end

                native_target = target.native_target_for_spec(file_accessor.spec_consumer.spec)
                target.user_build_configurations.each do |bc_name, type|
                  bundle_target.add_build_configuration(bc_name, type)
                end
                bundle_target.deployment_target = deployment_target

                test_specification = file_accessor.spec.test_specification?

                if test_specification
                  target.test_resource_bundle_targets << bundle_target
                else
                  target.resource_bundle_targets << bundle_target
                end

                if target.should_build?
                  native_target.add_dependency(bundle_target)
                  if target.requires_frameworks?
                    native_target.add_resources([bundle_target.product_reference])
                  end
                end

                # Create Info.plist file for bundle
                path = target.info_plist_path
                path.dirname.mkdir unless path.dirname.exist?
                info_plist_path = path.dirname + "ResourceBundle-#{bundle_name}-#{path.basename}"
                generator = Generator::InfoPlistFile.new(target, :bundle_package_type => :bndl)
                update_changed_file(generator, info_plist_path)
                add_file_to_support_group(info_plist_path)

                bundle_target.build_configurations.each do |c|
                  c.build_settings['PRODUCT_NAME'] = bundle_name
                  relative_info_plist_path = info_plist_path.relative_path_from(sandbox.root)
                  c.build_settings['INFOPLIST_FILE'] = relative_info_plist_path.to_s
                  # Do not set the CONFIGURATION_BUILD_DIR for resource bundles that are only meant for test targets.
                  # This is because the test target itself also does not set this configuration build dir and it expects
                  # all bundles to be copied from the default path.
                  unless test_specification
                    c.build_settings['CONFIGURATION_BUILD_DIR'] = target.configuration_build_dir('$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)')
                  end

                  # Set the correct device family for this bundle, based on the platform
                  device_family_by_platform = {
                    :ios => '1,2',
                    :tvos => '3',
                    :watchos => '1,2' # The device family for watchOS is 4, but Xcode creates watchkit-compatible bundles as 1,2
                  }

                  if (family = device_family_by_platform[target.platform.name])
                    c.build_settings['TARGETED_DEVICE_FAMILY'] = family
                  end
                end
              end
            end
          end

          # Generates the contents of the xcconfig file and saves it to disk.
          #
          # @return [void]
          #
          def create_xcconfig_file
            path = target.xcconfig_path
            xcconfig_gen = Generator::XCConfig::PodXCConfig.new(target)
            update_changed_file(xcconfig_gen, path)
            xcconfig_file_ref = add_file_to_support_group(path)

            native_target.build_configurations.each do |c|
              c.base_configuration_reference = xcconfig_file_ref
            end

            # also apply the private config to resource bundle targets.
            apply_xcconfig_file_ref_to_resource_bundle_targets(target.resource_bundle_targets, xcconfig_file_ref)
          end

          # Generates the contents of the xcconfig file used for each test target type and saves it to disk.
          #
          # @return [void]
          #
          def create_test_xcconfig_files
            target.supported_test_types.each do |test_type|
              path = target.xcconfig_path(test_type.to_s)
              xcconfig_gen = Generator::XCConfig::PodXCConfig.new(target, true)
              update_changed_file(xcconfig_gen, path)
              xcconfig_file_ref = add_file_to_support_group(path)

              target.test_native_targets.each do |test_target|
                test_target.build_configurations.each do |test_target_bc|
                  test_target_swift_debug_hack(test_target_bc)
                  test_target_bc.base_configuration_reference = xcconfig_file_ref
                end
              end

              # also apply the private config to resource bundle test targets.
              apply_xcconfig_file_ref_to_resource_bundle_targets(target.test_resource_bundle_targets, xcconfig_file_ref)
            end
          end

          # Creates a script that copies the resources to the bundle of the test target.
          #
          # @param [Symbol] test_type
          #        The test type to create the script for.
          #
          # @return [void]
          #
          def create_test_target_copy_resources_script(test_type)
            path = target.copy_resources_script_path_for_test_type(test_type)
            pod_targets = target.all_test_dependent_targets
            resource_paths_by_config = { 'Debug' => pod_targets.flat_map(&:resource_paths) }
            generator = Generator::CopyResourcesScript.new(resource_paths_by_config, target.platform)
            update_changed_file(generator, path)
            add_file_to_support_group(path)
          end

          # Creates a script that embeds the frameworks to the bundle of the test target.
          #
          # @param [Symbol] test_type
          #        The test type to create the script for.
          #
          # @return [void]
          #
          def create_test_target_embed_frameworks_script(test_type)
            path = target.embed_frameworks_script_path_for_test_type(test_type)
            pod_targets = target.all_test_dependent_targets
            framework_paths_by_config = { 'Debug' => pod_targets.flat_map(&:framework_paths) }
            generator = Generator::EmbedFrameworksScript.new(framework_paths_by_config)
            update_changed_file(generator, path)
            add_file_to_support_group(path)
          end

          # Manually add `libswiftSwiftOnoneSupport.dylib` as it seems there is an issue with tests that do not include it for Debug configurations.
          # Possibly related to Swift module optimization.
          #
          # @return [void]
          #
          def test_target_swift_debug_hack(test_target_bc)
            return unless test_target_bc.debug?
            return unless [target, *target.recursive_dependent_targets].any?(&:uses_swift?)
            ldflags = test_target_bc.build_settings['OTHER_LDFLAGS'] ||= '$(inherited)'
            ldflags << ' -lswiftSwiftOnoneSupport'
          end

          # Creates a build phase which links the versioned header folders
          # of the OS X into the framework bundle's root root directory.
          # This is only necessary because the way how headers are copied
          # via custom copy file build phases in combination with
          # header_mappings_dir interferes with xcodebuild's expectations
          # about the existence of private or public headers.
          #
          # @return [void]
          #
          def create_build_phase_to_symlink_header_folders
            return unless target.platform.name == :osx && header_mappings_dir

            build_phase = native_target.new_shell_script_build_phase('Create Symlinks to Header Folders')
            build_phase.shell_script = <<-eos.strip_heredoc
          base="$CONFIGURATION_BUILD_DIR/$WRAPPER_NAME"
          ln -fs "$base/${PUBLIC_HEADERS_FOLDER_PATH\#$WRAPPER_NAME/}" "$base/${PUBLIC_HEADERS_FOLDER_PATH\#\$CONTENTS_FOLDER_PATH/}"
          ln -fs "$base/${PRIVATE_HEADERS_FOLDER_PATH\#\$WRAPPER_NAME/}" "$base/${PRIVATE_HEADERS_FOLDER_PATH\#\$CONTENTS_FOLDER_PATH/}"
            eos
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
            update_changed_file(generator, path)
            add_file_to_support_group(path)

            native_target.build_configurations.each do |c|
              relative_path = path.relative_path_from(project.path.dirname)
              c.build_settings['GCC_PREFIX_HEADER'] = relative_path.to_s
            end
          end

          ENABLE_OBJECT_USE_OBJC_FROM = {
            :ios => Version.new('6'),
            :osx => Version.new('10.8'),
            :watchos => Version.new('2.0'),
            :tvos => Version.new('9.0'),
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
            if target.inhibit_warnings?
              flags << '-w -Xanalyzer -analyzer-disable-all-checks'
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

          def apply_xcconfig_file_ref_to_resource_bundle_targets(resource_bundle_targets, xcconfig_file_ref)
            resource_bundle_targets.each do |rsrc_target|
              rsrc_target.build_configurations.each do |rsrc_bc|
                rsrc_bc.base_configuration_reference = xcconfig_file_ref
              end
            end
          end

          def create_module_map
            return super unless custom_module_map
            path = target.module_map_path
            UI.message "- Copying module map file to #{UI.path(path)}" do
              unless path.exist? && FileUtils.identical?(custom_module_map, path)
                FileUtils.cp(custom_module_map, path)
              end
              add_file_to_support_group(path)

              native_target.build_configurations.each do |c|
                relative_path = path.relative_path_from(sandbox.root)
                c.build_settings['MODULEMAP_FILE'] = relative_path.to_s
              end
            end
          end

          def create_umbrella_header
            return super unless custom_module_map
          end

          def custom_module_map
            @custom_module_map ||= target.file_accessors.first.module_map
          end

          def project_file_references_array(files, file_type)
            files.map do |sf|
              project.reference_for_path(sf).tap do |ref|
                raise Informative, "Unable to find #{file_type} ref for #{sf} for target #{target.name}." unless ref
              end
            end
          end

          def header_mappings_dir
            return @header_mappings_dir if defined?(@header_mappings_dir)
            file_accessor = target.file_accessors.first
            @header_mappings_dir = if dir = file_accessor.spec_consumer.header_mappings_dir
                                     file_accessor.path_list.root + dir
                                   end
          end

          def add_header(build_file, public_headers, private_headers, native_target)
            file_ref = build_file.file_ref
            acl = if public_headers.include?(file_ref.real_path)
                    'Public'
                  elsif private_headers.include?(file_ref.real_path)
                    'Private'
                  else
                    'Project'
                  end

            if target.requires_frameworks? && header_mappings_dir && acl != 'Project'
              relative_path = file_ref.real_path.relative_path_from(header_mappings_dir)
              sub_dir = relative_path.dirname
              copy_phase_name = "Copy #{sub_dir} #{acl} Headers"
              copy_phase = native_target.copy_files_build_phases.find { |bp| bp.name == copy_phase_name } ||
                native_target.new_copy_files_build_phase(copy_phase_name)
              copy_phase.symbol_dst_subfolder_spec = :products_directory
              copy_phase.dst_path = "$(#{acl.upcase}_HEADERS_FOLDER_PATH)/#{sub_dir}"
              copy_phase.add_file_reference(file_ref, true)
            else
              build_file.settings ||= {}
              build_file.settings['ATTRIBUTES'] = [acl]
            end
          end

          #-----------------------------------------------------------------------#
        end
      end
    end
  end
end
