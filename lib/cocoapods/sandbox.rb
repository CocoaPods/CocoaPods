require 'fileutils'

module Pod
  # The sandbox provides support for the directory that CocoaPods uses for an
  # installation. In this directory the Pods projects, the support files and
  # the sources of the Pods are stored.
  #
  # CocoaPods assumes to have control of the sandbox.
  #
  # Once completed the sandbox will have the following file structure:
  #
  #     Pods
  #     |
  #     +-- Headers
  #     |   +-- Private
  #     |   |   +-- [Pod Name]
  #     |   +-- Public
  #     |       +-- [Pod Name]
  #     |
  #     +-- Local Podspecs
  #     |   +-- External Sources
  #     |   +-- Normal Sources
  #     |
  #     +-- Target Support Files
  #     |   +-- [Target Name]
  #     |       +-- Pods-acknowledgements.markdown
  #     |       +-- Pods-acknowledgements.plist
  #     |       +-- Pods-dummy.m
  #     |       +-- Pods-prefix.pch
  #     |       +-- Pods.xcconfig
  #     |
  #     +-- [Pod Name]
  #     |
  #     +-- Manifest.lock
  #     |
  #     +-- Pods.xcodeproj
  #
  class Sandbox
    autoload :FileAccessor,  'cocoapods/sandbox/file_accessor'
    autoload :HeadersStore,  'cocoapods/sandbox/headers_store'
    autoload :PathList,      'cocoapods/sandbox/path_list'
    autoload :PodDirCleaner, 'cocoapods/sandbox/pod_dir_cleaner'
    autoload :PodspecFinder, 'cocoapods/sandbox/podspec_finder'

    # @return [Pathname] the root of the sandbox.
    #
    attr_reader :root

    # @return [HeadersStore] the header directory for the user targets.
    #
    attr_reader :public_headers

    # Initialize a new instance
    #
    # @param [String, Pathname] root @see root
    #
    def initialize(root)
      FileUtils.mkdir_p(root)
      @root = Pathname.new(root).realpath
      @public_headers = HeadersStore.new(self, 'Public')
      @predownloaded_pods = []
      @checkout_sources = {}
      @development_pods = {}
      @pods_with_absolute_path = []
    end

    # @return [Lockfile] the manifest which contains the information about the
    #         installed pods.
    #
    attr_accessor :manifest

    def manifest
      @manifest ||= begin
        Lockfile.from_file(manifest_path) if manifest_path.exist?
      end
    end

    # @return [Project] the Pods project.
    #
    attr_accessor :project

    # Removes the files of the Pod with the given name from the sandbox.
    #
    # @return [void]
    #
    def clean_pod(name)
      root_name = Specification.root_name(name)
      unless local?(root_name)
        path = pod_dir(name)
        path.rmtree if path.exist?
      end
      podspe_path = specification_path(name)
      podspe_path.rmtree if podspe_path
    end

    # Prepares the sandbox for a new installation removing any file that will
    # be regenerated and ensuring that the directories exists.
    #
    def prepare
      FileUtils.rm_rf(headers_root)
      FileUtils.rm_rf(target_support_files_root)

      FileUtils.mkdir_p(headers_root)
      FileUtils.mkdir_p(sources_root)
      FileUtils.mkdir_p(specifications_root)
      FileUtils.mkdir_p(target_support_files_root)
    end

    # @return [String] a string representation suitable for debugging.
    #
    def inspect
      "#<#{self.class}> with root #{root}"
    end

    #-------------------------------------------------------------------------#

    public

    # @!group Paths

    # @return [Pathname] the path of the manifest.
    #
    def manifest_path
      root + 'Manifest.lock'
    end

    # @return [Pathname] the path of the Pods project.
    #
    def project_path
      root + 'Pods.xcodeproj'
    end

    # Returns the path for the directory where the support files of
    # a target are stored.
    #
    # @param  [String] name
    #         The name of the target.
    #
    # @return [Pathname] the path of the support files.
    #
    def target_support_files_dir(name)
      target_support_files_root + name
    end

    # Returns the path where the Pod with the given name is stored, taking into
    # account whether the Pod is locally sourced.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [Pathname] the path of the Pod.
    #
    def pod_dir(name)
      root_name = Specification.root_name(name)
      if local?(root_name)
        Pathname.new(development_pods[root_name])
      else
        sources_root + root_name
      end
    end

    # Returns true if the path as originally specified was absolute.
    #
    # @param  [String] name
    #
    # @return [Bool] true if originally absolute
    #
    def local_path_was_absolute?(name)
      @pods_with_absolute_path.include? name
    end

    # @return [Pathname] The directory where headers are stored.
    #
    def headers_root
      root + 'Headers'
    end

    # @return [Pathname] The directory where the downloaded sources of
    #         the Pods are stored.
    #
    def sources_root
      root
    end

    # @return [Pathname] the path for the directory where the
    #         specifications are stored.
    #
    def specifications_root
      root + 'Local Podspecs'
    end

    # @return [Pathname] The directory where the files generated by
    #         CocoaPods to support the umbrella targets are stored.
    #
    def target_support_files_root
      root + 'Target Support Files'
    end

    #-------------------------------------------------------------------------#

    public

    # @!group Specification store

    # Returns the specification for the Pod with the given name.
    #
    # @param  [String] name
    #         the name of the Pod for which the specification is requested.
    #
    # @return [Specification] the specification if the file is found.
    #
    def specification(name)
      if file = specification_path(name)
        original_path = development_pods[name]
        Dir.chdir(original_path || Dir.pwd) { Specification.from_file(file) }
      end
    end

    # Returns the path of the specification for the Pod with the
    # given name, if one is stored.
    #
    # @param  [String] name
    #         the name of the Pod for which the podspec file is requested.
    #
    # @return [Pathname] the path or nil.
    # @return [Nil] if the podspec is not stored.
    #
    def specification_path(name)
      name = Specification.root_name(name)
      path = specifications_root + "#{name}.podspec"
      if path.exist?
        path
      else
        path = specifications_root + "#{name}.podspec.json"
        if path.exist?
          path
        end
      end
    end

    # Stores a specification in the `Local Podspecs` folder.
    #
    # @param  [Sandbox] sandbox
    #         the sandbox where the podspec should be stored.
    #
    # @param  [String, Pathname] podspec
    #         The contents of the specification (String) or the path to a
    #         podspec file (Pathname).
    #
    # @return [void]
    #
    # @todo   Store all the specifications (including those not originating
    #         from external sources) so users can check them.
    #
    def store_podspec(name, podspec, _external_source = false, json = false)
      file_name = json ? "#{name}.podspec.json" : "#{name}.podspec"
      output_path = specifications_root + file_name
      output_path.dirname.mkpath
      if podspec.is_a?(String)
        output_path.open('w') { |f| f.puts(podspec) }
      else
        unless podspec.exist?
          raise Informative, "No podspec found for `#{name}` in #{podspec}"
        end
        FileUtils.copy(podspec, output_path)
      end

      Dir.chdir(podspec.is_a?(Pathname) ? File.dirname(podspec) : Dir.pwd) do
        spec = Specification.from_file(output_path)

        unless spec.name == name
          raise Informative, "The name of the given podspec `#{spec.name}` doesn't match the expected one `#{name}`"
        end
      end
    end

    #-------------------------------------------------------------------------#

    public

    # @!group Pods information

    # Marks a Pod as pre-downloaded
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [void]
    #
    def store_pre_downloaded_pod(name)
      root_name = Specification.root_name(name)
      predownloaded_pods << root_name
    end

    # @return [Array<String>] The names of the pods that have been
    #         pre-downloaded from an external source.
    #
    attr_reader :predownloaded_pods

    # Checks if a Pod has been pre-downloaded by the resolver in order to fetch
    # the podspec.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [Bool] Whether the Pod has been pre-downloaded.
    #
    def predownloaded?(name)
      root_name = Specification.root_name(name)
      predownloaded_pods.include?(root_name)
    end

    #--------------------------------------#

    # Stores the local path of a Pod.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @param  [Hash] source
    #         The hash which contains the options as returned by the
    #         downloader.
    #
    # @return [void]
    #
    def store_checkout_source(name, source)
      root_name = Specification.root_name(name)
      checkout_sources[root_name] = source
    end

    # Removes the checkout source of a Pod.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [void]
    #
    def remove_checkout_source(name)
      root_name = Specification.root_name(name)
      checkout_sources.delete(root_name)
    end

    # @return [Hash{String=>Hash}] The options necessary to recreate the exact
    #         checkout of a given Pod grouped by its name.
    #
    attr_reader :checkout_sources

    #--------------------------------------#

    # Stores the local path of a Pod.
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @param  [#to_s] path
    #         The local path where the Pod is stored.
    #
    # @param  [Bool] was_absolute
    #         True if the specified local path was absolute.
    #
    # @return [void]
    #
    def store_local_path(name, path, was_absolute = false)
      root_name = Specification.root_name(name)
      development_pods[root_name] = path.to_s
      @pods_with_absolute_path << root_name if was_absolute
    end

    # @return [Hash{String=>String}] The path of the Pods with a local source
    #         grouped by their root name.
    #
    # @todo   Rename (e.g. `pods_with_local_path`)
    #
    attr_reader :development_pods

    # Checks if a Pod is locally sourced?
    #
    # @param  [String] name
    #         The name of the Pod.
    #
    # @return [Bool] Whether the Pod is locally sourced.
    #
    def local?(name)
      root_name = Specification.root_name(name)
      !development_pods[root_name].nil?
    end

    #-------------------------------------------------------------------------#
  end
end
