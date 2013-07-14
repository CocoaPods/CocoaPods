module Pod
  module Generator
    class CopyResourcesScript

      # @return [Array<#to_s>] A list of files relative to the project pods
      #         root.
      #
      attr_reader :resources

      # @return [Platform] The platform of the library for which the copy
      #         resources script is needed.
      #
      attr_reader :platform

      # @param  [Array<#to_s>] resources @see resources
      # @param  [Platform] platform @see platform
      #
      def initialize(resources, platform)
        @resources = resources
        @platform = platform
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

      # @return [Hash{Symbol=>Version}] The minimum deployment target which
      #         supports the `--reference-external-strings-file` option for
      #         the `ibtool` command.
      #
      EXTERNAL_STRINGS_FILE_MIMINUM_DEPLOYMENT_TARGET = {
        :ios => Version.new('6.0'),
        :osx => Version.new('10.8')
      }

      # @return [Bool] Whether the external strings file is supported by the
      #         `ibtool` according to the deployment target of the platform.
      #
      def use_external_strings_file?
        minimum_deployment_target = EXTERNAL_STRINGS_FILE_MIMINUM_DEPLOYMENT_TARGET[platform.name]
        platform.deployment_target >= minimum_deployment_target
      end

      # @return [String] The install resources shell function.
      #
      def install_resources_function
          if use_external_strings_file?
            INSTALL_RESOURCES_FUCTION
          else
            INSTALL_RESOURCES_FUCTION.gsub(' --reference-external-strings-file', '')
          end
      end

      # @return [String] The contents of the copy resources script.
      #
      def script
        script = install_resources_function
        resources.each do |resource|
          script += "install_resource '#{resource}'\n"
        end
        script += RSYNC_CALL
        script
      end


      INSTALL_RESOURCES_FUCTION = <<EOS
#!/bin/sh
set -e

RESOURCES_TO_COPY=${PODS_ROOT}/resources-to-copy-${TARGETNAME}.txt
> "$RESOURCES_TO_COPY"

install_resource()
{
  case $1 in
    *\.storyboard)
      echo "ibtool --reference-external-strings-file --errors --warnings --notices --output-format human-readable-text --compile ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \\"$1\\" .storyboard`.storyboardc ${PODS_ROOT}/$1 --sdk ${SDKROOT}"
      ibtool --reference-external-strings-file --errors --warnings --notices --output-format human-readable-text --compile "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \\"$1\\" .storyboard`.storyboardc" "${PODS_ROOT}/$1" --sdk "${SDKROOT}"
      ;;
    *\.xib)
        echo "ibtool --reference-external-strings-file --errors --warnings --notices --output-format human-readable-text --compile ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \\"$1\\" .xib`.nib ${PODS_ROOT}/$1 --sdk ${SDKROOT}"
      ibtool --reference-external-strings-file --errors --warnings --notices --output-format human-readable-text --compile "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \\"$1\\" .xib`.nib" "${PODS_ROOT}/$1" --sdk "${SDKROOT}"
      ;;
    *.framework)
      echo "mkdir -p ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      echo "cp -fpR ${PODS_ROOT}/$1 ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      cp -fpR "${PODS_ROOT}/$1" "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      ;;
    *.xcdatamodel)
      echo xcrun momc \"${PODS_ROOT}/$1\" ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$1" .xcdatamodel`.mom
      xcrun momc \"${PODS_ROOT}/$1\" ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$1" .xcdatamodel`.mom
      ;;
    *.xcdatamodeld)
      echo  xcrun momc \"${PODS_ROOT}/$1\" ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$1" .xcdatamodeld`.momd
      xcrun momc \"${PODS_ROOT}/$1\" ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$1" .xcdatamodeld`.momd
      ;;
    *)
      echo "${PODS_ROOT}/$1"
      echo "${PODS_ROOT}/$1" >> "$RESOURCES_TO_COPY"
      ;;
  esac
}
EOS


      RSYNC_CALL = <<EOS

rsync -avr --no-relative --exclude '*/.svn/*' --files-from="$RESOURCES_TO_COPY" / "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
rm -f "$RESOURCES_TO_COPY"
EOS

    end
  end
end
