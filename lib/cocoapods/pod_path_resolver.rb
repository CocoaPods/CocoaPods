module Pod
  class PodPathResolver
    include Config::Mixin

    def initialize(podfile)
      @podfile = podfile
    end

    def relative_path_for_pods
      pods_path = config.project_pods_root
      xcode_proj_path = @podfile.xcodeproj || ''
      source_root = (config.project_root + xcode_proj_path).parent
      pods_path.relative_path_from(source_root)
    end

    def pods_root
      "$(SRCROOT)/#{relative_path_for_pods}"
    end
  end
end
