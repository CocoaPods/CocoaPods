require 'cocoapods/target/build_settings'

module Pod
  # Model class which describes a Pods target.
  #
  # The Target class stores and provides the information necessary for
  # working with a target in the Podfile and its dependent libraries.
  # This class is used to represent both the targets and their libraries.
  #
  class Target
    DEFAULT_VERSION = '1.0.0'.freeze
    DEFAULT_NAME = 'Default'.freeze
    DEFAULT_BUILD_CONFIGURATIONS = { 'Release' => :release, 'Debug' => :debug }.freeze

    # @return [Sandbox] The sandbox where the Pods should be installed.
    #
    attr_reader :sandbox

    # @return [Boolean] Whether the target needs to be implemented as a framework.
    #         Computed by analyzer.
    #
    attr_reader :host_requires_frameworks
    alias_method :host_requires_frameworks?, :host_requires_frameworks

    # @return [Hash{String=>Symbol}] A hash representing the user build
    #         configurations where each key corresponds to the name of a
    #         configuration and its value to its type (`:debug` or `:release`).
    #
    attr_reader :user_build_configurations

    # @return [Array<String>] The value for the ARCHS build setting.
    #
    attr_reader :archs

    # @return [Platform] the platform of this target.
    #
    attr_reader :platform

    # @return [BuildSettings] the build settings for this target.
    #
    attr_reader :build_settings

    # Initialize a new target
    #
    # @param [Sandbox] sandbox @see #sandbox
    # @param [Boolean] host_requires_frameworks @see #host_requires_frameworks
    # @param [Hash{String=>Symbol}] user_build_configurations @see #user_build_configurations
    # @param [Array<String>] archs @see #archs
    # @param [Platform] platform @see #platform
    #
    def initialize(sandbox, host_requires_frameworks, user_build_configurations, archs, platform)
      @sandbox = sandbox
      @host_requires_frameworks = host_requires_frameworks
      @user_build_configurations = user_build_configurations
      @archs = archs
      @platform = platform

      @build_settings = create_build_settings
    end

    # @return [String] the name of the library.
    #
    def name
      label
    end

    alias to_s name

    # @return [String] the label for the target.
    #
    def label
      DEFAULT_NAME
    end

    # @return [String] The version associated with this target
    #
    def version
      DEFAULT_VERSION
    end

    # @return [Boolean] Whether the target uses Swift code
    #
    def uses_swift?
      false
    end

    # @return [Boolean] Whether the target should build a static framework.
    #
    def static_framework?
      false
    end

    # @return [String] the name to use for the source code module constructed
    #         for this target, and which will be used to import the module in
    #         implementation source files.
    #
    def product_module_name
      c99ext_identifier(label)
    end

    # @return [String] the name of the product.
    #
    def product_name
      if requires_frameworks?
        framework_name
      else
        static_library_name
      end
    end

    # @return [String] the name of the product excluding the file extension or
    #         a product type specific prefix, depends on #requires_frameworks?
    #         and #product_module_name or #label.
    #
    def product_basename
      if requires_frameworks?
        product_module_name
      else
        label
      end
    end

    # @return [String] the name of the framework, depends on #label.
    #
    # @note This may not depend on #requires_frameworks? indirectly as it is
    #       used for migration.
    #
    def framework_name
      "#{product_module_name}.framework"
    end

    # @return [String] the name of the library, depends on #label.
    #
    # @note This may not depend on #requires_frameworks? indirectly as it is
    #       used for migration.
    #
    def static_library_name
      "lib#{label}.a"
    end

    # @return [Symbol] either :framework or :static_library, depends on
    #         #requires_frameworks?.
    #
    def product_type
      requires_frameworks? ? :framework : :static_library
    end

    # @return [String] A string suitable for debugging.
    #
    def inspect
      "<#{self.class} name=#{name} >"
    end

    #-------------------------------------------------------------------------#

    # @!group Framework support

    # @return [Boolean] whether the generated target needs to be implemented
    #         as a framework
    #
    def requires_frameworks?
      host_requires_frameworks? || false
    end

    #-------------------------------------------------------------------------#

    # @!group Support files

    # @return [Pathname] the folder where to store the support files of this
    #         library.
    #
    def support_files_dir
      sandbox.target_support_files_dir(name)
    end

    # @param  [String] variant
    #         The variant of the xcconfig. Used to differentiate build
    #         configurations.
    #
    # @return [Pathname] the absolute path of the xcconfig file.
    #
    def xcconfig_path(variant = nil)
      if variant
        support_files_dir + "#{label}.#{variant.gsub(File::SEPARATOR, '-').downcase}.xcconfig"
      else
        support_files_dir + "#{label}.xcconfig"
      end
    end

    # @return [Pathname] the absolute path of the header file which contains
    #         the exported foundation constants with framework version
    #         information and all headers, which should been exported in the
    #         module map.
    #
    def umbrella_header_path
      module_map_path.parent + "#{label}-umbrella.h"
    end

    def umbrella_header_path_to_write
      module_map_path_to_write.parent + "#{label}-umbrella.h"
    end

    # @return [Pathname] the absolute path of the LLVM module map file that
    #         defines the module structure for the compiler.
    #
    def module_map_path
      module_map_path_to_write
    end

    # @!private
    #
    # @return [Pathname] the absolute path of the module map file that
    #         CocoaPods writes. This can be different from `module_map_path`
    #         if the module map gets symlinked.
    #
    def module_map_path_to_write
      basename = "#{label}.modulemap"
      support_files_dir + basename
    end

    # @return [Pathname] the absolute path of the bridge support file.
    #
    def bridge_support_path
      support_files_dir + "#{label}.bridgesupport"
    end

    # @return [Pathname] the absolute path of the Info.plist file.
    #
    def info_plist_path
      support_files_dir + "#{label}-Info.plist"
    end

    # @return [Pathname] the path of the dummy source generated by CocoaPods
    #
    def dummy_source_path
      support_files_dir + "#{label}-dummy.m"
    end

    #-------------------------------------------------------------------------#

    private

    # Transforms the given string into a valid +identifier+ after C99ext
    # standard, so that it can be used in source code where escaping of
    # ambiguous characters is not applicable.
    #
    # @param  [String] name
    #         any name, which may contain leading numbers, spaces or invalid
    #         characters.
    #
    # @return [String]
    #
    def c99ext_identifier(name)
      name.gsub(/^([0-9])/, '_\1').gsub(/[^a-zA-Z0-9_]/, '_')
    end

    def create_build_settings
      BuildSettings.new(self)
    end
  end
end
