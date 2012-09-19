require 'cocoapods/open_uri'

module Pod
  class Dependency < Gem::Dependency

    attr_reader :head
    alias :head? :head
    attr_accessor :specification, :external_source

    def initialize(*name_and_version_requirements, &block)
      if name_and_version_requirements.empty? && block
        @inline_podspec = true
        @specification  = Specification.new(&block)
        super(@specification.name, @specification.version)

      elsif !name_and_version_requirements.empty? && block.nil?
        version = name_and_version_requirements.last
        if name_and_version_requirements.last.is_a?(Hash)
          @external_source = ExternalSources.from_params(name_and_version_requirements[0].split('/').first, name_and_version_requirements.pop)
        elsif version.is_a?(Symbol) && version == :head || version.is_a?(Version) && version.head?
          name_and_version_requirements.pop
          @head = true
        end

        super(*name_and_version_requirements)

        if head? && !latest_version?
          raise Informative, "A `:head' dependency may not specify version requirements."
        end

      else
        raise Informative, "A dependency needs either a name and version requirements, " \
                           "a source hash, or a block which defines a podspec."
      end
    end

    def latest_version?
      versions = @version_requirements.requirements.map(&:last)
      versions == [Gem::Version.new('0')]
    end

    def ==(other)
      super && (head? == other.head?) && (@specification ? @specification == other.specification : @external_source == other.external_source)
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
        version << 'defined in Podfile'
      elsif head?
        version << 'HEAD'
      elsif @version_requirements != Gem::Requirement.default
        version << @version_requirements.to_s
      end
      result = @name.dup
      result << " (#{version})" unless version.empty?
      result
    end

    def specification_from_sandbox(sandbox, platform)
      @external_source.specification_from_sandbox(sandbox, platform)
    end

    def match_version?(version)
      match?(name, version) && (version.head? == head?)
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
        return unless name && params
        if params.key?(:git)
          GitSource.new(name, params)
        elsif params.key?(:podspec)
          PodspecSource.new(name, params)
        elsif params.key?(:local)
          LocalSource.new(name, params)
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
          specification_from_local(sandbox, platform) || specification_from_external(sandbox, platform)
        end

        def specification_from_local(sandbox, platform)
          if local_pod = sandbox.installed_pod_named(name, platform)
            local_pod.top_specification
          end
        end

        def specification_from_external(sandbox, platform)
          podspec = copy_external_source_into_sandbox(sandbox, platform)
          spec = specification_from_local(sandbox, platform)
          raise Informative, "No podspec found for `#{name}' in #{description}" unless spec
          spec
        end

        # Can store from a pathname or a string
        #
        def store_podspec(sandbox, podspec)
          output_path = sandbox.root + "Local Podspecs/#{name}.podspec"
          output_path.dirname.mkpath
          if podspec.is_a?(String)
            raise Informative, "No podspec found for `#{name}' in #{description}" unless podspec.include?('Spec.new')
            output_path.open('w') { |f| f.puts(podspec) }
          else
            raise Informative, "No podspec found for `#{name}' in #{description}" unless podspec.exist?
            FileUtils.copy(podspec, output_path)
          end
        end

        def ==(other)
          return if other.nil?
          name == other.name && params == other.params
        end
      end

      class GitSource < AbstractExternalSource
        def copy_external_source_into_sandbox(sandbox, platform)
          UI.info("->".green + " Pre-downloading: '#{name}'") do
            target = sandbox.root + name
            target.rmtree if target.exist?
            downloader = Downloader.for_target(sandbox.root + name, @params)
            downloader.download
            store_podspec(sandbox, target + "#{name}.podspec")
            if local_pod = sandbox.installed_pod_named(name, platform)
              local_pod.downloaded = true
            end
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
        def copy_external_source_into_sandbox(sandbox, _)
          UI.info("->".green + " Fetching podspec for `#{name}' from: #{@params[:podspec]}") do
            path = @params[:podspec]
            path = Pathname.new(path).expand_path if path.start_with?("~")
            open(path) { |io| store_podspec(sandbox, io.read) }
          end
        end

        def description
          "from `#{@params[:podspec]}'"
        end
      end

      class LocalSource < AbstractExternalSource
        def pod_spec_path
          path = Pathname.new(@params[:local]).expand_path + "#{name}.podspec"
          raise Informative, "No podspec found for `#{name}' in `#{@params[:local]}'" unless path.exist?
          path
        end

        def copy_external_source_into_sandbox(sandbox, _)
          store_podspec(sandbox, pod_spec_path)
        end

        def specification_from_local(sandbox, platform)
          specification_from_external(sandbox, platform)
        end

        def specification_from_external(sandbox, platform)
          copy_external_source_into_sandbox(sandbox, platform)
          spec = Specification.from_file(pod_spec_path)
          spec.source = @params
          spec
        end

        def description
          "from `#{@params[:local]}'"
        end
      end
    end
  end
end
