module Pod
  class Lockfile

    # @return [Lockfile] Returns the Lockfile saved in path. If the
    #   file could not be loaded or is not compatible with current
    #   version of CocoaPods {nil}
    #
    def self.from_file(path)
      lockfile = Lockfile.new(path)
      lockfile.hash_reppresentation ? lockfile : nil
    end

    # @return [Lockfile] Creates a new Lockfile ready to be saved in path.
    #
    def self.create(path, podfile, specs)
      Lockfile.new(path, podfile, specs)
    end

    attr_reader :defined_in_file, :podfile, :specs, :hash_reppresentation

    # @param [Pathname] the path of the Lockfile.
    #   If no other value is provided the Lockfile is read from this path.
    # @param [Podfile] the Podfile to use for generating the Lockfile.
    # @param [specs] the specs installed.
    #
    def initialize(path, podfile = nil, specs = nil)
      @defined_in_file = path
      if podfile && specs
        @podfile = podfile
        @specs = specs
      else
        yaml = YAML.load(File.open(path))
        if yaml && Version.new(yaml["COCOAPODS"]) >= Version.new("0.10")
          @hash_reppresentation = yaml
        end
      end
    end

    def pods
      return [] unless to_hash
      to_hash['PODS'] || []
    end

    def dependencies
      return [] unless to_hash
      to_hash['DEPENDENCIES'] || []
    end

    def external_sources
      return [] unless to_hash
      to_hash["EXTERNAL SOURCES"] || []
    end

    # @return [Array<Dependency>] The Podfile dependencies used during the last
    #   install.
    #
    def podfile_dependencies
      dependencies.map { |dep| dependency_from_string(dep) }
    end

    # @return [Array<Dependency>] The dependencies that require the installed
    #   pods with their exact version.
    #
    def dependencies_for_pods
      pods.map { |pod| dependency_from_string(pod.is_a?(String) ? pod : pod.keys[0]) }
    end

    # @return [Dependency] The dependency described by the string.
    #
    def dependency_from_string(string)
      match_data = string.match(/(\S*)( (.*))?/)
      name = match_data[1]
      version = match_data[2]
      version = version.gsub(/[()]/,'') if version
      case version
      when nil
        Dependency.new(name)
      when /from `(.*)'/
        # @TODO: find a way to serialize the external specs and support
        #  all the options
        external_source_info = external_sources.find {|hash| hash.keys[0] == name} || {}
        Dependency.new(name, external_source_info[name])
      when /HEAD/
        # @TODO: find a way to serialize from the Downloader the information
        #   necessary to restore a head version.
        Dependency.new(name, :head)
      else
        Dependency.new(name, version)
      end
    end

    # @return [void] Writes the Lockfile to {#path}.
    #
    def write_to_disk
      File.open(defined_in_file, 'w') {|f| f.write(to_yaml) }
    end

    # @return [String] A string useful to represent the Lockfile in a message
    #   presented to the user.
    #
    def to_s
      "Podfile.lock"
    end

    # @return [String] The YAML representation of the Lockfile, used for
    #   serialization.
    #
    def to_yaml
      to_hash.to_yaml.gsub(/^--- ?\n/,"").gsub(/^([A-Z])/,"\n\\1")
    end

    # @return [Dictionary] The Dictionary representation of the Lockfile.
    #
    def to_hash
      return @hash_reppresentation if @hash_reppresentation
      return nil unless @podfile && @specs
      hash = {}

      # Get list of [name, dependencies] pairs.
      pod_and_deps = specs.map do |spec|
        [spec.to_s, spec.dependencies.map(&:to_s).sort]
      end.uniq

      # Merge dependencies of ios and osx version of the same pod.
      tmp = {}
      pod_and_deps.each do |name, deps|
        if tmp[name]
          tmp[name].concat(deps).uniq!
        else
          tmp[name] = deps
        end
      end
      pod_and_deps = tmp.sort_by(&:first).map do |name, deps|
        deps.empty? ? name : {name => deps}
      end
      hash["PODS"] = pod_and_deps

      hash["DEPENDENCIES"] = podfile.dependencies.map{ |d| "#{d}" }.sort

      external_sources = podfile.dependencies.select(&:external?).sort{ |d, other| d.name <=> other.name}.map{ |d| { d.name => d.external_source.params } }
      hash["EXTERNAL SOURCES"] = external_sources unless external_sources.empty?

      # hash["SPECS_CHECKSUM"]
      hash["COCOAPODS"] = VERSION
      hash
    end
  end
end

