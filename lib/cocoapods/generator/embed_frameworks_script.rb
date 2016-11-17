module Pod
  module Generator
    class EmbedFrameworksScript
      # @return [Hash{String => Array<String>}] Multiple lists of frameworks per
      #         configuration.
      #
      attr_reader :frameworks_by_config

      # @param  [Hash{String => Array<String>] frameworks_by_config
      #         @see #frameworks_by_config
      #
      def initialize(frameworks_by_config)
        @frameworks_by_config = frameworks_by_config
      end

      # Saves the resource script to the given pathname.
      #
      # @param  [Pathname] pathname
      #         The path where the embed frameworks script should be saved.
      #
      # @return [void]
      #
      def save_as(pathname)
        pathname.open('w') do |file|
          file.puts(script)
        end
        File.chmod(0755, pathname.to_s)
      end

      private

      # @!group Private Helpers

      # @return [String] The contents of the embed frameworks script.
      #
      def script
        script = <<-SH.strip_heredoc
          #!/bin/sh
          set -e

          echo "mkdir -p ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
          mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

          SWIFT_STDLIB_PATH="${DT_TOOLCHAIN_DIR}/usr/lib/swift/${PLATFORM_NAME}"

          install_framework()
          {
            if [ -r "${BUILT_PRODUCTS_DIR}/$1" ]; then
              local source="${BUILT_PRODUCTS_DIR}/$1"
            elif [ -r "${BUILT_PRODUCTS_DIR}/$(basename "$1")" ]; then
              local source="${BUILT_PRODUCTS_DIR}/$(basename "$1")"
            elif [ -r "$1" ]; then
              local source="$1"
            fi

            local destination="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

            if [ -L "${source}" ]; then
                echo "Symlinked..."
                source="$(readlink "${source}")"
            fi

            # use filter instead of exclude so missing patterns dont' throw errors
            echo "rsync -av --filter \\"- CVS/\\" --filter \\"- .svn/\\" --filter \\"- .git/\\" --filter \\"- .hg/\\" --filter \\"- Headers\\" --filter \\"- PrivateHeaders\\" --filter \\"- Modules\\" \\"${source}\\" \\"${destination}\\""
            rsync -av --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" --filter "- Headers" --filter "- PrivateHeaders" --filter "- Modules" "${source}" "${destination}"

            local basename
            basename="$(basename -s .framework "$1")"
            binary="${destination}/${basename}.framework/${basename}"
            if ! [ -r "$binary" ]; then
              binary="${destination}/${basename}"
            fi

            # Strip invalid architectures so "fat" simulator / device frameworks work on device
            if [[ "$(file "$binary")" == *"dynamically linked shared library"* ]]; then
              strip_invalid_archs "$binary"
            fi

            # Resign the code if required by the build settings to avoid unstable apps
            code_sign_if_enabled "${destination}/$(basename "$1")"

            # Embed linked Swift runtime libraries. No longer necessary as of Xcode 7.
            if [ "${XCODE_VERSION_MAJOR}" -lt 7 ]; then
              local swift_runtime_libs
              swift_runtime_libs=$(xcrun otool -LX "$binary" | grep --color=never @rpath/libswift | sed -E s/@rpath\\\\/\\(.+dylib\\).*/\\\\1/g | uniq -u  && exit ${PIPESTATUS[0]})
              for lib in $swift_runtime_libs; do
                echo "rsync -auv \\"${SWIFT_STDLIB_PATH}/${lib}\\" \\"${destination}\\""
                rsync -auv "${SWIFT_STDLIB_PATH}/${lib}" "${destination}"
                code_sign_if_enabled "${destination}/${lib}"
              done
            fi
          }

          # Signs a framework with the provided identity
          code_sign_if_enabled() {
            if [ -n "${EXPANDED_CODE_SIGN_IDENTITY}" -a "${CODE_SIGNING_REQUIRED}" != "NO" -a "${CODE_SIGNING_ALLOWED}" != "NO" ]; then
              # Use the current code_sign_identitiy
              echo "Code Signing $1 with Identity ${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
              local code_sign_cmd="/usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} ${OTHER_CODE_SIGN_FLAGS} --preserve-metadata=identifier,entitlements '$1'"

              if [ "${COCOAPODS_PARALLEL_CODE_SIGN}" == "true" ]; then
                code_sign_cmd="$code_sign_cmd &"
              fi
              echo "$code_sign_cmd"
              eval "$code_sign_cmd"
            fi
          }

          # Strip invalid architectures
          strip_invalid_archs() {
            binary="$1"
            # Get architectures for current file
            archs="$(lipo -info "$binary" | rev | cut -d ':' -f1 | rev)"
            stripped=""
            for arch in $archs; do
              if ! [[ "${VALID_ARCHS}" == *"$arch"* ]]; then
                # Strip non-valid architectures in-place
                lipo -remove "$arch" -output "$binary" "$binary" || exit 1
                stripped="$stripped $arch"
              fi
            done
            if [[ "$stripped" ]]; then
              echo "Stripped $binary of architectures:$stripped"
            fi
          }

        SH
        script << "\n" unless frameworks_by_config.values.all?(&:empty?)
        frameworks_by_config.each do |config, frameworks|
          unless frameworks.empty?
            script << %(if [[ "$CONFIGURATION" == "#{config}" ]]; then\n)
            frameworks.each do |framework|
              script << %(  install_framework "#{framework}"\n)
            end
            script << "fi\n"
          end
        end
        script << <<-SH.strip_heredoc
        if [ "${COCOAPODS_PARALLEL_CODE_SIGN}" == "true" ]; then
          wait
        fi
        SH
        script
      end
    end
  end
end
