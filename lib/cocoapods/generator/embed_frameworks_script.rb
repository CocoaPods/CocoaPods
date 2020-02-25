require 'cocoapods/xcode'

module Pod
  module Generator
    class EmbedFrameworksScript
      # @return [Hash{String => Array<FrameworkPaths>}] Multiple lists of frameworks per
      #         configuration.
      #
      attr_reader :frameworks_by_config

      # @param  [Hash{String => Array<FrameworkPaths>] frameworks_by_config
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

      # @return [String] The contents of the embed frameworks script.
      #
      def generate
        script
      end

      private

      # @!group Private Helpers

      # @return [String] The contents of the embed frameworks script.
      #
      def script
        script = <<-SH.strip_heredoc
#{Pod::Generator::ScriptPhaseConstants::DEFAULT_SCRIPT_PHASE_HEADER}
if [ -z ${FRAMEWORKS_FOLDER_PATH+x} ]; then
  # If FRAMEWORKS_FOLDER_PATH is not set, then there's nowhere for us to copy
  # frameworks to, so exit 0 (signalling the script phase was successful).
  exit 0
fi

echo "mkdir -p ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

COCOAPODS_PARALLEL_CODE_SIGN="${COCOAPODS_PARALLEL_CODE_SIGN:-false}"
SWIFT_STDLIB_PATH="${DT_TOOLCHAIN_DIR}/usr/lib/swift/${PLATFORM_NAME}"

#{Pod::Generator::ScriptPhaseConstants::RSYNC_PROTECT_TMP_FILES}
# Copies and strips a vendored framework
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

  # Use filter instead of exclude so missing patterns don't throw errors.
  echo "rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter \\"- CVS/\\" --filter \\"- .svn/\\" --filter \\"- .git/\\" --filter \\"- .hg/\\" --filter \\"- Headers\\" --filter \\"- PrivateHeaders\\" --filter \\"- Modules\\" \\"${source}\\" \\"${destination}\\""
  rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" --filter "- Headers" --filter "- PrivateHeaders" --filter "- Modules" "${source}" "${destination}"

  local basename
  basename="$(basename -s .framework "$1")"
  binary="${destination}/${basename}.framework/${basename}"

  if ! [ -r "$binary" ]; then
    binary="${destination}/${basename}"
  elif [ -L "${binary}" ]; then
    echo "Destination binary is symlinked..."
    dirname="$(dirname "${binary}")"
    binary="${dirname}/$(readlink "${binary}")"
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
    swift_runtime_libs=$(xcrun otool -LX "$binary" | grep --color=never @rpath/libswift | sed -E s/@rpath\\\\/\\(.+dylib\\).*/\\\\1/g | uniq -u)
    for lib in $swift_runtime_libs; do
      echo "rsync -auv \\"${SWIFT_STDLIB_PATH}/${lib}\\" \\"${destination}\\""
      rsync -auv "${SWIFT_STDLIB_PATH}/${lib}" "${destination}"
      code_sign_if_enabled "${destination}/${lib}"
    done
  fi
}
#{Pod::Generator::ScriptPhaseConstants::INSTALL_DSYM_METHOD}
#{Pod::Generator::ScriptPhaseConstants::STRIP_INVALID_ARCHITECTURES_METHOD}
# Copies the bcsymbolmap files of a vendored framework
install_bcsymbolmap() {
    local bcsymbolmap_path="$1"
    local destination="${BUILT_PRODUCTS_DIR}"
    echo "rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --filter \"- CVS/\" --filter \"- .svn/\" --filter \"- .git/\" --filter \"- .hg/\" --filter \"- Headers\" --filter \"- PrivateHeaders\" --filter \"- Modules\" \"${bcsymbolmap_path}\" \"${destination}\""
    rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" --filter "- Headers" --filter "- PrivateHeaders" --filter "- Modules" "${bcsymbolmap_path}" "${destination}"
}

# Signs a framework with the provided identity
code_sign_if_enabled() {
  if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" -a "${CODE_SIGNING_REQUIRED:-}" != "NO" -a "${CODE_SIGNING_ALLOWED}" != "NO" ]; then
    # Use the current code_sign_identity
    echo "Code Signing $1 with Identity ${EXPANDED_CODE_SIGN_IDENTITY_NAME}"
    local code_sign_cmd="/usr/bin/codesign --force --sign ${EXPANDED_CODE_SIGN_IDENTITY} ${OTHER_CODE_SIGN_FLAGS:-} --preserve-metadata=identifier,entitlements '$1'"

    if [ "${COCOAPODS_PARALLEL_CODE_SIGN}" == "true" ]; then
      code_sign_cmd="$code_sign_cmd &"
    fi
    echo "$code_sign_cmd"
    eval "$code_sign_cmd"
  fi
}

install_artifact() {
  artifact="$1"
  base="$(basename "$artifact")"
  case $base in
  *.framework)
    install_framework "$artifact"
    ;;
  *.dSYM)
    # Suppress arch warnings since XCFrameworks will include many dSYM files
    install_dsym "$artifact" "false"
    ;;
  *.bcsymbolmap)
    install_bcsymbolmap "$artifact"
    ;;
  *)
    echo "error: Unrecognized artifact "$artifact""
    ;;
  esac
}

copy_artifacts() {
  file_list="$1"
  while read artifact; do
    install_artifact "$artifact"
  done <$file_list
}

ARTIFACT_LIST_FILE="${BUILT_PRODUCTS_DIR}/cocoapods-artifacts-${CONFIGURATION}.txt"
if [ -r "${ARTIFACT_LIST_FILE}" ]; then
  copy_artifacts "${ARTIFACT_LIST_FILE}"
fi

        SH
        frameworks_by_config.each do |config, frameworks_with_dsyms|
          next if frameworks_with_dsyms.empty?
          script << %(if [[ "$CONFIGURATION" == "#{config}" ]]; then\n)
          frameworks_with_dsyms.each do |framework_with_dsym|
            script << %(  install_framework "#{framework_with_dsym.source_path}"\n)
            unless framework_with_dsym.bcsymbolmap_paths.nil?
              framework_with_dsym.bcsymbolmap_paths.each do |bcsymbolmap_path|
                script << %(  install_bcsymbolmap "#{bcsymbolmap_path}"\n)
              end
            end
          end
          script << "fi\n"
        end
        script << <<-SH.strip_heredoc
        if [ "${COCOAPODS_PARALLEL_CODE_SIGN}" == "true" ]; then
          wait
        fi
        SH
        script
      end

      # @param  [Xcode::FrameworkPaths] framework_path
      #         the framework path containing the dSYM
      #
      # @return [String, Nil] the name of the dSYM binary, if found
      #
      def dsym_binary_name(framework_path)
        return nil if framework_path.dsym_path.nil?
        if (path = Pathname.glob(framework_path.dsym_path.join('Contents/Resources/DWARF', '**/*')).first)
          File.basename(path)
        end
      end
    end
  end
end
