require 'cocoa_pods/specification/set'

module Pod
  class Specification
    def self.from_podfile(path)
      if path.exist?
        spec = new
        spec.instance_eval(path.read)
        spec.defined_in_file = path
        spec
      end
    end

    def self.from_podspec(path)
      spec = eval(path.read, nil, path.to_s)
      spec.defined_in_file = path
      spec
    end

    attr_accessor :defined_in_file

    def initialize(&block)
      @dependencies = []
      @xcconfig = {}
      instance_eval(&block) if block_given?
    end

    # Attributes

    def read(name)
      instance_variable_get("@#{name}")
    end

    def name(name)
      @name = name
    end

    def version(version)
      @version = Version.new(version)
    end

    def authors(*names_and_email_addresses)
      list = names_and_email_addresses
      unless list.first.is_a?(Hash)
        authors = list.last.is_a?(Hash) ? list.pop : {}
        list.each { |name| authors[name] = nil }
      end
      @authors = authors || list
    end
    alias_method :author, :authors

    def homepage(url)
      @homepage = url
    end

    def summary(summary)
      @summary = summary
      @description ||= summary
    end

    def description(description)
      @description = description
    end

    def part_of(name, *version_requirements)
      part_of_dependency(name, *version_requirements)
      @part_of.only_part_of_other_pod = true
    end

    def part_of_dependency(name, *version_requirements)
      @part_of = dependency(name, *version_requirements)
    end

    def source_files(*patterns)
      @source_files = patterns.map { |p| Pathname.new(p) }
    end

    def source(remote)
      @source = remote
    end

    attr_reader :dependencies
    def dependency(name, *version_requirements)
      dep = Dependency.new(name, *version_requirements)
      @dependencies << dep
      dep
    end

    def xcconfig(hash)
      @xcconfig = hash
    end

    # Not attributes

    include Config::Mixin

    def ==(other)
      self.class === other &&
        @name && @name == other.read(:name) &&
          @version && @version == other.read(:version)
    end

    def dependency_by_name(name)
      @dependencies.find { |d| d.name == name }
    end

    def part_of_specification_set
      if @part_of
        Set.by_specification_name(@part_of.name)
      end
    end

    # Returns the specification for the pod that this pod's source is a part of.
    def part_of_specification
      (set = part_of_specification_set) && set.specification
    end

    def pod_destroot
      return if from_podfile?
      if part_of_other_pod?
        part_of_specification.pod_destroot
      else
        config.project_pods_root + "#{@name}-#{@version}"
      end
    end

    def part_of_other_pod?
      !@part_of.nil?
    end

    def from_podfile?
      @name.nil? && @version.nil?
    end

    def to_s
      if from_podfile?
        "podfile at `#{@defined_in_file}'"
      else
        "`#{@name}' version `#{@version}'"
      end
    end

    def inspect
      "#<#{self.class.name} for #{to_s}>"
    end

    # Install and download hooks

    # Places the activated specification in the project's pods directory.
    #
    # Override this if you need to perform work before or after activating the
    # pod. Eg:
    #
    #   Pod::Spec.new do
    #     def install!
    #       # pre-install
    #       super
    #       # post-install
    #     end
    #   end
    def install!
      puts "==> Installing: #{self}" unless config.silent?
      config.project_pods_root.mkpath
      require 'fileutils'
      FileUtils.cp(@defined_in_file, config.project_pods_root)

      # In case this spec is part of another pod's source, we need to dowload
      # the other pod's source.
      (part_of_specification || self).download_if_necessary!
    end

    def download_if_necessary!
      if pod_destroot.exist?
        puts "  * Skipping download of #{self}, pod already downloaded" unless config.silent?
      else
        puts "  * Downloading: #{self}" unless config.silent?
        download!
      end
    end

    # Downloads the source of the pod and places it in the project's pods
    # directory.
    #
    # Override this if you need to perform work before or after downloading the
    # pod, or if you need to implement custom dowloading. Eg:
    #
    #   Pod::Spec.new do
    #     def download!
    #       # pre-download
    #       super # or custom downloading
    #       # post-download
    #     end
    #   end
    def download!
      downloader = Downloader.for_source(pod_destroot, @source)
      downloader.download
      downloader.clean if config.clean
    end

  end

  Spec = Specification
end
