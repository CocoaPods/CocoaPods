module Pod
  module ExternalSources
    def self.from_dependency(dependency)
      name = dependency.root_name
      params = dependency.external_source
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
        path = Pathname.new(@params[:local]).expand_path
        path += "#{name}.podspec"# unless path.to_s.include?("#{name}.podspec")
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
