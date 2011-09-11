framework 'Foundation'

module Pod
  class XcodeProject
    TEMPLATES_DIR = Pathname.new(File.expand_path('../../../xcode-project-templates', __FILE__))

    # TODO see if we really need different templates for iOS and OS X
    def self.static_library
      new TEMPLATES_DIR + 'cocoa-touch-static-library.pbxproj'
    end

    def initialize(template)
      @template = NSDictionary.dictionaryWithContentsOfFile(template.to_s)
      p @template
    end

    def source_files=(files)
      @source_files = files
      @load_paths = files.map { |file| File.dirname(file) }.uniq
    end
  end
end
