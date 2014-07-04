module Pod
  module Generator
    # Generates Info.plist files. A Info.plist file is generated for each
    # Pod and for each Pod target definition, that requires to be built as
    # framework. It states public attributes.
    #
    class InfoPlistFile
      # @return [Target] the target represented by this Info.plist.
      #
      attr_reader :target

      # @param  [Target] target @see target
      #
      def initialize(target)
        @target = target
      end

      # Generates and saves the Info.plist to the given path.
      #
      # @param  [Pathname] path
      #         the path where the prefix header should be stored.
      #
      # @return [void]
      #
      def save_as(path)
        contents = generate
        File.open(path, 'w') do |f|
          f.write(contents)
        end
      end

      # Generates the contents of the Info.plist
      #
      # @return [String]
      #
      def generate
        FILE_CONTENTS
      end

      FILE_CONTENTS = <<-EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${EXECUTABLE_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>org.cocoapods.${PRODUCT_NAME:rfc1034identifier}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleVersion</key>
  <string>${CURRENT_PROJECT_VERSION}</string>
  <key>NSPrincipalClass</key>
  <string></string>
</dict>
</plist>
      EOS
    end
  end
end
