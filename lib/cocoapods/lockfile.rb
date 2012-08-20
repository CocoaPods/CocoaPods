module Pod
  class Lockfile

    # @return [Lockfile] Returns the Lockfile saved in path.
    #   Returns {nil} If the file can't be loaded.
    #
    def self.from_file(path)
      return nil unless path.exist?
      hash = YAML.load(File.open(path))
      lockfile = Lockfile.new(hash)
      lockfile.defined_in_file = path
      lockfile
    end

    # @return [Lockfile] Generates a lockfile from a {Podfile} and the
    #   list of {Specifications} that were installed.
    #
    def self.generate(podfile, specs)
      Lockfile.new(generate_hash_from_podfile(podfile, specs))
    end

    # @return [String] The file where this Lockfile is defined.
    #
    attr_accessor :defined_in_file

    # @return [String] The hash used to initialize the Lockfile.
    #
    attr_reader :to_hash

    # @param [Hash] hash A Hash representation of a Lockfile.
    #
    def initialize(hash)
      @to_hash = hash
    end

    # @return [Array<String, Hash{String => Array[String]}>] The pods installed
    #   and their dependencies.
    #
    def pods
      @pods ||= to_hash['PODS'] || []
    end

    # @return [Array<Dependency>] The Podfile dependencies used during the last
    #   install.
    #
    def dependencies
      @dependencies ||= to_hash['DEPENDENCIES'].map { |dep| dependency_from_string(dep) } || []
    end

    # @return [Hash{String => Hash}] A hash where the name of the pods are
    #   the keys and the values are the parameters of an {AbstractExternalSource}
    #   of the dependency that required the pod.
    #
    def external_sources
      @external_sources ||= to_hash["EXTERNAL SOURCES"] || {}
    end

    # @return [Array<String>] The names of the installed Pods.
    #
    def pods_names
      @pods_names ||= pods.map do |pod|
        pod = pod.keys.first unless pod.is_a?(String)
        name_and_version_for_pod(pod)[0]
      end
    end

    # @return [Hash{String => Version}] A Hash containing the name
    #   of the installed Pods as the keys and their corresponding {Version}
    #   as the values.
    #
    def pods_versions
      unless @pods_versions
        @pods_versions = {}
        pods.each do |pod|
          pod = pod.keys.first unless pod.is_a?(String)
          name, version = name_and_version_for_pod(pod)
          @pods_versions[name] = version
        end
      end
      @pods_versions
    end

    # @return [Dependency] A dependency that describes the exact installed version
    #   of a Pod.
    #
    def dependency_for_installed_pod_named(name)
      version = pods_versions[name]
      raise Informative, "Attempt to lock a Pod without an known version." unless version
      dependency = Dependency.new(name, version)
      if external_source = external_sources[name]
        dependency.external_source = Dependency::ExternalSources.from_params(dependency.name, external_source)
      end
      dependency
    end

    # @param [String] The string that describes a {Specification} generated
    #   from {Specification#to_s}.
    #
    #   @example Strings examples
    #       "libPusher"
    #       "libPusher (1.0)"
    #       "libPusher (HEAD from 1.0)"
    #       "RestKit/JSON"
    #
    # @return [String, Version] The name and the version of a
    # pod.
    #
    def name_and_version_for_pod(string)
        match_data = string.match(/(\S*) \((.*)\)/)
        name = match_data[1]
        vers = Version.from_s(match_data[2])
        return [name, vers]
    end

    # @param [String] The string that describes a {Dependency} generated
    #   from {Dependency#to_s}.
    #
    #   @example Strings examples
    #       "libPusher"
    #       "libPusher (= 1.0)"
    #       "libPusher (~> 1.0.1)"
    #       "libPusher (> 1.0, < 2.0)"
    #       "libPusher (HEAD)"
    #       "libPusher (from `www.example.com')"
    #       "libPusher (defined in Podfile)"
    #       "RestKit/JSON"
    #
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
      when /defined in Podfile/
        # @TODO: store the whole spec?, the version?
        Dependency.new(name)
      when /from `(.*)'/
        external_source_info = external_sources[name]
        Dependency.new(name, external_source_info)
      when /HEAD/
        # @TODO: find a way to serialize from the Downloader the information
        #   necessary to restore a head version.
        Dependency.new(name, :head)
      else
        Dependency.new(name, version)
      end
    end

    # Analyzes the {Lockfile} and detects any changes applied to the {Podfile}
    # since the last installation.
    #
    # For each Pod, it detects one state among the following:
    #
    # - added: Pods that weren't present in the Podfile.
    # - changed: Pods that were present in the Podfile but changed:
    #   - Pods whose version is not compatible anymore with Podfile,
    #   - Pods that changed their head or external options.
    # - removed: Pods that were removed form the Podfile.
    # - unchanged: Pods that are still compatible with Podfile.
    #
    # @TODO: detect changes for inline dependencies?
    #
    # @return [Hash{Symbol=>Array[Strings]}] A hash where pods are grouped
    # by the state in which they are.
    #
    def detect_changes_with_podfile(podfile)
      previous_podfile_deps = dependencies.map(&:name)
      user_installed_pods   = pods_names.reject { |name| !previous_podfile_deps.include?(name) }
      deps_to_install       = podfile.dependencies.dup

      result = {}
      result[:added]      = []
      result[:changed]    = []
      result[:removed]    = []
      result[:unchanged]  = []

      user_installed_pods.each do |pod_name|
        dependency = deps_to_install.find { |d| d.name == pod_name }
        deps_to_install.delete(dependency)
        version = pods_versions[pod_name]
        external_source = Dependency::ExternalSources.from_params(pod_name, external_sources[pod_name])

        if dependency.nil?
          result[:removed] << pod_name
        elsif !dependency.match_version?(version) || dependency.external_source != external_source
          result[:changed] << pod_name
        else
          result[:unchanged] << pod_name
        end
      end

      deps_to_install.each do |dependency|
        result[:added] << dependency.name
      end
      result
    end

    # @return [void] Writes the Lockfile to {#path}.
    #
    def write_to_disk(path)
      File.open(path, 'w') {|f| f.write(to_yaml) }
      defined_in_file = path
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

    # @return [Hash] The Hash representation of the Lockfile generated from
    #   a given Podfile and the list of resolved Specifications.
    #
    def self.generate_hash_from_podfile(podfile, specs)
      hash = {}

      # Get list of [name, dependencies] pairs.
      pod_and_deps = specs.map do |spec|
        [spec.to_s, spec.dependencies.map(&:to_s).sort]
      end.uniq

      # Merge dependencies of iOS and OS X version of the same pod.
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

      hash["DEPENDENCIES"] = podfile.dependencies.map{ |d| d.to_s }.sort

      external_sources = {}
      deps = podfile.dependencies.select(&:external?).sort{ |d, other| d.name <=> other.name}
      deps.each{ |d| external_sources[d.name] = d.external_source.params }
      hash["EXTERNAL SOURCES"] = external_sources unless external_sources.empty?

      checksums = {}
      specs.select {|spec| !spec.defined_in_file.nil? }.each do |spec|
        checksums[spec.name] = Digest::SHA1.hexdigest(File.read(spec.defined_in_file)).encode('UTF-8')
      end
      hash["SPECS CHECKSUM"] = checksums unless checksums.empty?
      hash["COCOAPODS"] = VERSION
      hash
    end
  end
end

