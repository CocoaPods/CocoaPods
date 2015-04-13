module Pod
  module Generator
    class EmbedFrameworksScript
      # @return [TargetDefinition] The target definition, whose label will be
      #         used to locate the target-specific build products.
      #
      attr_reader :target_definition

      # @return [Hash{String, Array{String}] Multiple lists of frameworks per
      #         configuration.
      #
      attr_reader :frameworks_by_config

      # @param  [TargetDefinition] target_definition
      #         @see #target_definition
      #
      # @param  [Hash{String, Array{String}] frameworks_by_config
      #         @see #frameworks_by_config
      #
      def initialize(target_definition, frameworks_by_config)
        @target_definition = target_definition
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
        script = <<-eos.strip_heredoc
          #!/bin/sh
          set -e

          echo "mkdir -p ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
          mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

          SWIFT_STDLIB_PATH="${DT_TOOLCHAIN_DIR}/usr/lib/swift/${PLATFORM_NAME}"

          install_framework()
          {
            local source="${BUILT_PRODUCTS_DIR}/#{target_definition.label}/$1"
            local destination="${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

            if [ -L "${source}" ]; then
                echo "Symlinked..."
                source=$(readlink "${source}")
            fi

            # use filter instead of exclude so missing patterns dont' throw errors
            echo "rsync -av --filter \"- CVS/\" --filter \"- .svn/\" --filter \"- .git/\" --filter \"- .hg/\" --filter \"- Headers/\" --filter \"- PrivateHeaders/\" --filter \"- Modules/\" ${source} ${destination}"
            rsync -av --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" --filter "- Headers/" --filter "- PrivateHeaders/" --filter "- Modules/" "${source}" "${destination}"
            # Resign the code if required by the build settings to avoid unstable apps
            if [ "${CODE_SIGNING_REQUIRED}" == "YES" ]; then
                code_sign "${destination}/$1"
            fi

            # Embed linked Swift runtime libraries
            local basename
            basename=$(echo $1 | sed -E s/\\\\..+// && exit ${PIPESTATUS[0]})
            local swift_runtime_libs
            swift_runtime_libs=$(xcrun otool -LX "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/$1/${basename}" | grep --color=never @rpath/libswift | sed -E s/@rpath\\\\/\\(.+dylib\\).*/\\\\1/g | uniq -u  && exit ${PIPESTATUS[0]})
            for lib in $swift_runtime_libs; do
              echo "rsync -auv \\"${SWIFT_STDLIB_PATH}/${lib}\\" \\"${destination}\\""
              rsync -auv "${SWIFT_STDLIB_PATH}/${lib}" "${destination}"
              if [ "${CODE_SIGNING_REQUIRED}" == "YES" ]; then
                code_sign "${destination}/${lib}"
              fi
            done
          }

          # Signs a framework with the provided identity
          code_sign() {
            # Use the current code_sign_identitiy
            echo "Code Signing $1 with Identity ${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
            echo "/usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} --preserve-metadata=identifier,entitlements $1"
            /usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} --preserve-metadata=identifier,entitlements "$1"
          }

        eos
        script += "\n" unless frameworks_by_config.values.all?(&:empty?)
        frameworks_by_config.each do |config, frameworks|
          unless frameworks.empty?
            script += %(if [[ "$CONFIGURATION" == "#{config}" ]]; then\n)
            frameworks.each do |framework|
              script += "  install_framework '#{framework}'\n"
            end
            script += "fi\n"
          end
        end
        script
      end
    end
  end
end
