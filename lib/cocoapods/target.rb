module Pod

  # Model class which describes a Pods target.
  #
  # The Target class stores and provides the information necessary for
  # working with a target in the Podfile and it's dependent libraries.
  # This class is used to represent both the targets and their libraries.
  #
  class Target

    # @return [String]
    #
    attr_accessor :short_name

    # @return [Target]
    #
    attr_accessor :parent

    def initialize(short_name, parent = nil)
      @short_name = short_name
      @parent = parent
      @children = []
      @pod_targets = []
      @specs = []
      @file_accessors = []
      @user_target_uuids = []
      @user_build_configurations = {}

      if parent
        parent.children << self
      end
    end

    # @return [Array]
    #
    attr_accessor :children

    # @return [Target]
    #
    def root
      if parent
        parent
      else
        self
      end
    end

    # @return [Bool]
    #
    def root?
      parent.nil?
    end

    # @return [String] the name of the library.
    #
    def name
      if root?
        short_name
      else
        "#{parent.name}-#{short_name}"
      end
    end

    # @return [String] the name of the library.
    #
    def product_name
      "lib#{name}.a"
    end

    # @return [String] A string suitable for debugging.
    #
    def inspect
      "<#{self.class} name=#{name}>"
    end

    # @return [String]
    #
    def to_s
      s = "#{name}"
      s << " #{platform}" if platform
      s
    end


    public

    # @!group Support files
    #-------------------------------------------------------------------------#

    # @return [PBXNativeTarget] The Xcode native target generated in the Pods
    #         project.
    #
    attr_accessor :native_target

    # @return [Pathname] The directory where the support files are stored.
    #
    attr_accessor :support_files_root

    # @return [HeadersStore] the build header store.
    #
    attr_accessor :private_headers_store

    # @return [HeadersStore] the public header store.
    #
    attr_accessor :public_headers_store

    # @return [Xcodeproj::Config] The public configuration.
    #
    attr_accessor :xcconfig

    # @return [Pathname] The path of the public configuration.
    #
    attr_accessor :xcconfig_path

    # @return [Pathname] The path of the copy resources script
    #
    attr_accessor :copy_resources_script_path

    # @return [Pathname] The path of the prefix header file.
    #
    attr_accessor :prefix_header_path


    public

    # @!group Aggregate
    #-------------------------------------------------------------------------#

    #
    #
    def aggregate?
      root?
    end

    #----------------------------------------#

    # @return [Platform] the platform for this library.
    #
    def platform
      if root?
        @platform
      else
        root.platform
      end
    end

    # Sets the platform of the target
    #
    def platform=(platform)
      if root?
        @platform = platform
      else
        raise "The platform must be set in the root target"
      end
    end

    #----------------------------------------#

    # @return [Pathname] the path of the user project that this target will
    #         integrate as identified by the analyzer.
    #
    # @note   The project instance is not stored to prevent editing different
    #         instances.
    #
    attr_accessor :user_project_path

    # @return [String] the list of the UUIDs of the user targets that will be
    #         integrated by this target as identified by the analyzer.
    #
    # @note   The target instances are not stored to prevent editing different
    #         instances.
    #
    attr_accessor :user_target_uuids

    # @return [Hash{String=>Symbol}] A hash representing the user build
    #         configurations where each key corresponds to the name of a
    #         configuration and its value to its type (`:debug` or `:release`).
    #
    attr_accessor :user_build_configurations

    # @return [Bool]
    #
    attr_accessor :set_arc_compatibility_flag
    alias :set_arc_compatibility_flag? :set_arc_compatibility_flag

    # @return [Bool]
    #
    attr_accessor :generate_bridge_support
    alias :generate_bridge_support? :generate_bridge_support


    public

    # @!group Specs
    #-------------------------------------------------------------------------#

    attr_accessor :specs

    # @return [Specification] the spec for the target.
    #
    def specs
      (@specs + children.map(&:specs)).flatten
    end

    # @return [Array<Specification::Consumer>] The consumers of the Pod.
    #
    def spec_consumers
      specs.map { |spec| spec.consumer(platform) }
    end

    # @return [Specification] The root specification for the target.
    #
    def root_spec
      specs.first.root
    end

    # @return [String] The name of the Pod that this target refers to.
    #
    def pod_name
      root_spec.name
    end

    # @return [Array<Sandbox::FileAccessor>] the file accessors for the
    #         specifications of this target.
    #
    attr_accessor :file_accessors

    # @return [Array<String>] The names of the Pods on which this target
    #         depends.
    #
    def dependencies
      specs.map do |spec|
        spec.consumer(platform).dependencies.map { |dep| Specification.root_name(dep.name) }
      end.flatten.reject { |dep| dep == pod_name }
    end

    # @return [Array<String>]
    #
    def frameworks
      spec_consumers.map(&:frameworks).flatten.uniq
    end

    # @return [Array<String>]
    #
    def libraries
      spec_consumers.map(&:libraries).flatten.uniq
    end

    # @return [Bool]
    #
    attr_accessor :inhibits_warnings
    alias :inhibits_warnings? :inhibits_warnings


    public

    # @!group Deprecated
    #-------------------------------------------------------------------------#

    # TODO: This has been preserved only for the LibraryRepresentation.
    #
    attr_accessor :target_definition

    #-------------------------------------------------------------------------#

  end
end
