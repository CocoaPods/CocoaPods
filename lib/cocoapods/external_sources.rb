module Pod

  # Provides support for initializing the correct concrete class of an external
  # source.
  #
  module ExternalSources

    # @return [AbstractExternalSource] an initialized instance of the concrete
    #         external source class associated with the option specified in the
    #         hash.
    #
    def self.from_dependency(dependency, podfile_path)
      name   = dependency.root_name
      params = dependency.external_source

      klass  = if params.key?(:git) then GitSource
      elsif params.key?(:svn)       then SvnSource
      elsif params.key?(:hg)        then MercurialSource
      elsif params.key?(:podspec)   then PodspecSource
      elsif params.key?(:local)     then LocalSource
      end

      if klass
        klass.new(name, params, podfile_path)
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

      # @return [String] the path where the podfile is defined to resolve
      #         relative paths.
      #
      attr_reader :podfile_path

      # @param [String] name @see name
      # @param [Hash] params @see params
      # @param [String] podfile_path @see podfile_path
      #
      def initialize(name, params, podfile_path)
        @name = name
        @params = params
        @podfile_path = podfile_path
      end

      # @return [Bool] whether an external source source is equal to another
      #         according to the {#name} and to the {#params}.
      #
      def ==(other)
        return false if other.nil?
        name == other.name && params == other.params
      end

      #--------------------------------------#

      public

      # @!group Specifications

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
          raise Informative, "No podspec found for `#{name}` in #{description}"
        end
        spec
      end

      #--------------------------------------#

      public

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

      #--------------------------------------#

      private

      # @! Subclasses helpers


      # Pre-downloads a Pod passing the options to the downloader and informing
      # the sandbox.
      #
      # @param  [Sandbox] sandbox
      #         the sandbox where the Pod should be downloaded.
      #
      # @return [void]
      #
      def pre_download(sandbox)
        UI.info("->".green + " Pre-downloading: `#{name}`") do
          target = sandbox.root + name
          target.rmtree if target.exist?
          downloader = Downloader.for_target(target, params)
          downloader.download
          sandbox.store_podspec(name, target + "#{name}.podspec", true)
          sandbox.store_pre_downloaded_pod(name)
          if downloader.options_specific?
            source = params
          else
            source = downloader.checkout_options
          end
          sandbox.store_checkout_source(name, source)
        end
      end

    end

    #-------------------------------------------------------------------------#

    # Provides support for fetching a specification file from a Git remote.
    #
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
        pre_download(sandbox)
      end

      # @see AbstractExternalSource#description
      #
      def description
        "from `#{params[:git]}`".tap do |description|
          description << ", commit `#{params[:commit]}`" if params[:commit]
          description << ", branch `#{params[:branch]}`" if params[:branch]
          description << ", tag `#{params[:tag]}`" if params[:tag]
        end
      end
    end

    #-------------------------------------------------------------------------#

    # Provides support for fetching a specification file from a SVN source
    # remote.
    #
    # Supports all the options of the downloader (is similar to the git key of
    # `source` attribute of a specification).
    #
    # @note The podspec must be in the root of the repository and should have a
    #       name matching the one of the dependency.
    #
    class SvnSource < AbstractExternalSource

      # @see AbstractExternalSource#copy_external_source_into_sandbox
      #
      # @note To prevent a double download of the repository the pod is marked
      #       as pre-downloaded indicating to the installer that only clean
      #       operations are needed.
      #
      def copy_external_source_into_sandbox(sandbox)
        pre_download(sandbox)
      end

      # @see AbstractExternalSource#description
      #
      def description
        "from `#{params[:svn]}`".tap do |description|
          description << ", folder `#{params[:folder]}`" if params[:folder]
          description << ", tag `#{params[:tag]}`" if params[:tag]
          description << ", revision `#{params[:revision]}`" if params[:revision]
        end
      end
    end

    #-------------------------------------------------------------------------#

    # Provides support for fetching a specification file from a Mercurial
    # source remote.
    #
    # Supports all the options of the downloader (is similar to the git key of
    # `source` attribute of a specification).
    #
    # @note The podspec must be in the root of the repository and should have a
    #       name matching the one of the dependency.
    #
    class MercurialSource < AbstractExternalSource

      # @see AbstractExternalSource#copy_external_source_into_sandbox
      #
      # @note To prevent a double download of the repository the pod is marked
      #       as pre-downloaded indicating to the installer that only clean
      #       operations are needed.
      #
      def copy_external_source_into_sandbox(sandbox)
        pre_download(sandbox)
      end

      # @see AbstractExternalSource#description
      #
      def description
        "from `#{params[:hg]}`".tap do |description|
          description << ", revision `#{params[:revision]}`" if params[:revision]
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
        UI.info("->".green + " Fetching podspec for `#{name}` from: #{params[:podspec]}") do
          path = params[:podspec]
          path = Pathname.new(path).expand_path if path.to_s.start_with?("~")
          require 'open-uri'
          open(path) { |io| sandbox.store_podspec(name, io.read, true) }
        end
      end

      # @see AbstractExternalSource#description
      #
      def description
        "from `#{params[:podspec]}`"
      end
    end

    #-------------------------------------------------------------------------#

    # Provides support for fetching a specification file from a path local to
    # the machine running the installation.
    #
    # Works with the {LocalPod::LocalSourcedPod} class.
    #
    class LocalSource < AbstractExternalSource

      # @see  AbstractExternalSource#copy_external_source_into_sandbox
      #
      def copy_external_source_into_sandbox(sandbox)
        sandbox.store_podspec(name, pod_spec_path, true)
        sandbox.store_local_path(name, params[:local])
      end

      # @see  AbstractExternalSource#description
      #
      def description
        "from `#{params[:local]}`"
      end

      # @see  AbstractExternalSource#specification_from_local
      #
      # @note The LocalSource class always fetches podspecs from the external
      #       source to provide always the freshest specification. Otherwise,
      #       once installed, the podspec would be updated only by `pod
      #       update`.
      #
      def specification_from_local(sandbox)
        specification_from_external(sandbox)
      end

      # @see  AbstractExternalSource#specification_from_local
      #
      # @note The LocalSource overrides the source of the specification to
      #       point to the local path.
      #
      def specification_from_external(sandbox)
        copy_external_source_into_sandbox(sandbox)
        spec = Specification.from_file(pod_spec_path)
        spec.source = params
        spec
      end

      #--------------------------------------#

      private

      # @!group Helpers

      # @return [Pathname] the path of the podspec.
      #
      def pod_spec_path
        declared_path = params[:local].to_s
        path_with_ext = File.extname(declared_path) == '.podspec' ? declared_path : "#{declared_path}/#{name}.podspec"
        path_without_tilde = path_with_ext.gsub('~', ENV['HOME'])
        absolute_path = Pathname(podfile_path).dirname + path_without_tilde

        unless absolute_path.exist?
          raise Informative, "No podspec found for `#{name}` in `#{params[:local]}`"
        end
        absolute_path
      end
    end
  end
end
