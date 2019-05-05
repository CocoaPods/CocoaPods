module Pod
  module Generator
    class CombineXCAssetsScript
      # TODO
      #
      attr_reader :xcassets_paths

      # Initialize a new instance
      #
      # @param  [Array<Something>] xcassets_paths @see #xcasset_paths
      #
      def initialize(xcassets_paths)
        @xcassets_paths = xcassets_paths
      end

      # Saves the combine xcassets script to the given pathname.
      #
      # @param  [Pathname] pathname
      #         The path where the copy resources script should be saved.
      #
      # @return [void]
      #
      def save_as(pathname)
        pathname.open('w') do |file|
          file.puts(generate)
        end
        File.chmod(0755, pathname.to_s)
      end

      # @return [String] The contents of the combine xcassets script.
      #
      def generate
        <<-SH.strip_heredoc
#!/bin/sh

if [[ -n "${WRAPPER_EXTENSION}" ]] && [ "`xcrun --find actool`" ]
then
  ASSET_FILES=( "#{xcassets_paths.map { |p| p.to_s }.join('" "')}")
  ASSET_FILES+=( "${XCASSET_FILES[@]}" "${XCASSET_FILES[@]}" )
  if [ -z ${ASSETCATALOG_COMPILER_APPICON_NAME+x} ]; then
    printf "%s\\0" "${ASSET_FILES[@]}" | xargs -0 xcrun actool --output-format human-readable-text --notices --warnings --platform "${PLATFORM_NAME}" --minimum-deployment-target "${!DEPLOYMENT_TARGET_SETTING_NAME}" ${TARGET_DEVICE_ARGS} --compress-pngs --compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
  else
    printf "%s\\0" "${ASSET_FILES[@]}" | xargs -0 xcrun actool --output-format human-readable-text --notices --warnings --platform "${PLATFORM_NAME}" --minimum-deployment-target "${!DEPLOYMENT_TARGET_SETTING_NAME}" ${TARGET_DEVICE_ARGS} --compress-pngs --compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" --app-icon "${ASSETCATALOG_COMPILER_APPICON_NAME}" --output-partial-info-plist "${TARGET_TEMP_DIR}/assetcatalog_generated_info_cocoapods.plist"
  fi
fi
        SH
      end
    end
  end
end
