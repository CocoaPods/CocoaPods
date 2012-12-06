require 'xcodeproj'

module Pod

  # Provides support for generating the Pods project
  #
  class Project < Xcodeproj::Project

    include Config::Mixin

    # @return [Sandbox] the sandbox that contains the project.
    #
    attr_reader :sandbox

    # @param  [Sandbox] sandbox @see #sandbox
    #
    def initialize(sandbox)
      super(nil)
      @sandbox = sandbox
      @support_files_group = new_group('Targets Support Files')
      @user_build_configurations = []
      @libraries = []
    end

    # @return [Pathname] the path of the Pods project.
    #
    def path
      sandbox.project_path
    end

    # @return [String] a string representation suited for debugging.
    #
    def inspect
      "#<#{self.class}>"
    end

    #--------------------------------------#

    #@!group Working with groups

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
    # TODO: Pass the specification directly and don't expose the pods groups.
    #
    def add_spec_group(name, parent_group)
      current_group = parent_group
      group = nil
      name.split('/').each do |name|
        group = current_group[name] || current_group.new_group(name)
        current_group = group
      end
      group
    end

    #--------------------------------------#

    #@!group Manipulating the project

    # @return [Array<Library>] the libraries generated from the target
    #         definitions of the Podfile.
    #
    attr_reader :libraries

    # Adds a file reference to the podfile.
    #
    # @param  [#to_s] podfile_path
    #         the path of the podfile
    #
    # @return [PBXFileReference]
    #
    def add_podfile(podfile_path)
      podfile_path = Pathname.new(podfile_path)
      podfile_ref  = new_file(podfile_path.relative_path_from(path.dirname))
      podfile_ref.xc_language_specification_identifier = 'xcode.lang.ruby'
      podfile_ref
    end

    # Creates the user build configurations for the Pods project.
    #
    # @note   The configurations at the top level only need to exist, they
    #         don't hold any build settings themselves, that's left to
    #         `add_pod_library`.
    #
    # @return [void]
    #
    # TODO: why is this needed?
    #
    def user_build_configurations=(user_build_configurations)
      @user_build_configurations = user_build_configurations
      user_build_configurations.each do |name, _|
        unless build_configurations.map(&:name).include?(name)
          bc = new(XCBuildConfiguration)
          bc.name = name
          build_configurations << bc
        end
      end
    end

    # Creates a static library target for the given target_definition.
    #
    # @param  [TargetDefinition] target_definition
    #         the target definition of the library.
    #
    # @raise  If the target definition doesn't specifies a platform.
    #
    # @return [Library] the library for the created target.
    #
    def add_pod_library(target_definition)
      name     = target_definition.label
      platform = target_definition.platform

      unless platform
        raise Informative, "Missing platform for #{target_definition}"
      end

      settings = settings_for_platform(platform)
      target   = new_target(:static_library, name, platform.name)
      target.build_settings('Debug').merge!(settings)
      target.build_settings('Release').merge!(settings)

      @user_build_configurations.each do |name, type|
        unless target.build_configurations.map(&:name).include?(name)
          bc = new(XCBuildConfiguration)
          bc.name = name
          target.build_configurations << bc
          # Copy the settings from either the Debug or the Release configuration.
          bc.build_settings = target.build_settings(type.to_s.capitalize).merge(settings)
        end
      end

      lib = Library.new(target_definition, target)
      libraries << lib
      lib
    end

    #--------------------------------------#

    #@!group Helpers

    private

    # Returns the Xcode build settings for a target with the given platform.
    #
    # @param  [Platform] platform
    #         the platform for which the build settings are needed.
    #
    # @return [Hash] the build settings.
    #
    def settings_for_platform(platform)
      settings = {}
      settings['ARCHS'] = "armv6 armv7" if platform.requires_legacy_ios_archs?

      if dt = platform.deployment_target
        if platform == :ios
          settings['IPHONEOS_DEPLOYMENT_TARGET'] = dt.to_s
        else
          # TODO: add MACOSX_DEPLOYMENT_TARGET
        end
      end
      settings
    end

    #-------------------------------------------------------------------------#

    # Describes a library generated for the Pods project.
    #
    class Library

      include Config::Mixin

      # @return [PBXNativeTarget] the target definition of the Podfile that
      #         generated this library.
      #
      attr_reader :target_definition

      # @return [PBXNativeTarget] the target generated in the Pods project for
      #         this library.
      #
      attr_reader :target

      # @param  [TargetDefinition]  target_definition @see target_definition
      # @param  [PBXNativeTarget]   target            @see target
      #
      def initialize(target_definition, target)
        @target_definition = target_definition
        @target  = target
      end

      def label
        target_definition.label
      end

      #-----------------------------------------------------------------------#

      # @!group User project

      # @return [Xcodeproj::Project]
      #   the project that will be integrated.
      #
      def user_project
        @user_project ||= Xcodeproj::Project.new(user_project_path)
      end

      # Returns the path of the user project that the {TargetDefinition}
      # should integrate.
      #
      # @raise If the project is implicit and there are multiple projects.
      #
      # @raise If the path doesn't exits.
      #
      # @return [Pathname] the path of the user project.
      #
      def user_project_path
        unless @user_project_path
          if target_definition.user_project_path
            @user_project_path = Pathname.new(config.project_root + target_definition.user_project_path)
            unless @user_project_path.exist?
              raise Informative, "Unable to find the Xcode project `#{@user_project_path}` for the target `#{label}`."
            end
          else
            xcodeprojs = Pathname.glob(config.project_root + '*.xcodeproj')
            if xcodeprojs.size == 1
              @user_project_path = xcodeprojs.first
            else
              raise Informative, "Could not automatically select an Xcode project. " \
                "Specify one in your Podfile like so:\n\n" \
                "    xcodeproj 'path/to/Project.xcodeproj'\n"
            end
          end
        end
        @user_project_path
      end

      # Returns a list of the targets from the project of {TargetDefinition}
      # that needs to be integrated.
      #
      # @note   The method first looks if there is a target specified with
      #         the `link_with` option of the {TargetDefinition}. Otherwise
      #         it looks for the target that has the same name of the target
      #         definition.  Finally if no target was found the first
      #         encountered target is returned (it is assumed to be the one
      #         to integrate in simple projects).
      #
      # @note   This will only return targets that do **not** already have
      #         the Pods library in their frameworks build phase.
      #
      # @return [Array<PBXNativeTarget>] the list of targets that the Pods
      #         lib should be linked with.
      #
      def user_targets
        unless @targets
          if link_with = target_definition.link_with
            @targets = user_project.targets.select { |t| link_with.include? t.name }
            raise Informative, "Unable to find a target named `#{link_with.to_sentence}` to link with target definition `#{target_definition.name}`" if @targets.empty?
          elsif target_definition.name != :default
            target = user_project.targets.find { |t| t.name == target_definition.name.to_s }
            @targets = [ target ].compact
            raise Informative, "Unable to find a target named `#{target_definition.name.to_s}`" if @targets.empty?
          else
            @targets = [ user_project.targets.first ].compact
            raise Informative, "Unable to find a target" if @targets.empty?
          end
        end
        @targets
      end

      #-----------------------------------------------------------------------#

      # @!group TargetInstaller & UserProjectIntegrator helpers

      # @return [String] the name of the library.
      #
      def name
        "lib#{target_definition.label}.a"
      end

      # @return [Project] the Pods project.
      #
      def project
        target.project
      end

      # Computes the relative path of a sandboxed file from the `$(SRCROOT)` of
      # the user's project.
      #
      # @param  [Pathname] path
      #
      # @return [String] the computed path.
      #
      def relative_to_srcroot(path = nil)
        base_path = path ? config.project_pods_root + path : config.project_pods_root
        (base_path).relative_path_from(user_project_path.dirname).to_s
      end

      def relative_pods_root
        "${SRCROOT}/#{relative_to_srcroot}"
      end

      # @return [Pathname] the folder where to store the support files of this
      #         library.
      #
      # @todo each library should have a group for its support files
      #
      def support_files_root
        project.sandbox.root
      end

      #---------------------------------------#

      # @return [Xcodeproj::Config] the configuration file of the library
      #
      # @note   The configuration is generated by the {TargetInstaller} and
      #         used by {UserProjectIntegrator} to check for any overridden
      #         values.
      #
      attr_accessor :xcconfig

      # @return [String] the name of the xcconfig file relative to this target.
      #
      def xcconfig_name
        "#{label}.xcconfig"
      end

      # @return [Pathname] the absolute path of the xcconfig file.
      #
      def xcconfig_path
        support_files_root + xcconfig_name
      end

      # @return [String] the path of the xcconfig file relative to the root of
      #         the user project.
      #
      def xcconfig_relative_path
        relative_to_srcroot("#{xcconfig_name}").to_s
      end

      #---------------------------------------#

      # @return [String] the name of the copy resources script relative to this
      # target.
      #
      def copy_resources_script_name
        "#{label}-resources.sh"
      end

      # @return [Pathname] the absolute path of the copy resources script.
      #
      def copy_resources_script_path
        support_files_root + copy_resources_script_name
      end

      # @return [String] the path of the copy resources script relative to the
      #         root of the user project.
      #
      def copy_resources_script_relative_path
        "${SRCROOT}/#{relative_to_srcroot("#{copy_resources_script_name}")}"
      end

      #---------------------------------------#

      # @return [String] the name of the prefix header file relative to this
      #         target.
      #
      def prefix_header_name
        "#{label}-prefix.pch"
      end

      # @return [Pathname] the absolute path of the prefix header file.
      #
      def prefix_header_path
        support_files_root + prefix_header_name
      end

      #---------------------------------------#

      # @return [String] the name of the bridge support file relative to this
      #         target.
      #
      def bridge_support_name
        "#{label}.bridgesupport"
      end

      # @return [Pathname] the absolute path of the bridge support file.
      #
      def bridge_support_path
        support_files_root + bridge_support_name
      end

      # @todo
      #
      def acknowledgements_path
        support_files_root + "#{label}-Acknowledgements"
      end

    end
  end
end
