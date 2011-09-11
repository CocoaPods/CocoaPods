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

    def resolved_dependent_specifications
      @resolved_dependent_specifications ||= Resolver.new(self).resolve
    end

    def install_dependent_specifications!(root, clean)
      resolved_dependent_specifications.each do |spec|
        install_spec = spec
        if part_of_spec_dep = spec.read(:part_of)
          install_spec = resolved_dependent_specifications.find { |s| s.read(:name) == part_of_spec_dep.name }
          puts "-- Installing: #{install_spec} for #{spec}"
        else
          puts "-- Installing: #{install_spec}"
        end
        install_spec.install!(root, clean)
      end
    end

    # User can override this for custom installation
    def install!(pods_root, clean)
      require 'fileutils'
      pods_root.mkpath
      pod_root = pods_root + "#{@name}-#{@version}"
      if pod_root.exist?
        puts "   Skipping, the pod already exists: #{pod_root}"
      else
        pod_root.mkdir
        FileUtils.cp(@defined_in_file, pod_root)
        download_to(pod_root, clean)
      end
    end

    # User can override this for custom downloading
    def download_to(pod_root, clean)
      downloader = Downloader.for_source(@source, pod_root)
      downloader.download
      downloader.clean if clean
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
