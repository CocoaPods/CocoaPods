module Pod
  module Xcode
    class CopyResourcesScript
      CONTENT = <<EOS
#!/bin/sh

install_resource()
{
  echo "cp -R ${SRCROOT}/Pods/$1 ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
  cp -R ${SRCROOT}/Pods/$1 ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}
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
