module Pod
  module Generator
    class CopyResourcesScript
      # @return [Hash{String, Array{String}] A list of files relative to the
      #         project pods root, keyed by build configuration.
      #
      attr_reader :resources_by_config

      # @return [Platform] The platform of the library for which the copy
      #         resources script is needed.
      #
      attr_reader :platform

      # @param  [Hash{String, Array{String}]
      #         resources_by_config @see resources_by_config
      # @param  [Platform] platform @see platform
      #
      def initialize(resources_by_config, platform)
        @resources_by_config = resources_by_config
        @platform = platform # TODO: Remove this?
      end

      # Saves the resource script to the given pathname.
      #
      # @param  [Pathname] pathname
      #         The path where the copy resources script should be saved.
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

      # @return [String] The contents of the copy resources script.
      #
      def script
        # Define install function
        script = INSTALL_RESOURCES_FUNCTION

        # Call function for each configuration-dependent resource
        resources_by_config.each do |config, resources|
          unless resources.empty?
            script += %(if [[ "$CONFIGURATION" == "#{config}" ]]; then\n)
            resources.each do |resource|
              script += %(  install_resource "#{resource}"\n)
            end
            script += "fi\n"
          end
        end

        script
      end

      INSTALL_RESOURCES_FUNCTION = <<EOS
#!/bin/sh
set -e

mkdir -p "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

install_resource()
{
  case $1 in
    *.framework)
      echo "mkdir -p ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      echo "rsync -av ${PODS_ROOT}/$1 ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      rsync -av "${PODS_ROOT}/$1" "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      ;;
  esac
}
EOS

    end
  end
end
