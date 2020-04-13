require 'cocoapods/xcode'

module Pod
  module Generator
    class CopyXCFrameworksScript
      # @return [Array<Pod::Xcode::XCFramework>] Lists of xcframeworks to copy
      #
      attr_reader :xcframeworks

      # @return [Pathname] the root directory of the sandbox
      #
      attr_reader :sandbox_root

      # @return [Platform] the platform of the target for which this script will run
      #
      attr_reader :platform

      # @param  [Array<Pod::Xcode::XCFramework>] xcframeworks
      #         @see #xcframeworks
      #
      # @param  [Pathname] sandbox_root
      #         the sandbox root of the installation
      #
      # @param  [Platform] platform
      #         the platform of the target for which this script will run
      #
      def initialize(xcframeworks, sandbox_root, platform)
        @xcframeworks = xcframeworks
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
#{Pod::Generator::ScriptPhaseConstants::DEFAULT_SCRIPT_PHASE_HEADER}

#{Pod::Generator::ScriptPhaseConstants::RSYNC_PROTECT_TMP_FILES}

copy_dir()
{
  local source="$1"
  local destination="$2"

  # Use filter instead of exclude so missing patterns don't throw errors.
  echo "rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter \\"- CVS/\\" --filter \\"- .svn/\\" --filter \\"- .git/\\" --filter \\"- .hg/\\" \\"${source}\\" \\"${destination}\\""
  rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" "${source}" "${destination}"
}

SELECT_SLICE_RETVAL=""

select_slice() {
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
      SELECT_SLICE_RETVAL=${paths[$i]}
      break;
    fi
  done
}

install_library() {
  local source="$1"
  local name="$2"
  local destination="#{Target::BuildSettings::XCFRAMEWORKS_BUILD_DIR_VARIABLE}/${name}"

  # Libraries can contain headers, module maps, and a binary, so we'll copy everything in the folder over

  local source="$binary"
  echo "rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter \\"- CVS/\\" --filter \\"- .svn/\\" --filter \\"- .git/\\" --filter \\"- .hg/\\" \\"${source}/*\\" \\"${destination}\\""
  rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" "${source}/*" "${destination}"
}

# Copies a framework to derived data for use in later build phases
install_framework()
{
  local source="$1"
  local name="$2"
  local destination="#{Pod::Target::BuildSettings::XCFRAMEWORKS_BUILD_DIR_VARIABLE}/${name}"

  if [ ! -d "$destination" ]; then
    mkdir -p "$destination"
  fi

  copy_dir "$source" "$destination"
  echo "Copied $source to $destination"
}

install_xcframework_library() {
  local basepath="$1"
  local name="$2"
  local paths=("$@")

  # Locate the correct slice of the .xcframework for the current architectures
  select_slice "${paths[@]}"
  local target_path="$SELECT_SLICE_RETVAL"
  if [[ -z "$target_path" ]]; then
    echo "warning: [CP] Unable to find matching .xcframework slice in '${paths[@]}' for the current build architectures ($ARCHS)."
    return
  fi

  install_framework "$basepath/$target_path" "$name"
}

install_xcframework() {
  local basepath="$1"
  local name="$2"
  local package_type="$3"
  local paths=("$@")

  # Locate the correct slice of the .xcframework for the current architectures
  select_slice "${paths[@]}"
  local target_path="$SELECT_SLICE_RETVAL"
  if [[ -z "$target_path" ]]; then
    echo "warning: [CP] Unable to find matching .xcframework slice in '${paths[@]}' for the current build architectures ($ARCHS)."
    return
  fi
  local source="$basepath/$target_path"

  local destination="#{Pod::Target::BuildSettings::XCFRAMEWORKS_BUILD_DIR_VARIABLE}/${name}"

  if [ ! -d "$destination" ]; then
    mkdir -p "$destination"
  fi

  if [[ "$package_type" == "library" ]]; then
    # Libraries can contain headers, module maps, and a binary, so we'll copy everything in the folder over
    copy_dir "$source/" "$destination"
  elif [[ "$package_type" == "framework" ]]; then
    copy_dir "$source" "$destination"
  fi
  echo "Copied $source to $destination"
}

        SH
        xcframeworks.each do |xcframework|
          slices = xcframework.slices.select { |f| f.platform.symbolic_name == platform.symbolic_name }
          next if slices.empty?
          args = install_xcframework_args(xcframework, slices)
          script << "install_xcframework #{args}\n"
        end

        script << "\n" unless xcframeworks.empty?
        script
      end

      def shell_escape(value)
        "\"#{value}\""
      end

      def install_xcframework_args(xcframework, slices)
        root = xcframework.path
        args = [shell_escape("${PODS_ROOT}/#{root.relative_path_from(sandbox_root)}")]
        args << shell_escape(xcframework.name)
        is_framework = xcframework.build_type.framework?
        args << shell_escape(is_framework ? 'framework' : 'library')
        slices.each do |slice|
          args << if is_framework
                    shell_escape(slice.path.relative_path_from(root))
                  else
                    # We don't want the path to the library binary, we want the dir that contains it
                    shell_escape(slice.path.dirname.relative_path_from(root))
                  end
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
