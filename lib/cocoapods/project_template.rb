require 'fileutils'

module Pod
  class ProjectTemplate
    def initialize(platform)
      @platform = platform
    end
    
    # TODO this is a workaround for an issue with MacRuby with compiled files
    # that makes the use of __FILE__ impossible.
    #
    #TEMPLATES_DIR = Pathname.new(File.expand_path('../../../xcode-project-templates', __FILE__))
    # Rest of this is to handle sourcing template projects from standalone 
    # executable, for which even the $LOADED_FEATURES workaround fails.
    possibilities = [
      [
        $LOADED_FEATURES.find { |file| file =~ %r{cocoapods/project_template\.rbo?$} },
        '../../../xcode-project-templates'
      ],
      [$0, '../xcode-project-templates']
    ]
    TEMPLATES_DIR = possibilities.map do |base, relpath|
      Pathname.new(File.expand_path(relpath, base))
    end.find { |path| path && path.exist? }
    
    def path
      @path ||= case @platform
      when :osx
        TEMPLATES_DIR + 'cocoa-static-library'
      when :ios
        TEMPLATES_DIR + 'cocoa-touch-static-library'
      else
        raise "No Xcode project template exists for the platform `#{platform.inspect}'"
      end
    end
    
    def xcodeproj_path
      @xcodeproj_path = File.join(path, 'Pods.xcodeproj')
    end
    
    def copy_to(pods_root)
      FileUtils.cp_r("#{path}/.", pods_root)
    end
  end
end
