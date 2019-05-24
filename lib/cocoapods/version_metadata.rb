module Pod
  module VersionMetadata
    CACHE_VERSION = '002'.freeze

    def self.gem_version
      Pod::VERSION
    end

    def self.project_cache_version
      "#{VersionMetadata.gem_version}.project-cache.#{CACHE_VERSION}"
    end
  end
end
