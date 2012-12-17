require 'xcodeproj'

module Pod

  # The Pods project.
  #
  # Model class which provides helpers for working with the Pods project
  # through the installation process.
  #
  class Project < Xcodeproj::Project

    # @return [Sandbox] the sandbox that contains the project.
    #
    # attr_reader :sandbox

    # @param  [Sandbox] sandbox @see #sandbox
    #
    def initialize(xcodeproj = nil)
      super
      # @sandbox = sandbox
      @support_files_group = new_group('Targets Support Files')
      @libraries = []
    end

    # @return [String] a string representation suited for debugging.
    #
    def inspect
      "#<#{self.class}> path:#{path}"
    end

    #-------------------------------------------------------------------------#

    # @!group Helpers

    # @return [PBXGroup] the group where the support files for the Pod
    #         libraries should be added.
    #
    attr_reader :support_files_group

    # Returns the `Pods` group, creating it if needed.
    #
    # @return [PBXGroup] the group.
    #
    def pods
      @pods ||= new_group('Pods')
    end

    # Returns the `Local Pods` group, creating it if needed. This group is used
    # to contain locally sourced pods.
    #
    # @return [PBXGroup] the group.
    #
    def local_pods
      @local_pods ||= new_group('Local Pods')
    end

    # Adds a group as child to the `Pods` group namespacing subspecs.
    #
    # @param  [String] spec_name
    #         The full name of the specification.
    #
    # @param  [PBXGroup] root_group
    #         The group where to add the specification. Either `Pods` or `Local
    #         Pods`.
    #
    # @return [PBXGroup] the group for the spec with the given name.
    #
    def add_spec_group(spec_name, root_group)
      current_group = root_group
      group = nil
      spec_name.split('/').each do |spec_name|
        group = current_group[spec_name] || current_group.new_group(spec_name)
        current_group = group
      end
      group
    end

    # Adds a file reference to the podfile.
    #
    # @param  [#to_s] podfile_path
    #         the path of the podfile
    #
    # @return [PBXFileReference] the file reference.
    #
    def add_podfile(podfile_path)
      podfile_path = Pathname.new(podfile_path)
      podfile_ref  = new_file(podfile_path)
      podfile_ref.xc_language_specification_identifier = 'xcode.lang.ruby'
      podfile_ref
    end
  end
end
