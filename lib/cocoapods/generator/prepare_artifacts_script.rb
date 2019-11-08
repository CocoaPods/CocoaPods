require 'cocoapods/xcode'

module Pod
  module Generator
    class PrepareArtifactsScript
      # @return [Hash{String => Array<Pod::Xcode::XCFramework>}] Multiple lists of xcframeworks per
      #         configuration.
      #
      attr_reader :xcframeworks_by_config

      # @return [Pathname] the root directory of the sandbox
      #
      attr_reader :sandbox_root

      # @param  [Hash{String => Array<Pod::Xcode::XCFramework>] xcframeworks_by_config
      #         @see #xcframeworks_by_config
      #
      # @param  [Pathname] sandbox_root
      #         the sandbox root of the installation
      #
      def initialize(xcframeworks_by_config, sandbox_root)
        @xcframeworks_by_config = xcframeworks_by_config
        @sandbox_root = sandbox_root
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

      # @return [String] The contents of the embed frameworks script.
      #
      def generate
        script
      end

      private

      # @!group Private Helpers

      # @return [String] The contents of the prepare artifacts script.
      #
      def script
        script = <<-SH.strip_heredoc
          #!/bin/sh
          set -e
          set -u
          set -o pipefail

          function on_error {
            echo "$(realpath -mq "${0}"):$1: error: Unexpected failure"
          }
          trap 'on_error $LINENO' ERR

          if [ -z ${FRAMEWORKS_FOLDER_PATH+x} ]; then
            # If FRAMEWORKS_FOLDER_PATH is not set, then there's nowhere for us to copy
            # frameworks to, so exit 0 (signalling the script phase was successful).
            exit 0
          fi

          # This protects against multiple targets copying the same framework dependency at the same time. The solution
          # was originally proposed here: https://lists.samba.org/archive/rsync/2008-February/020158.html
          RSYNC_PROTECT_TMP_FILES=(--filter "P .*.??????")

          ARTIFACT_LIST_FILE="${BUILT_PRODUCTS_DIR}/cocoapods-artifacts-${CONFIGURATION}.txt"
          cat > $ARTIFACT_LIST_FILE

          record_artifact()
          {
            echo "$1" >> $ARTIFACT_LIST_FILE
          }

          # Copies a framework to derived data for use in later build phases
          install_framework()
          {
            if [ -r "${BUILT_PRODUCTS_DIR}/$1" ]; then
              local source="${BUILT_PRODUCTS_DIR}/$1"
            elif [ -r "${BUILT_PRODUCTS_DIR}/$(basename "$1")" ]; then
              local source="${BUILT_PRODUCTS_DIR}/$(basename "$1")"
            elif [ -r "$1" ]; then
              local source="$1"
            fi

            local strip_archs=${2:-true}
            local destination="${TARGET_BUILD_DIR}"

            if [ -L "${source}" ]; then
              echo "Symlinked..."
              source="$(readlink "${source}")"
            fi

            # Use filter instead of exclude so missing patterns don't throw errors.
            echo "rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter \\"- CVS/\\" --filter \\"- .svn/\\" --filter \\"- .git/\\" --filter \\"- .hg/\\" \\"${source}\\" \\"${destination}\\""
            rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" "${source}" "${destination}"

            local basename
            basename="$(basename -s .framework "$1")"
            binary="${destination}/${basename}.framework/${basename}"

            if ! [ -r "$binary" ]; then
              binary="${destination}/${basename}"
            fi

            record_artifact "$(dirname "${binary}")"
          }

          install_xcframework() {
            local basepath="$1"
            shift
            local paths=("$@")
            
            # Locate the correct slice of the .xcframework for the current architectures
            local target_path=""
            local target_arch="$ARCHS"
            local target_variant=""
            if [[ "$PLATFORM_NAME" == *"simulator" ]]; then
              target_variant="simulator"
            fi
            if [[ "$EFFECTIVE_PLATFORM_NAME" == *"maccatalyst" ]]; then
              target_variant="maccatalyst"
            fi
            for i in ${!paths[@]}; do
              if [[ "${paths[$i]}" == *"$target_arch"* ]] && [[ "${paths[$i]}" == *"$target_variant"* ]]; then
                # Found a matching slice
                echo "Selected xcframework slice ${paths[$i]}"
                target_path=${paths[$i]}
                break;
              fi
            done
            
            if [[ -z "$target_path" ]]; then
              echo "warning: [CP] Unable to find matching .xcframework slice in '${paths[@]}' for the current build architectures ($ARCHS)."
              return
            fi

            install_framework "$basepath/$target_path"
          }

        SH
        contents_by_config = Hash.new do |hash, key|
          hash[key] = ""
        end
        xcframeworks_by_config.each do |config, xcframeworks|
          next if xcframeworks.empty?
          xcframeworks.each do |xcframework|
            # It's possible for an .xcframework to include slices of different linkages,
            # so we must select only dynamic slices to pass to the script
            slices = xcframework.slices
                       .select { |slice| Xcode::LinkageAnalyzer.dynamic_binary?(slice.binary_path) }
            next if slices.empty?
            relative_path = xcframework.path.relative_path_from(sandbox_root)
            args = [shell_escape("${PODS_ROOT}/#{relative_path}")]
            slices.each do |slice|
              args << shell_escape(slice.path.relative_path_from(xcframework.path))
            end
            # We pass two arrays to install_xcframework - a nested list of archs, and a list of paths that
            # contain frameworks for those archs
            contents_by_config[config] << %(  install_xcframework #{args.join(" ")}\n)
          end
        end

        script << "\n" unless contents_by_config.empty?
        contents_by_config.keys.sort.each do |config|
          contents = contents_by_config[config]
          next if contents.empty?
          script << %(if [[ "$CONFIGURATION" == "#{config}" ]]; then\n)
          script << contents
          script << "fi\n"
        end

        script << "\necho \"Artifact list stored at $ARTIFACT_LIST_FILE\"\n"
        script << "\ncat \"$ARTIFACT_LIST_FILE\"\n"
        script
      end

      def shell_escape(value)
        "\"#{value}\""
      end
    end
  end
end
