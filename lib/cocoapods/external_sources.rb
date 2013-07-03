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

      klass  =  if params.key?(:git)          then GitSource
                elsif params.key?(:svn)       then SvnSource
                elsif params.key?(:hg)        then MercurialSource
                elsif params.key?(:podspec)   then PodspecSource
                elsif params.key?(:path)      then PathSource
                end

      if params.key?(:local)
        klass = PathSource
        UI.warn "The `:local` option of the Podfile has been renamed to `:path` and is deprecated." \
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

      # @!group Fetching

      # Fetches the external source from the remote according to the params.
      #
      # @param  [Sandbox] sandbox
      #         the sandbox where the specification should be stored.
      #
      # @return [void]
      #
      def fetch(sandbox)
        raise "Abstract method"
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
      def fetch(sandbox)
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
      #         The sandbox where the Pod should be downloaded.
      #
      # @note   To prevent a double download of the repository the pod is
      #         marked as pre-downloaded indicating to the installer that only
      #         clean operations are needed.
      #
      # @todo  The downloader configuration is the same of the
      #        #{PodSourceInstaller} and it needs to be kept in sync.
      #
      # @return [void]
      #
      def pre_download(sandbox)
        UI.titled_section("Pre-downloading: `#{name}` #{description}", { :verbose_prefix => "-> " }) do
          target = sandbox.root + name
          target.rmtree if target.exist?
          downloader = Config.instance.downloader(target, params)
          downloader.download
          store_podspec(sandbox, target + "#{name}.podspec")
          sandbox.store_pre_downloaded_pod(name)
          if downloader.options_specific?
            source = params
          else
            source = downloader.checkout_options
          end
          sandbox.store_checkout_source(name, source)
        end
      end

      # Stores the podspec in the sandbox and marks it as from an external
      # source.
      #
      # @param  [Sandbox] sandbox
      #         The sandbox where the specification should be stored.
      #
      # @param  [Pathname, String] spec
      #         The path of the specification or its contents.
      #
      # @note   All the concrete implementations of #{fetch} should invoke this
      #         method.
      #
      # @note   The sandbox ensures that the podspec exists and that the names
      #         match.
      #
      # @return [void]
      #
      def store_podspec(sandbox, spec)
        sandbox.store_podspec(name, spec, true)
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

      # @see AbstractExternalSource#fetch
      #
      def fetch(sandbox)
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

      # @see AbstractExternalSource#fetch
      #
      def fetch(sandbox)
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

      # @see AbstractExternalSource#fetch
      #
      def fetch(sandbox)
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

      # @see AbstractExternalSource#fetch
      #
      def fetch(sandbox)
        UI.titled_section("Fetching podspec for `#{name}` #{description}", { :verbose_prefix => "-> " }) do

          require 'open-uri'
          open(podspec_uri) { |io| store_podspec(sandbox, io.read) }
        end
      end

      # @see AbstractExternalSource#description
      #
      def description
        "from `#{params[:podspec]}`"
      end

      #--------------------------------------#

      private

      # @!group Helpers

      # @return [String] The uri of the podspec appending the name of the file
      #         and expanding it if necessary.
      #
      # @note   If the declared path is expanded only if the represents a path
      #         relative to the file system.
      #
      def podspec_uri
        declared_path = params[:podspec].to_s
        if declared_path.match(%r{^.+://})
          declared_path
        else
          path_with_ext = File.extname(declared_path) == '.podspec' ? declared_path : "#{declared_path}/#{name}.podspec"
          podfile_dir   = File.dirname(podfile_path || '')
          absolute_path = File.expand_path(path_with_ext, podfile_dir)
          absolute_path
        end
      end
    end

    #-------------------------------------------------------------------------#

    # Provides support for fetching a specification file from a path local to
    # the machine running the installation.
    #
    # Works with the {LocalPod::LocalSourcedPod} class.
    #
    class PathSource < AbstractExternalSource

      # @see  AbstractExternalSource#fetch
      #
      def fetch(sandbox)
        UI.titled_section("Fetching podspec for `#{name}` #{description}", { :verbose_prefix => "-> " }) do
          podspec = podspec_path
          store_podspec(sandbox, podspec)
          sandbox.store_local_path(name, podspec.dirname)
        end
      end

      # @see  AbstractExternalSource#description
      #
      def description
        "from `#{params[:path] || params[:local]}`"
      end

      #--------------------------------------#

      private

      # @!group Helpers

      # @return [Pathname] the path of the podspec.
      #
      def podspec_path
        declared_path = (params[:path] || params[:local]).to_s
        path_with_ext = File.extname(declared_path) == '.podspec' ? declared_path : "#{declared_path}/#{name}.podspec"
        podfile_dir   = File.dirname(podfile_path || '')
        absolute_path = File.expand_path(path_with_ext, podfile_dir)
        pathname      = Pathname.new(absolute_path)

        unless pathname.exist?
          raise Informative, "No podspec found for `#{name}` in `#{params[:local]}`"
        end
        pathname
      end
    end

    #-------------------------------------------------------------------------#

  end
end
