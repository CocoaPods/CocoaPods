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
            DESTINATION="${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
            echo "rsync -av \\"${BUILT_PRODUCTS_DIR}/#{target_definition.label}/$1\\" \\"${DESTINATION}\\""
            rsync -av "${BUILT_PRODUCTS_DIR}/#{target_definition.label}/$1" "${DESTINATION}"
            BASENAME=$(echo $1 | sed -E s/\\\\..+//)
            SWIFT_RUNTIME_LIBS=$(otool -LX "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/$1/$BASENAME" | grep libswift | sed -E s/@rpath\\\\/\\(.+dylib\\).*/\\\\1/g | uniq -u)
            for LIB in $SWIFT_RUNTIME_LIBS
            do
              echo "rsync -av \\"${SWIFT_STDLIB_PATH}/${LIB}\\" \\"${DESTINATION}\\""
              rsync -av "${SWIFT_STDLIB_PATH}/${LIB}" "${DESTINATION}"
            done
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
