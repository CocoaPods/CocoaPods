module Gem
end
require 'rubygems/dependency'

module Pod
  class Dependency < Gem::Dependency
    attr_accessor :only_part_of_other_pod
    alias_method :only_part_of_other_pod?, :only_part_of_other_pod

    attr_accessor :external_spec_source

    attr_accessor :specification

    def initialize(*name_and_version_requirements, &block)
      if name_and_version_requirements.empty? && block
        @inline_podspec = true
        @specification  = Specification.new(&block)
        super(@specification.name, @specification.version)

      elsif !name_and_version_requirements.empty? && block.nil?
        if name_and_version_requirements.last.is_a?(Hash)
          @external_spec_source = name_and_version_requirements.pop
        end
        super(*name_and_version_requirements)

      else
        raise Informative, "A dependency needs either a name and version requirements, " \
                           "a source hash, or a block which defines a podspec."
      end
      @only_part_of_other_pod = false
    end

    def ==(other)
      super &&
        @only_part_of_other_pod == other.only_part_of_other_pod &&
         (@specification ? @specification == other.specification : @external_spec_source == other.external_spec_source)
    end

    def subspec_dependency?
      @name.include?('/')
    end

    # In case this is a dependency for a subspec, e.g. 'RestKit/Networking',
    # this returns 'RestKit', which is what the Pod::Source needs to know to
    # retrieve the correct Set from disk.
    def top_level_spec_name
      subspec_dependency? ? @name.split('/').first : @name
    end

    # Returns a copy of the dependency, but with the name of the top level
    # spec. This is used by Pod::Specification::Set to merge dependencies on
    # the complete set, irrespective of what spec in the set wil be used.
    def to_top_level_spec_dependency
      dep = dup
      dep.name = top_level_spec_name
      dep
    end

    def to_s
      version = ''
      if source = @external_spec_source
        version << "from `#{source[:git] || source[:podspec]}'"
        version << ", commit `#{source[:commit]}'" if source[:commit]
        version << ", tag `#{source[:tag]}'"       if source[:tag]
      elsif @inline_podspec
        version << "defined in Podfile"
      elsif @version_requirements != Gem::Requirement.default
        version << @version_requirements.to_s
      end
      version.empty? ? @name : "#{@name} (#{version})"
    end

    # In case this dependency was defined with either a repo url, :podspec, or block,
    # this method will return the Specification instance.
    def specification
      @specification ||= begin
        if @external_spec_source
          config   = Config.instance
          pod_root = config.project_pods_root + @name
          spec     = nil
          if @external_spec_source[:podspec]
            config.project_pods_root.mkpath
            spec = config.project_pods_root + "#{@name}.podspec"
            source = @external_spec_source[:podspec]
            # can be http, file, etc
            require 'open-uri'
            puts "  * Fetching podspec for `#{@name}' from: #{source}" unless config.silent?
            open(source) do |io|
              spec.open('w') { |f| f << io.read }
            end
          else
            puts "  * Pre-downloading: `#{@name}'" unless config.silent?
            Downloader.for_dependency(self).download
            spec = pod_root + "#{@name}.podspec"
          end
          Specification.from_file(spec)
        end
      end
    end
    
    def pod_root
      Config.instance.project_pods_root + @name
    end

    # Taken from RubyGems 1.3.7
    unless public_method_defined?(:match?)
      def match?(spec_name, spec_version)
        pattern = name

        if Regexp === pattern
          return false unless pattern =~ spec_name
        else
          return false unless pattern == spec_name
        end

        return true if requirement.to_s == ">= 0"

        requirement.satisfied_by? Gem::Version.new(spec_version)
      end
    end

    # Taken from a newer version of RubyGems
    unless public_method_defined?(:merge)
      def merge other
        unless name == other.name then
          raise ArgumentError,
                "#{self} and #{other} have different names"
        end

        default = Gem::Requirement.default
        self_req  = self.requirement
        other_req = other.requirement

        return self.class.new name, self_req  if other_req == default
        return self.class.new name, other_req if self_req  == default

        self.class.new name, self_req.as_list.concat(other_req.as_list)
      end
    end

  end
end
