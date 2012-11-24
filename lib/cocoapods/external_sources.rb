module Pod

  # Provides support for initializing the correct concrete class of an external
  # source.
  #
  module ExternalSources

    # @return [AbstractExternalSource] an initialized instance of the concrete
    #         external source class associated with the option specified in the
    #         hash.
    #
    def self.from_dependency(dependency)
      name   = dependency.root_name
      params = dependency.external_source

      klass  = if params.key?(:git) then GitSource
      elsif params.key?(:podspec)   then PodspecSource
      elsif params.key?(:local)     then LocalSource
      end

      if klass
        klass.new(name, params)
      else
        msg = "Unknown external source parameters for `#{name}`: `#{params}`"
        raise Informative, msg
      end
    end

    #-------------------------------------------------------------------------#

    # Abstract class that defines the common behaviour of external sources.
    #
    class AbstractExternalSource

      # @return [String] the name of the Pod described by this external source.
      #
      attr_reader :name

      # @return [Hash{Symbol => String}] the hash representation of the
      #         external source.
      #
      attr_reader :params

      # @param [String] name    @see name
      # @param [Hash]   params  @see params
      #
      def initialize(name, params)
        @name, @params = name, params
      end

      # @return [Bool] whether an external source source is equal to another
      #         according to the {#name} and to the {#params}.
      #
      def ==(other)
        return false if other.nil?
        name == other.name && params == other.params
      end

      #--------------------------------------#

      # @!group Specifications

      public

      # @return [Specification] returns the specification, either from the
      #         sandbox or by fetching the remote source, associated with the
      #         external source.
      #
      def specification(sandbox)
        specification_from_local(sandbox) || specification_from_external(sandbox)
      end

      # @return [Specification] returns the specification associated with the
      #         external source if available in the sandbox.
      #
      def specification_from_local(sandbox)
        sandbox.specification(name)
      end

      # @return [Specification] returns the specification associated with the
      #         external source after fetching it from the remote source, even
      #         if is already present in the sandbox.
      #
      # @raise  If not specification could be found.
      #
      def specification_from_external(sandbox)
        copy_external_source_into_sandbox(sandbox)
        spec = specification_from_local(sandbox)
        unless spec
          raise Informative, "No podspec found for `#{name}' in #{description}"
        end
        spec
      end

      #--------------------------------------#

      # @!group Subclasses hooks

      # Fetches the external source from the remote according to the params.
      #
      # @param  [Sandbox] sandbox
      #         the sandbox where the specification should be stored.
      #
      # @return [void]
      #
      def copy_external_source_into_sandbox(sandbox)
        raise "Abstract method"
      end

      # @return [String] a string representation of the source suitable for UI.
      #
      def description
        raise "Abstract method"
      end

      private

      # Stores a specification in the `Local Podspecs` folder.
      #
      # @param  [Sandbox] sandbox
      #         the sandbox where the podspec should be stored.
      #
      # @param  [String, Pathname] podspec
      #         The contents of the specification (String) or the path to a
      #         podspec file (Pathname).
      #
      # TODO    This could be done by the sandbox.
      # TODO    The check for the podspec string is a bit primitive.
      #
      def store_podspec(sandbox, podspec)
        output_path = sandbox.root + "Local Podspecs/#{name}.podspec"
        output_path.dirname.mkpath
        if podspec.is_a?(String)
          unless podspec.include?('Spec.new')
            raise Informative, "No podspec found for `#{name}` in #{description}"
          end
          output_path.open('w') { |f| f.puts(podspec) }
        else
          unless podspec.exist?
            raise Informative, "No podspec found for `#{name}` in #{description}"
          end
          FileUtils.copy(podspec, output_path)
        end
      end

    end

    #-------------------------------------------------------------------------#

    # Provides support for fetching a specification file from a Git remote.
    # Supports all the options of the downloader (is similar to the git key of
    # `source` attribute of a specification).
    #
    # @note The podspec must be in the root of the repository and should have a
    #       name matching the one of the dependency.
    #
    class GitSource < AbstractExternalSource

      # @see AbstractExternalSource#copy_external_source_into_sandbox
      #
      # @note To prevent a double download of the repository the pod is marked
      #       as pre-downloaded indicating to the installer that only clean
      #       operations are needed.
      #
      def copy_external_source_into_sandbox(sandbox)
        UI.info("->".green + " Pre-downloading: '#{name}'") do
          target = sandbox.root + name
          target.rmtree if target.exist?
          downloader = Downloader.for_target(sandbox.root + name, @params)
          downloader.download
          store_podspec(sandbox, target + "#{name}.podspec")
          sandbox.predownloaded_pods << name
        end
      end

      # @see AbstractExternalSource#description
      #
      def description
        "from `#{@params[:git]}'".tap do |description|
          description << ", commit `#{@params[:commit]}`" if @params[:commit]
          description << ", branch `#{@params[:branch]}`" if @params[:branch]
          description << ", tag `#{@params[:tag]}`" if @params[:tag]
        end
      end
    end

    #-------------------------------------------------------------------------#

    # Provides support for fetching a specification file from an URL. Can be
    # http, file, etc.
    #
    class PodspecSource < AbstractExternalSource

      # @see AbstractExternalSource#copy_external_source_into_sandbox
      #
      def copy_external_source_into_sandbox(sandbox)
        UI.info("->".green + " Fetching podspec for `#{name}' from: #{@params[:podspec]}") do
          path = @params[:podspec]
          path = Pathname.new(path).expand_path if path.start_with?("~")
          open(path) { |io| store_podspec(sandbox, io.read) }
        end
      end

      # @see AbstractExternalSource#description
      #
      def description
        "from `#{@params[:podspec]}`"
      end
    end

    #-------------------------------------------------------------------------#

    # Provides support for fetching a specification file from a path local to
    # the machine running the installation.
    #
    # Works with the {LocalPod::LocalSourcedPod} class.
    #
    class LocalSource < AbstractExternalSource

      # @see AbstractExternalSource#copy_external_source_into_sandbox
      #
      def copy_external_source_into_sandbox(sandbox)
        store_podspec(sandbox, pod_spec_path)
      end

      # @see AbstractExternalSource#description
      #
      def description
        "from `#{@params[:local]}`"
      end

      # @see AbstractExternalSource#specification_from_local
      #
      # @note The LocalSource class always fetches podspecs from the external
      #       source to provide always the freshest specification. Otherwise,
      #       once installed, the podspec would be updated only by `pod
      #       update`.
      #
      def specification_from_local(sandbox)
        specification_from_external(sandbox)
      end

      # @see AbstractExternalSource#specification_from_local
      #
      # @note The LocalSource overrides the source of the specification to
      #       point to the local path.
      #
      def specification_from_external(sandbox)
        copy_external_source_into_sandbox(sandbox)
        spec = Specification.from_file(pod_spec_path)
        spec.source = @params
        spec
      end

      #--------------------------------------#

      # @!group Helpers

      private

      # @return [Pathname] the path of the podspec.
      #
      def pod_spec_path
        path = Pathname.new(@params[:local]).expand_path
        path += "#{name}.podspec"# unless path.to_s.include?("#{name}.podspec")
        unless path.exist?
          raise Informative, "No podspec found for `#{name}` in `#{@params[:local]}`"
        end
        path
      end
    end
  end
end
