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

      # @return [Platform] the platform of the target for which this script will run
      #
      attr_reader :platform

      # @param  [Hash{String => Array<Pod::Xcode::XCFramework>] xcframeworks_by_config
      #         @see #xcframeworks_by_config
      #
      # @param  [Pathname] sandbox_root
      #         the sandbox root of the installation
      #
      # @param  [Platform] platform
      #         the platform of the target for which this script will run
      #
      def initialize(xcframeworks_by_config, sandbox_root, platform)
        @xcframeworks_by_config = xcframeworks_by_config
        @sandbox_root = sandbox_root
        @platform = platform
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
        File.chmod(0o755, pathname.to_s)
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

          BCSYMBOLMAP_DIR="BCSymbolMaps"

          record_artifact()
          {
            echo "$1" >> $ARTIFACT_LIST_FILE
          }

          install_artifact()
          {
            local source="$1"
            local destination="$2"
            local record=${3:-false}

            # Use filter instead of exclude so missing patterns don't throw errors.
            echo "rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter \\"- CVS/\\" --filter \\"- .svn/\\" --filter \\"- .git/\\" --filter \\"- .hg/\\" \\"${source}\\" \\"${destination}\\""
            rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" "${source}" "${destination}"

            if [[ "$record" == "true" ]]; then
              artifact="${destination}/$(basename "$source")"
              record_artifact "$artifact"
            fi
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

            local record_artifact=${2:-true}
            local destination="${CONFIGURATION_BUILD_DIR}"

            if [ -L "${source}" ]; then
              echo "Symlinked..."
              source="$(readlink "${source}")"
            fi

            install_artifact "$source" "$destination" "$record_artifact"

            if [ -d "${source}/${BCSYMBOLMAP_DIR}" ]; then
              # Locate and install any .bcsymbolmaps if present
              find "${source}/${BCSYMBOLMAP_DIR}/" -name "*.bcsymbolmap"|while read f; do
                install_artifact "$f" "$destination" "true"
              done
            fi
          }

          install_xcframework() {
            local basepath="$1"
            local dsym_folder="$2"
            local embed="$3"
            shift
            local paths=("$@")

            # Locate the correct slice of the .xcframework for the current architectures
            local target_path=""
            local target_arch="$ARCHS"

            # Replace spaces in compound architectures with _ to match slice format
            target_arch=${target_arch//\ /_}

            local target_variant=""
            if [[ "$PLATFORM_NAME" == *"simulator" ]]; then
              target_variant="simulator"
            fi
            if [[ ! -z ${EFFECTIVE_PLATFORM_NAME+x} && "$EFFECTIVE_PLATFORM_NAME" == *"maccatalyst" ]]; then
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

            install_framework "$basepath/$target_path" "$embed"

            if [[ -z "$dsym_folder" || ! -d "$dsym_folder" ]]; then
              return
            fi

            dsyms=($(ls "$dsym_folder"))

            local target_dsym=""
            for i in ${!dsyms[@]}; do
              install_artifact "$dsym_folder/${dsyms[$i]}" "$CONFIGURATION_BUILD_DIR" "true"
            done
          }

        SH
        contents_by_config = Hash.new do |hash, key|
          hash[key] = ''
        end
        xcframeworks_by_config.each do |config, xcframeworks|
          next if xcframeworks.empty?
          xcframeworks.each do |xcframework|
            slices = xcframework.slices.select { |f| f.platform.symbolic_name == platform.symbolic_name }
            dynamic_slices, static_slices = slices.partition { |slice| Xcode::LinkageAnalyzer.dynamic_binary?(slice.binary_path) }
            next if dynamic_slices.empty? && static_slices.empty?
            unless dynamic_slices.empty?
              args = install_xcframework_args(xcframework.path, dynamic_slices, false)
              contents_by_config[config] << %(  install_xcframework #{args}\n)
            end

            unless static_slices.empty?
              args = install_xcframework_args(xcframework.path, static_slices, true)
              contents_by_config[config] << %(  install_xcframework #{args}\n)
            end
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

      def install_xcframework_args(root, slices, static)
        args = [shell_escape("${PODS_ROOT}/#{root.relative_path_from(sandbox_root)}")]
        dsym_folder_arg = if (dsym_folder = PrepareArtifactsScript.dsym_folder(root))
                            shell_escape("${PODS_ROOT}/#{dsym_folder.relative_path_from(sandbox_root)}")
                          else
                            '""'
                          end
        args << dsym_folder_arg
        embed = static ? 'false' : 'true'
        args << shell_escape(embed)
        slices.each do |slice|
          args << shell_escape(slice.path.relative_path_from(root))
        end
        args.join(' ')
      end

      class << self
        # @param  [Pathname] xcframework_path
        #         the base path of the .xcframework bundle
        #
        # @return [Array<Pathname>] all found .dSYM paths
        #
        def dsym_folder(xcframework_path)
          basename = File.basename(xcframework_path, '.xcframework')
          dsym_basename = basename + '.dSYMs'
          path = xcframework_path.dirname + dsym_basename
          Pathname.new(path) if File.directory?(path)
        end
      end
    end
  end
end
