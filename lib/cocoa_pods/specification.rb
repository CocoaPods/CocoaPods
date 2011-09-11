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
      dependency(name, *version_requirements)
    end

    def source_files(*patterns)
      @source_files = patterns
    end

    def source(remote)
      @source = remote
    end

    attr_reader :dependencies
    def dependency(name, *version_requirements)
      @dependencies << Dependency.new(name, *version_requirements)
    end

    # Not attributes

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
