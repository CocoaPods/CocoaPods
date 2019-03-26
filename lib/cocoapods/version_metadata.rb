module Pod
  module VersionMetadata
    def self.gem_version
      Pod::VERSION
    end

    def self.project_cache_version
      VersionMetadata.gem_version
    end
  end
end
