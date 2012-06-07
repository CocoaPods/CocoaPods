module Pod
  class Podfile
    class UserProject
      include Config::Mixin

      DEFAULT_BUILD_CONFIGURATIONS = { 'Debug' => :debug, 'Release' => :release }.freeze

      def initialize(path = nil, build_configurations = {})
        self.path = path if path
        @build_configurations = build_configurations.merge(DEFAULT_BUILD_CONFIGURATIONS)
      end

      def path=(path)
        path  = path.to_s
        @path = Pathname.new(File.extname(path) == '.xcodeproj' ? path : "#{path}.xcodeproj")
        @path = config.project_root + @path unless @path.absolute?
        @path
      end

      def path
        if @path
          @path
        else
          xcodeprojs = config.project_root.glob('*.xcodeproj')
          if xcodeprojs.size == 1
            @path = xcodeprojs.first
          end
        end
      end

      def project
        Xcodeproj::Project.new(path) if path && path.exist?
      end

      def build_configurations
        if project
          project.build_configurations.map(&:name).inject({}) do |hash, name|
            hash[name] = :release; hash
          end.merge(@build_configurations)
        else
          @build_configurations
        end
      end
    end

    class TargetDefinition
      include Config::Mixin

      attr_reader :name, :target_dependencies

      attr_accessor :user_project, :link_with, :platform, :parent, :exclusive

      def initialize(name, options = {})
        @name, @target_dependencies = name, []
        @parent, @exclusive = options.values_at(:parent, :exclusive)
      end

      # A target is automatically `exclusive` if the `platform` does not match
      # the parent's `platform`.
      def exclusive
        if @exclusive.nil?
          if @platform.nil?
            false
          else
            @parent.platform != @platform
          end
        else
          @exclusive
        end
      end
      alias_method :exclusive?, :exclusive

      def user_project
        @user_project || @parent.user_project
      end

      def link_with=(targets)
        @link_with = targets.is_a?(Array) ? targets : [targets]
      end

      def platform
        @platform || (@parent.platform if @parent)
      end

      def label
        if name == :default
          "Pods"
        elsif exclusive?
          "Pods-#{name}"
        else
          "#{@parent.label}-#{name}"
        end
      end

      def acknowledgements_path
        config.project_pods_root + "#{label}-Acknowledgements"
      end

      # Returns a path, which is relative to the project_root, relative to the
      # `$(SRCROOT)` of the user's project.
      def relative_to_srcroot(path)
        if user_project.path.nil?
          # TODO this is not in the right place
          raise Informative, "[!] Unable to find an Xcode project to integrate".red if config.integrate_targets
          path
        else
          (config.project_root + path).relative_path_from(user_project.path.dirname)
        end
      end

      def relative_pods_root
        "${SRCROOT}/#{relative_to_srcroot "Pods"}"
      end

      def lib_name
        "lib#{label}.a"
      end

      def xcconfig_name
        "#{label}.xcconfig"
      end

      def xcconfig_relative_path
        relative_to_srcroot("Pods/#{xcconfig_name}").to_s
      end

      def copy_resources_script_name
        "#{label}-resources.sh"
      end

      def copy_resources_script_relative_path
        "${SRCROOT}/#{relative_to_srcroot("Pods/#{copy_resources_script_name}")}"
      end

      def prefix_header_name
        "#{label}-prefix.pch"
      end

      def bridge_support_name
        "#{label}.bridgesupport"
      end

      # Returns *all* dependencies of this target, not only the target specific
      # ones in `target_dependencies`.
      def dependencies
        @target_dependencies + (exclusive? ? [] : @parent.dependencies)
      end

      def empty?
        target_dependencies.empty?
      end
    end

    def self.from_file(path)
      podfile = Podfile.new do
        eval(path.read, nil, path.to_s)
      end
      podfile.defined_in_file = path
      podfile.validate!
      podfile
    end

    include Config::Mixin

    def initialize(&block)
      @target_definition = TargetDefinition.new(:default, :exclusive => true)
      @target_definition.user_project = UserProject.new
      @target_definitions = { :default => @target_definition }
      instance_eval(&block)
    end

    # Specifies the platform for which a static library should be build.
    #
    # This can be either `:osx` for Mac OS X applications, or `:ios` for iOS
    # applications.
    #
    # For iOS applications, you can set the deployment target by passing a :deployment_target
    # option, e.g:
    #
    #   platform :ios, :deployment_target => "4.0"
    #
    # If the deployment target requires it (< 4.3), armv6 will be added to ARCHS.
    #
    def platform(platform, options={})
      @target_definition.platform = Platform.new(platform, options)
    end

    # Specifies the Xcode workspace that should contain all the projects.
    #
    # If no explicit Xcode workspace is specified and only **one** project exists
    # in the same directory as the Podfile, then the name of that project is used
    # as the workspace’s name.
    #
    # @example
    #
    #   workspace 'MyWorkspace'
    #
    def workspace(path = nil)
      if path
        @workspace = config.project_root + (File.extname(path) == '.xcworkspace' ? path : "#{path}.xcworkspace")
      elsif @workspace
        @workspace
      else
        projects = @target_definitions.map { |_, td| td.user_project.path }.uniq
        if projects.size == 1 && (xcodeproj = @target_definitions[:default].user_project.path)
          config.project_root + "#{xcodeproj.basename('.xcodeproj')}.xcworkspace"
        end
      end
    end

    # Specifies the Xcode project that contains the target that the Pods library
    # should be linked with.
    #
    # If no explicit project is specified, it will use the Xcode project of the
    # parent target. If none of the target definitions specify an explicit project
    # and there is only **one** project in the same directory as the Podfile then
    # that project will be used.
    #
    # @example
    #
    #   # Look for target to link with in an Xcode project called ‘MyProject.xcodeproj’.
    #   xcodeproj 'MyProject'
    #
    #   target :test do
    #     # This Pods library links with a target in another project.
    #     xcodeproj 'TestProject'
    #   end
    #
    def xcodeproj(path, build_configurations = {})
      @target_definition.user_project = UserProject.new(path, build_configurations)
    end

    # Specifies the target(s) in the user’s project that this Pods library
    # should be linked in.
    #
    # If no explicit target is specified, then the Pods target will be linked
    # with the first target in your project. So if you only have one target you
    # do not need to specify the target to link with.
    #
    # @example
    #
    #   # Link with a target called ‘MyApp’ (in the user's project).
    #   link_with 'MyApp'
    #
    #   # Link with the targets in the user’s project called ‘MyApp’ and ‘MyOtherApp’.
    #   link_with ['MyApp', 'MyOtherApp']
    #
    def link_with(targets)
      @target_definition.link_with = targets
    end

    # Specifies a dependency of the project.
    #
    # A dependency requirement is defined by the name of the Pod and _optionally_
    # a list of version requirements.
    #
    #
    # When starting out with a project it is likely that you will want to use the
    # latest version of a Pod. If this is the case, simply omit the version
    # requirements.
    #
    #   dependency 'SSZipArchive'
    #
    #
    # Later on in the project you may want to freeze to a specific version of a
    # Pod, in which case you can specify that version number.
    #
    #   dependency 'Objection', '0.9'
    #
    #
    # Besides no version, or a specific one, it is also possible to use operators:
    #
    # * `> 0.1`    Any version higher than 0.1
    # * `>= 0.1`   Version 0.1 and any higher version
    # * `< 0.1`    Any version lower than 0.1
    # * `<= 0.1`   Version 0.1 and any lower version
    # * `~> 0.1.2` Version 0.1.2 and the versions upto 0.2, not including 0.2
    #
    #
    # Finally, a list of version requirements can be specified for even more fine
    # grained control.
    #
    # For more information, regarding versioning policy, see:
    #
    # * http://semver.org
    # * http://docs.rubygems.org/read/chapter/7
    #
    #
    # ## Dependency on a library, outside those available in a spec repo.
    #
    # ### From a podspec in the root of a library repo.
    #
    # Sometimes you may want to use the bleeding edge version of a Pod. Or a
    # specific revision. If this is the case, you can specify that with your
    # dependency declaration.
    #
    #
    # To use the `master` branch of the repo:
    #
    #   dependency 'TTTFormatterKit', :git => 'https://github.com/gowalla/AFNetworking.git'
    #
    #
    # Or specify a commit:
    #
    #   dependency 'TTTFormatterKit', :git => 'https://github.com/gowalla/AFNetworking.git', :commit => '082f8319af'
    #
    #
    # It is important to note, though, that this means that the version will
    # have to satisfy any other dependencies on the Pod by other Pods.
    #
    #
    # The `podspec` file is expected to be in the root of the repo, if this
    # library does not have a `podspec` file in its repo yet, you will have to
    # use one of the approaches outlined in the sections below.
    #
    #
    # ### From a podspec outside a spec repo, for a library without podspec.
    #
    # If a podspec is available from another source outside of the library’s
    # repo. Consider, for instance, a podpsec available via HTTP:
    #
    #   dependency 'JSONKit', :podspec => 'https://raw.github.com/gist/1346394/1d26570f68ca27377a27430c65841a0880395d72/JSONKit.podspec'
    #
    #
    # ### For a library without any available podspec
    #
    # Finally, if no man alive has created a podspec, for the library you want
    # to use, yet, you will have to specify the library yourself.
    #
    #
    # When you omit arguments and pass a block to `dependency`, an instance of
    # Pod::Specification is yielded to the block. This is the same class which
    # is normally used to specify a Pod.
    #
    # ```
    #   dependency do |spec|
    #     spec.name         = 'JSONKit'
    #     spec.version      = '1.4'
    #     spec.source       = { :git => 'https://github.com/johnezang/JSONKit.git', :tag => 'v1.4' }
    #     spec.source_files = 'JSONKit.*'
    #   end
    # ```
    #
    #
    # For more info on the definition of a Pod::Specification see:
    # https://github.com/CocoaPods/CocoaPods/wiki/A-pod-specification
    def dependency(*name_and_version_requirements, &block)
      @target_definition.target_dependencies << Dependency.new(*name_and_version_requirements, &block)
    end

    # Specifies that a BridgeSupport metadata document should be generated from
    # the headers of all installed Pods.
    #
    # This is for scripting languages such as MacRuby, Nu, and JSCocoa, which use
    # it to bridge types, functions, etc better.
    def generate_bridge_support!
      @generate_bridge_support = true
    end

    # Defines a new static library target and scopes dependencies defined from
    # the given block. The target will by default include the dependencies
    # defined outside of the block, unless the `:exclusive => true` option is
    # given.
    #
    # Consider the following Podfile:
    #
    #   dependency 'ASIHTTPRequest'
    #
    #   target :debug do
    #     dependency 'SSZipArchive'
    #   end
    #
    #   target :test, :exclusive => true do
    #     dependency 'JSONKit'
    #   end
    #
    # This Podfile defines three targets. The first one is the `:default` target,
    # which produces the `libPods.a` file. The second and third are the `:debug`
    # and `:test` ones, which produce the `libPods-debug.a` and `libPods-test.a`
    # files.
    #
    # The `:default` target has only one dependency (ASIHTTPRequest), whereas the
    # `:debug` target has two (ASIHTTPRequest, SSZipArchive). The `:test` target,
    # however, is an exclusive target which means it will only have one
    # dependency (JSONKit).
    def target(name, options = {})
      parent = @target_definition
      options[:parent] = parent
      @target_definitions[name] = @target_definition = TargetDefinition.new(name, options)
      yield
    ensure
      @target_definition = parent
    end

    # This hook allows you to make any last changes to the generated Xcode project
    # before it is written to disk, or any other tasks you might want to perform.
    #
    # For instance, say you'd want to customize the `OTHER_LDFLAGS` of all targets:
    #
    #   post_install do |installer|
    #     installer.project.targets.each do |target|
    #       target.build_configurations.each do |config|
    #         config.build_settings['GCC_ENABLE_OBJC_GC'] = 'supported'
    #       end
    #     end
    #   end
    def post_install(&block)
      @post_install_callback = block
    end

    # Specifies that the -fobjc-arc flag should be added to the OTHER_LD_FLAGS.
    #
    # This is used as a workaround for a compiler bug with non-ARC projects.
    # (see https://github.com/CocoaPods/CocoaPods/issues/142)
    #
    # This was originally done automatically but libtool as of Xcode 4.3.2 no
    # longer seems to support the -fobjc-arc flag. Therefore it now has to be
    # enabled explicitly using this method.
    #
    # This may be removed in a future release.
    def set_arc_compatibility_flag!
      @set_arc_compatibility_flag = true
    end

    # Not attributes

    def podfile?
      true
    end

    attr_accessor :defined_in_file
    attr_reader :target_definitions

    def dependencies
      @target_definitions.values.map(&:target_dependencies).flatten.uniq
    end

    def dependency_by_top_level_spec_name(name)
      dependencies.find { |d| d.top_level_spec_name == name }
    end

    def generate_bridge_support?
      @generate_bridge_support
    end

    def set_arc_compatibility_flag?
      @set_arc_compatibility_flag
    end

    def user_build_configurations
      configs_array = @target_definitions.values.map { |td| td.user_project.build_configurations }
      configs_array.inject({}) { |hash, config| hash.merge(config) }
    end

    def post_install!(installer)
      @post_install_callback.call(installer) if @post_install_callback
    end

    def validate!
      #lines = []
      #lines << "* the `platform` attribute should be either `:osx` or `:ios`" unless @platform && [:osx, :ios].include?(@platform.name)
      #lines << "* no dependencies were specified, which is, well, kinda pointless" if dependencies.empty?
      #raise(Informative, (["The Podfile at `#{@defined_in_file}' is invalid:"] + lines).join("\n")) unless lines.empty?
    end
  end
end
