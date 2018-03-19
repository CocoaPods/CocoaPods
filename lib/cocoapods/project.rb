require 'xcodeproj'
require 'active_support/core_ext/string/inflections'

module Pod
  # The Pods project.
  #
  # Model class which provides helpers for working with the Pods project
  # through the installation process.
  #
  class Project < Xcodeproj::Project
    # Initialize a new instance
    #
    # @param  [Pathname, String] path @see path
    # @param  [Bool] skip_initialization
    #         Whether the project should be initialized from scratch.
    # @param  [Int] object_version
    #         Object version to use for serialization, defaults to Xcode 3.2 compatible.
    #
    def initialize(path, skip_initialization = false,
        object_version = Xcodeproj::Constants::DEFAULT_OBJECT_VERSION)
      super(path, skip_initialization, object_version)
      @support_files_group = new_group('Targets Support Files')
      @refs_by_absolute_path = {}
      @variant_groups_by_path_and_name = {}
      @pods = new_group('Pods')
      @development_pods = new_group('Development Pods')
      self.symroot = LEGACY_BUILD_ROOT
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

    # Generates a list of new UUIDs that created objects can be assigned.
    #
    # @note Overridden to generate UUIDs in a much faster way, since we don't need to check for collisions
    #       (as the Pods project is regenerated each time, and thus all UUIDs will have come from this method)
    #
    # @param [Integer] count
    #        The number of UUIDs to generate
    #
    # @return [Void]
    #
    def generate_available_uuid_list(count = 100)
      start = @generated_uuids.size
      uniques = Array.new(count) { |i| format('%011X0', start + i) }
      @generated_uuids += uniques
      @available_uuids += uniques
    end

    public

    # @!group Legacy Xcode build root
    #-------------------------------------------------------------------------#

    LEGACY_BUILD_ROOT = '${SRCROOT}/../build'

    # @param [String] symroot
    #        The build root that is used when Xcode is configured to not use the
    #        workspace’s build root. Defaults to `${SRCROOT}/../build`.
    #
    # @return [void]
    #
    def symroot=(symroot)
      root_object.build_configuration_list.build_configurations.each do |config|
        config.build_settings['SYMROOT'] = symroot
      end
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
      raise '[BUG]' if pod_group(pod_name)

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
      :resources  => 'Resources',
      :frameworks => 'Frameworks',
      :developer  => 'Pod',
    }

    # Returns the group for the specification with the give name creating it if
    # needed.
    #
    # @param [String] spec_name
    #                 The full name of the specification.
    #
    # @return [PBXGroup] The group.
    #
    def group_for_spec(spec_name, subgroup_key = nil)
      pod_name = Specification.root_name(spec_name)
      group = pod_group(pod_name)
      raise "[Bug] Unable to locate group for Pod named `#{pod_name}`" unless group
      if spec_name != pod_name
        subspecs_names = spec_name.gsub(pod_name + '/', '').split('/')
        subspecs_names.each do |name|
          group = group[name] || group.new_group(name)
        end
      end

      if subgroup_key
        subgroup_name = SPEC_SUBGROUPS[subgroup_key]
        raise ArgumentError, "Unrecognized subgroup key `#{subgroup_key}`" unless subgroup_name
        group = group[subgroup_name] || group.new_group(subgroup_name)
      end

      group
    end

    # Returns the support files group for the Pod with the given name.
    #
    # @param  [String] pod_name
    #         The name of the Pod.
    #
    # @return [PBXGroup] The group.
    #
    def pod_support_files_group(pod_name, dir)
      group = pod_group(pod_name)
      support_files_group = group['Support Files']
      unless support_files_group
        support_files_group = group.new_group('Support Files', dir)
      end
      support_files_group
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
    # @param  [Bool] reflect_file_system_structure
    #         Whether group structure should reflect the file system structure.
    #         If yes, where needed, intermediate groups are created, similar to
    #         how mkdir -p operates.
    #
    # @param  [Pathname] base_path
    #         The base path for newly created groups when reflect_file_system_structure is true.
    #         If nil, the provided group's real_path is used.
    #
    # @return [PBXFileReference] The new file reference.
    #
    def add_file_reference(absolute_path, group, reflect_file_system_structure = false, base_path = nil)
      file_path_name = absolute_path.is_a?(Pathname) ? absolute_path : Pathname(absolute_path)
      if ref = reference_for_path(file_path_name)
        return ref
      end

      group = group_for_path_in_group(file_path_name, group, reflect_file_system_structure, base_path)
      ref = group.new_file(file_path_name.realpath)
      @refs_by_absolute_path[file_path_name.to_s] = ref
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
      absolute_path = absolute_path.is_a?(Pathname) ? absolute_path : Pathname(absolute_path)
      unless absolute_path.absolute?
        raise ArgumentError, "Paths must be absolute #{absolute_path}"
      end

      refs_by_absolute_path[absolute_path.to_s] ||= refs_by_absolute_path[absolute_path.realpath.to_s]
    end

    # Adds a file reference to the Podfile.
    #
    # @param  [#to_s] podfile_path
    #         The path of the Podfile.
    #
    # @return [PBXFileReference] The new file reference.
    #
    def add_podfile(podfile_path)
      new_file(podfile_path, :project).tap do |podfile_ref|
        mark_ruby_file_ref(podfile_ref)
      end
    end

    # Sets the syntax of the provided file reference to be Ruby, in the case that
    # the file does not already have a ".rb" file extension (ex. the Podfile)
    #
    # @param  [PBXFileReference] file_ref
    #         The file reference to change
    #
    def mark_ruby_file_ref(file_ref)
      file_ref.xc_language_specification_identifier = 'xcode.lang.ruby'
      file_ref.explicit_file_type = 'text.script.ruby'
      file_ref.last_known_file_type = 'text'
    end

    # Adds a new build configuration to the project and populates it with
    # default settings according to the provided type.
    #
    # @note   This method extends the original Xcodeproj implementation to
    #         include a preprocessor definition named after the build
    #         setting. This is done to support the TargetEnvironmentHeader
    #         specification of Pods available only on certain build
    #         configurations.
    #
    # @param  [String] name
    #         The name of the build configuration.
    #
    # @param  [Symbol] type
    #         The type of the build configuration used to populate the build
    #         settings, must be :debug or :release.
    #
    # @return [XCBuildConfiguration] The new build configuration.
    #
    def add_build_configuration(name, type)
      build_configuration = super
      settings = build_configuration.build_settings
      definitions = settings['GCC_PREPROCESSOR_DEFINITIONS'] || ['$(inherited)']
      defines = [defininition_for_build_configuration(name)]
      defines << 'DEBUG' if type == :debug
      defines.each do |define|
        value = "#{define}=1"
        unless definitions.include?(value)
          definitions.unshift(value)
        end
      end
      settings['GCC_PREPROCESSOR_DEFINITIONS'] = definitions

      if type == :debug
        settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
      end

      build_configuration
    end

    # @param  [String] name
    #         The name of the build configuration.
    #
    # @return [String] The preprocessor definition to set for the configuration.
    #
    def defininition_for_build_configuration(name)
      "POD_CONFIGURATION_#{name.underscore}".gsub(/[^a-zA-Z0-9_]/, '_').upcase
    end

    private

    # @!group Private helpers
    #-------------------------------------------------------------------------#

    # @return [Hash{String => PBXFileReference}] The file references grouped
    #         by absolute path.
    #
    attr_reader :refs_by_absolute_path

    # @return [Hash{[Pathname, String] => PBXVariantGroup}] The variant groups
    #         grouped by absolute path of parent dir and name.
    #
    attr_reader :variant_groups_by_path_and_name

    # Returns the group for an absolute file path in another group.
    # Creates subgroups to reflect the file system structure if
    # reflect_file_system_structure is set to true.
    # Makes a variant group if the path points to a localized file inside a
    # *.lproj directory. To support Apple Base Internationalization, the same
    # variant group is returned for interface files and strings files with
    # the same name.
    #
    # @param  [Pathname] absolute_pathname
    #         The pathname of the file to get the group for.
    #
    # @param  [PBXGroup] group
    #         The parent group used as the base of the relative path.
    #
    # @param  [Bool] reflect_file_system_structure
    #         Whether group structure should reflect the file system structure.
    #         If yes, where needed, intermediate groups are created, similar to
    #         how mkdir -p operates.
    #
    # @param  [Pathname] base_path
    #         The base path for the newly created group. If nil, the provided group's real_path is used.
    #
    # @return [PBXGroup] The appropriate group for the filepath.
    #         Can be PBXVariantGroup, if the file is localized.
    #
    def group_for_path_in_group(absolute_pathname, group, reflect_file_system_structure, base_path = nil)
      unless absolute_pathname.absolute?
        raise ArgumentError, "Paths must be absolute #{absolute_pathname}"
      end
      unless base_path.nil? || base_path.absolute?
        raise ArgumentError, "Paths must be absolute #{base_path}"
      end

      relative_base = base_path.nil? ? group.real_path : base_path.realdirpath
      relative_pathname = absolute_pathname.relative_path_from(relative_base)
      relative_dir = relative_pathname.dirname

      # Add subgroups for directories, but treat .lproj as a file
      if reflect_file_system_structure
        path = relative_base
        relative_dir.each_filename do |name|
          break if name.to_s.downcase.include? '.lproj'
          next if name == '.'
          # Make sure groups have the correct absolute path set, as intermittent
          # directories may not be included in the group structure
          path += name
          group = group.children.find { |c| c.display_name == name } || group.new_group(name, path)
        end
      end

      # Turn files inside .lproj directories into a variant group
      if relative_dir.basename.to_s.downcase.include? '.lproj'
        group_name = variant_group_name(absolute_pathname)
        lproj_parent_dir = absolute_pathname.dirname.dirname
        group = @variant_groups_by_path_and_name[[lproj_parent_dir, group_name]] ||=
                  group.new_variant_group(group_name, lproj_parent_dir)
      end

      group
    end

    # Returns the name to be used for a the variant group for a file at a given path.
    # The path must be localized (within an *.lproj directory).
    #
    # @param  [Pathname] The localized path to get a variant group name for.
    #
    # @return [String] The variant group name.
    #
    def variant_group_name(path)
      unless path.to_s.downcase.include?('.lproj/')
        raise ArgumentError, 'Only localized resources can be added to variant groups.'
      end

      # When using Base Internationalization for XIBs and Storyboards a strings
      # file is generated with the same name as the XIB/Storyboard in each .lproj
      # directory:
      #   Base.lproj/MyViewController.xib
      #   fr.lproj/MyViewController.strings
      #
      # In this scenario we want the variant group to be the same as the XIB or Storyboard.
      #
      # Base Internationalization: https://developer.apple.com/library/ios/documentation/MacOSX/Conceptual/BPInternational/InternationalizingYourUserInterface/InternationalizingYourUserInterface.html
      if path.extname.downcase == '.strings'
        %w(.xib .storyboard).each do |extension|
          possible_interface_file = path.dirname.dirname + 'Base.lproj' + path.basename.sub_ext(extension)
          return possible_interface_file.basename.to_s if possible_interface_file.exist?
        end
      end

      path.basename.to_s
    end

    #-------------------------------------------------------------------------#
  end
end
