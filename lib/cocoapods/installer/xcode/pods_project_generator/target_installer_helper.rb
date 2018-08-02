module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        module TargetInstallerHelper
          # @param [Generator] generator
          #        the generator to use for generating the content.
          #
          # @param [Pathname] path
          #        the pathname to save the content into.
          #
          # Saves the content the provided path unless the path exists and the contents are exactly the same.
          #
          def update_changed_file(generator, path)
            if path.exist?
              contents = generator.generate.to_s
              content_stream = StringIO.new(contents)
              identical = File.open(path, 'rb') { |f| FileUtils.compare_stream(f, content_stream) }
              return if identical

              File.open(path, 'w') { |f| f.write(contents) }
            else
              path.dirname.mkpath
              generator.save_as(path)
            end
          end

          # Creates the Info.plist file which sets public framework attributes
          #
          # @param  [Sandbox] sandbox @see #sandbox
          #         The sandbox where the generated Info.plist file should be saved.
          #
          # @param  [Pathname] path
          #         the path to save the generated Info.plist file.
          #
          # @param  [PBXNativeTarget] native_target
          #         the native target to link the generated Info.plist file into.
          #
          # @param  [Version] version
          #         the version to use for when generating this Info.plist file.
          #
          # @param  [Platform] platform
          #         the platform to use for when generating this Info.plist file.
          #
          # @param  [Symbol] bundle_package_type
          #         the CFBundlePackageType of the target this Info.plist file is for.
          #
          #  @param [Hash] additional_entries
          #         any additional entries to include in this Info.plist file.
          #
          # @return [void]
          #
          def create_info_plist_file_with_sandbox(sandbox, path, native_target, version, platform,
                                                  bundle_package_type = :fmwk, additional_entries = {})
            UI.message "- Generating Info.plist file at #{UI.path(path)}" do
              generator = Generator::InfoPlistFile.new(version, platform, bundle_package_type, additional_entries)
              update_changed_file(generator, path)

              relative_path_string = path.relative_path_from(sandbox.root).to_s
              native_target.build_configurations.each do |c|
                c.build_settings['INFOPLIST_FILE'] = relative_path_string
              end
            end
          end

          module_function :update_changed_file
          module_function :create_info_plist_file_with_sandbox
        end
      end
    end
  end
end
