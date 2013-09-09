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
      @refs_by_absolute_path = {}
    end

    # @return [Hash] The names of the specification subgroups by key.
    #
    ROOT_GROUPS = {
      :support_files    => 'Targets Support Files',
      :pods             => 'Pods',
      :development_pods => 'Development Pods',
    }

    # @return [PBXGroup] The group for the support files of the aggregate
    #         targets.
    #
    def support_files_group
      create_group_if_needed(ROOT_GROUPS[:support_files])
    end

    # @return [PBXGroup] The group for the Pods.
    #
    def pods
      name = 'Pods'
      create_group_if_needed(ROOT_GROUPS[:pods])
    end

    # @return [PBXGroup] The group for Development Pods.
    #
    def development_pods
      name = 'Development Pods'
      create_group_if_needed(ROOT_GROUPS[:development_pods])
    end

    # Cleans up the project to prepare it for serialization.
    #
    # @return [void]
    #
    def prepare_for_serialization
      pods.remove_from_project if pods.empty?
      development_pods.remove_from_project if development_pods.empty?
      sort
    end


    public

    # @!group Pod Groups
    #-------------------------------------------------------------------------#

    # Creates a new group for the Pod with the given name and configures its
    # path.
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
      support_files_group = group.new_group(SPEC_SUBGROUPS[:support_files])
      support_files_group.source_tree = 'SOURCE_ROOT'
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
      pod_groups.find { |group| group.display_name == pod_name }
    end

    # @return [Hash] The names of the specification subgroups by key.
    #
    SPEC_SUBGROUPS = {
      :source_files             => 'Source Files',
      :resources                => 'Resources',
      :frameworks_and_libraries => 'Frameworks & Libraries',
      :support_files            => 'Support Files',
      :subspecs                 => 'Subspecs',
      :products                 => 'Products',
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
        subgroup = SPEC_SUBGROUPS[subgroup_key]
        raise ArgumentError, "Unrecognized subgroup `#{subgroup_key}`" unless subgroup
        spec_group.find_subpath(subgroup, true)
      else
        spec_group
      end
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
    # @return [void] The new file reference.
    #
    def set_podfile(podfile_path)
      if podfile_path
        if podfile
          podfile_ref = podfile
          podfile_ref.set_path(podfile_path)
        else
          podfile_ref = new_file(podfile_path, :project)
        end
        podfile_ref.name = 'Podfile'
        podfile_ref.xc_language_specification_identifier = 'xcode.lang.ruby'
        podfile_ref.last_known_file_type = 'text'
        podfile_ref
      end
    end

    # @return [PBXFileReference] The file reference of the Podfile.
    #
    def podfile
      main_group['Podfile']
    end


    private

    # @!group Private helpers
    #-------------------------------------------------------------------------#

    # Returns the group with the given name, creating it if needed.
    #
    # @param  [String] name
    #         The name of the group.
    #
    # @param  [String, Nil] parent
    #         The parent group. If nil resolves to the main group.
    #
    # @return [PBXGroup] The group.
    #
    def create_group_if_needed(name, parent = nil)
      parent ||= main_group
      parent[name] || parent.new_group(name)
    end

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
          subspecs_group = create_group_if_needed(SPEC_SUBGROUPS[:subspecs], group)
          group = subspecs_group[name] || subspecs_group.new_group(name)
        end
      end
      group
    end

    #-------------------------------------------------------------------------#

  end
end
