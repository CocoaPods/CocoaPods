module Pod
  class Lockfile

    # @return [Lockfile] Returns the Lockfile saved in path.
    #
    def self.from_file(path)
      Lockfile.new(path)
    end

    # @return [Lockfile] Creates a new Lockfile ready to be saved in path.
    #
    def self.create(path, podfile, specs)
      Lockfile.new(path, podfile, specs)
    end

    attr_reader :defined_in_file, :podfile, :specs, :dictionary_reppresenation

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
          @dictionary_reppresenation = yaml
        end
      end
    end

    # @return [Array<Dependency>] The dependencies used during the last install.
    #
    def podfile_dependencies
      return [] unless to_dict
      dependencies = to_dict['DEPENDENCIES'] | []
      dependencies.map { |dep|
        match_data = dep.match(/(\S*)( (.*))/)
        Dependency.new(match_data[1], match_data[2].gsub(/[()]/,''))
      }
    end

    # @return [Array<Dependency>] The dependencies that require exactly,
    #   the installed pods.
    #
    def installed_dependencies
      return [] unless to_dict
      pods = to_dict['PODS'] | []
      pods.map { |pod|
        name_and_version = pod.is_a?(String) ? pod : pod.keys[0]
        match_data = name_and_version.match(/(\S*)( (.*))/)
        Dependency.new(match_data[1], match_data[2].gsub(/[()]/,''))
      }
    end

    # @return [void] Writes the Lockfile to path.
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
      to_dict.to_yaml
    end

    # @return [Dictionary] The Dictionary representation of the Lockfile.
    #
    def to_dict
      return @dictionary_reppresenation if @dictionary_reppresenation
      return nil unless @podfile && @specs

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

      dict = {}
      dict["PODS"] = pod_and_deps
      dict["DEPENDENCIES"] = podfile.dependencies.map(&:to_s).sort
      # dict["SPECS_CHECKSUM"] =
      # dict["HEAD_SPECS_INFO"] =
      dict["COCOAPODS"] = VERSION
      dict
    end
  end
end

