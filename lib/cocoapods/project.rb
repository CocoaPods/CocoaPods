require 'xcodeproj'

module Pod

  # The Pods project.
  #
  # Model class which provides helpers for working with the Pods project
  # through the installation process.
  #
  class Project < Xcodeproj::Project

    # @param  [Pathname, String] path @see path
    # @param  [Bool] skip_initialization
    #         Wether the project should be initialized from scratch.
    #
    def initialize(path, skip_initialization = false)
      super(path, skip_initialization)
      @support_files_group = new_group('Target Files')
      @refs_by_absolute_path = {}
      @pods = new_group('Pods')
      @development_pods = new_group('Development Pods')
    end

    # @return [PBXGroup] The group for the support files of the aggregate
    #         targets.
    #
    attr_reader :support_files_group

    # @return [PBXGroup] The group for the Pods.
    #
    attr_reader :pods

    # @return [PBXGroup] The group for Development Pods.
    #
    attr_reader :development_pods


    public

    # @!group Groups
    #-------------------------------------------------------------------------#

    # Creates a new group for the sources of the Pod with the given name and
    # configures its path.
    #
    # @param  [String] pod_name
    #         The name of the Pod.
    #
    # @param  [#to_s] path
    #         The path to the root of the Pod.
    #
    # @param  [Bool] development
    #         Wether the group should be added to the Development Pods group.
    #
    # @param  [Bool] absolute
    #         Wether the path of the group should be set as absolute.
    #
    # @return [PBXGroup] The new group.
    #
    def add_pod_group(pod_name, path, development = false, absolute = false)
      raise "[BUG]" if pod_group(pod_name)

      parent_group = development ? development_pods : pods
      source_tree = absolute ? :absolute : :group
      group = parent_group.new_group(pod_name, path, source_tree)
      group
    end

    # @return [Array<PBXGroup>] Returns all the group of the Pods.
    #
    def pod_groups
      pods.children.objects + development_pods.children.objects
    end

    # Returns the group for the Pod with the given name.
    #
    # @param  [String] pod_name
    #         The name of the Pod.
    #
    # @return [PBXGroup] The group.
    #
    def pod_group(pod_name)
      pod_groups.find { |group| group.name == pod_name }
    end

    # @return [Hash] The names of the specification subgroups by key.
    #
    SPEC_SUBGROUPS = {
      :source_files             => 'Source Files',
      :resources                => 'Resources',
      :frameworks_and_libraries => 'Frameworks & Libraries',
      :subspecs                 => 'Subspecs',
    }

    # Returns the group for the specification with the give name creating it if
    # needed.
    #
    # @param [String] spec_name
    #                 The full name of the specification.
    #
    # @param [Symbol] subgroup_key
    #                 The optional key of the subgroup (@see #{SPEC_SUBGROUPS})
    #
    # @return [PBXGroup] The group.
    #
    def group_for_spec(spec_name, subgroup_key = nil)
      spec_group = spec_group(spec_name)
      if subgroup_key
        if subgroup_key == :source_files
          spec_group
        else
          subgroup = SPEC_SUBGROUPS[subgroup_key]
          raise ArgumentError, "Unrecognized subgroup `#{subgroup_key}`" unless subgroup
          spec_group.find_subpath(subgroup, true)
        end
      else
        spec_group
      end
    end

    # Creates a new group for the aggregate target with the given name and
    # path.
    #
    # @param  [String] name
    #         The name of the target.
    #
    # @param  [#to_s] path
    #         The path where the files of the target are stored.
    #
    # @return [PBXGroup] The new group.
    #
    def add_aggregate_group(name, path)
      # TODO TMP
      if existing = support_files_group[name]
        existing
      else
        support_files_group.new_group(name, path)
      end
    end

    # Returns the group for the aggregate target with the given name.
    #
    # @param  [String] pod_name
    #         The name of the Pod.
    #
    # @return [PBXGroup] The group.
    #
    def aggregate_group(name)
      support_files_group[name]
    end

    # @return [Array<PBXGroup>] Returns the list of the aggregate groups.
    #
    def aggregate_groups
      support_files_group.children
    end

    # Creates a new group for the pod target with the given name and aggregate.
    #
    # @param  [String] aggregate_name
    #         The name of the target.
    #
    # @param  [String] path
    #         The name of the Pod.
    #
    # @param  [#to_s] path
    #         The path where the files of the target are stored.
    #
    # @return [PBXGroup] The new group.
    #
    def add_aggregate_pod_group(aggregate_name, pod_name, path)
      group = aggregate_group(aggregate_name).new_group(pod_name, path)
    end

    # Returns the group for the pod target with the given name and aggregate.
    # path.
    #
    # @param  [String] aggregate_name
    #         The name of the target.
    #
    # @param  [String] path
    #         The name of the Pod.
    #
    # @return [PBXGroup] The group.
    #
    def aggregate_pod_group(aggregate_name, pod_name)
      aggregate_group(aggregate_name)[pod_name]
    end


    public

    # @!group File references
    #-------------------------------------------------------------------------#

    # Adds a file reference to given path as a child of the given group.
    #
    # @param  [Array<Pathname,String>] absolute_path
    #         The path of the file.
    #
    # @param  [PBXGroup] group
    #         The group for the new file reference.
    #
    # @return [PBXFileReference] The new file reference.
    #
    def add_file_reference(absolute_path, group)
      unless Pathname.new(absolute_path).absolute?
        raise ArgumentError, "Paths must be absolute #{absolute_path}"
      end

      if ref = reference_for_path(absolute_path)
        ref
      else
        ref = group.new_file(absolute_path)
        @refs_by_absolute_path[absolute_path.to_s] = ref
      end
    end

    # Returns the file reference for the given absolute path.
    #
    # @param  [#to_s] absolute_path
    #         The absolute path of the file whose reference is needed.
    #
    # @return [PBXFileReference] The file reference.
    # @return [Nil] If no file reference could be found.
    #
    def reference_for_path(absolute_path)
      unless Pathname.new(absolute_path).absolute?
        raise ArgumentError, "Paths must be absolute #{absolute_path}"
      end

      refs_by_absolute_path[absolute_path.to_s]
    end

    # Adds a file reference to the Podfile.
    #
    # @param  [#to_s] podfile_path
    #         The path of the Podfile.
    #
    # @return [PBXFileReference] The new file reference.
    #
    def add_podfile(podfile_path)
      podfile_ref = new_file(podfile_path, :project)
      podfile_ref.xc_language_specification_identifier = 'xcode.lang.ruby'
      podfile_ref.last_known_file_type = 'text'
      podfile_ref
    end


    private

    # @!group Private helpers
    #-------------------------------------------------------------------------#

    # @return [Hash{String => PBXFileReference}] The file references grouped
    #         by absolute path.
    #
    attr_reader :refs_by_absolute_path

    # Returns the group for the given specification creating it if needed.
    #
    # @param  [String] spec_name
    #         The full name of the specification.
    #
    # @return [PBXGroup] The group for the spec with the given name.
    #
    def spec_group(spec_name)
      pod_name = Specification.root_name(spec_name)
      group = pod_group(pod_name)
      raise "[Bug] Unable to locate group for Pod named `#{pod_name}`" unless group
      if spec_name != pod_name
        subspecs_names = spec_name.gsub(pod_name + '/', '').split('/')
        subspecs_names.each do |name|
          subspecs_group = group[SPEC_SUBGROUPS[:subspecs]] || group.new_group(SPEC_SUBGROUPS[:subspecs])
          group = subspecs_group[name] || subspecs_group.new_group(name)
        end
      end
      group
    end

    #-------------------------------------------------------------------------#

  end
end
