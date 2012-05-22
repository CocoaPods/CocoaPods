module Gem
end
require 'rubygems/dependency'
require 'open-uri'

module Pod
  class Dependency < Gem::Dependency
    attr_accessor :only_part_of_other_pod
    alias_method :only_part_of_other_pod?, :only_part_of_other_pod

    attr_reader :external_source
    attr_accessor :specification

    def initialize(*name_and_version_requirements, &block)
      if name_and_version_requirements.empty? && block
        @inline_podspec = true
        @specification  = Specification.new(&block)
        super(@specification.name, @specification.version)

      elsif !name_and_version_requirements.empty? && block.nil?
        if name_and_version_requirements.last.is_a?(Hash)
          @external_source = ExternalSources.from_params(name_and_version_requirements[0].split('/').first, name_and_version_requirements.pop)
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
         (@specification ? @specification == other.specification : @external_source == other.external_source)
    end

    def subspec_dependency?
      @name.include?('/')
    end
    
    def inline?
      @inline_podspec
    end
    
    def external?
      !@external_source.nil?
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
      if external?
        version << @external_source.description
      elsif inline?
        version << "defined in Podfile"
      elsif @version_requirements != Gem::Requirement.default
        version << @version_requirements.to_s
      end
      version.empty? ? @name : "#{@name} (#{version})"
    end
    
    def specification_from_sandbox(sandbox, platform)
      @external_source.specification_from_sandbox(sandbox, platform)
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

    module ExternalSources
      def self.from_params(name, params)
        if params.key?(:git)
          GitSource.new(name, params)
        elsif params.key?(:podspec)
          PodspecSource.new(name, params)
        else
          raise Informative, "Unknown external source parameters for #{name}: #{params}"
        end
      end
      
      class AbstractExternalSource
        include Config::Mixin

        attr_reader :name, :params
        
        def initialize(name, params)
          @name, @params = name, params
        end
        
        def specification_from_sandbox(sandbox, platform)
          if local_pod = sandbox.installed_pod_named(name, platform)
            local_pod.specification
          else
            copy_external_source_into_sandbox(sandbox)
            local_pod = sandbox.installed_pod_named(name, platform)
            local_pod.clean if config.clean?
            local_pod.specification
          end
        end
        
        def ==(other_source)
          return if other_source.nil?
          name == other_source.name && params == other_source.params
        end
      end
      
      class GitSource < AbstractExternalSource
        def copy_external_source_into_sandbox(sandbox)
          puts "  * Pre-downloading: '#{name}'" unless config.silent?
          Downloader.for_target(sandbox.root + name, @params).tap do |downloader|
            downloader.download
            downloader.clean if config.clean?
          end
        end
        
        def description
          "from `#{@params[:git]}'".tap do |description|
            description << ", commit `#{@params[:commit]}'" if @params[:commit]
            description << ", branch `#{@params[:branch]}'" if @params[:branch]
            description << ", tag `#{@params[:tag]}'" if @params[:tag]
          end
        end
      end

      # can be http, file, etc
      class PodspecSource < AbstractExternalSource
        def copy_external_source_into_sandbox(sandbox)
          output_path = sandbox.root + "Local Podspecs/#{name}.podspec"
          output_path.dirname.mkpath
          puts "  * Fetching podspec for `#{name}' from: #{@params[:podspec]}" unless config.silent?
          open(@params[:podspec]) do |io|
            output_path.open('w') { |f| f << io.read }
          end
        end
        
        def description
          "from `#{@params[:podspec]}'"
        end
      end
    end
  end
end
