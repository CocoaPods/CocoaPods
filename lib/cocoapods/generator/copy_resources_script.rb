module Pod
  module Generator
    class CopyResourcesScript
      CONTENT = <<EOS
#!/bin/sh

install_resource()
{
  case $1 in
    *\.xib)
      echo "ibtool --errors --warnings --notices --output-format human-readable-text --compile ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename $1 .xib`.nib ${SRCROOT}/Pods/$1 --sdk ${SDKROOT}"
      ibtool --errors --warnings --notices --output-format human-readable-text --compile ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename $1 .xib`.nib ${SRCROOT}/Pods/$1 --sdk ${SDKROOT}
      ;;
    *)
      echo "cp -R ${SRCROOT}/Pods/$1 ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
      cp -R "${SRCROOT}/Pods/$1" "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
      ;;
  esac
}
EOS

      attr_reader :resources

      # A list of files relative to the project pods root.
      def initialize(resources)
        @resources = resources
      end

      def save_as(pathname)
        pathname.open('w') do |script|
          script.puts CONTENT
          @resources.each do |resource|
            script.puts "install_resource '#{resource}'"
          end
        end
        # TODO use File api
        system("chmod +x '#{pathname}'")
      end
    end
  end
end
