require 'cocoa_pods/specification/set'

module Pod
  class Specification
    def self.from_podfile(path)
      if File.exist?(path)
        spec = new
        spec.instance_eval(File.read(path))
        spec.defined_in_file = path
        spec
      end
    end

    def self.from_podspec(pathname)
      spec = eval(File.read(pathname), nil, pathname.to_s)
      spec.defined_in_file = pathname
      spec
    end

    attr_accessor :defined_in_file

    def initialize(&block)
      @dependencies = []
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
      #@part_of = Dependency.new(name, *version_requirements)
      @part_of = dependency(name, *version_requirements)
      @part_of.part_of_other_pod = true
    end

    def source_files(*patterns)
      @source_files = patterns
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

    # Not attributes

    # This also includes those that are only part of other specs, but are not
    # actually being used themselves.
    def resolved_dependent_specification_sets
      @resolved_dependent_specifications_sets ||= Resolver.new(self).resolve
    end

    def install_dependent_specifications!
      sets = resolved_dependent_specification_sets
      sets.each do |set|
        # In case the set is only part of other pods we don't need to install
        # the pod itself.
        next if set.only_part_of_other_pod?

        spec = set.podspec
        spec.install!

        # In case spec is part of another pod we need to dowload the other
        # pod's source.
        if spec.part_of_other_pod?
          # Find the specification of the pod that spec's source is a part of.
          part_of_name = spec.read(:part_of).name
          spec = sets.find { |set| set.name == part_of_name }.podspec
        end
        spec.download_if_necessary!
      end
    end

    include Config::Mixin

    def pod_destroot
      config.project_pods_root + "#{@name}-#{@version}"
    end

    # Places the activated podspec in the project's pods directory.
    def install!
      puts "==> Installing: #{self}"
      config.project_pods_root.mkpath
      require 'fileutils'
      FileUtils.cp(@defined_in_file, config.project_pods_root)
    end

    def download_if_necessary!
      if pod_destroot.exist?
        puts "  * Skipping download of #{self}, pod already downloaded"
      else
        puts "  * Downloading: #{self}"
        download!
      end
    end

    # Downloads the source of the pod and places it in the project's pods
    # directory.
    #
    # You can override this for custom downloading.
    def download!
      downloader = Downloader.for_source(@source, pod_destroot)
      downloader.download
      downloader.clean if config.clean
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
  end

  Spec = Specification
end
