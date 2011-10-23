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
    file = $LOADED_FEATURES.find { |file| file =~ %r{cocoapods/project_template\.rbo?$} }
    TEMPLATES_DIR = Pathname.new(File.expand_path('../../../xcode-project-templates', file))
    
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
