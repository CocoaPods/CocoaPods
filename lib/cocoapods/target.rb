module Pod
  # Model class which describes a Pods target.
  #
  # The Target class stores and provides the information necessary for
  # working with a target in the Podfile and its dependent libraries.
  # This class is used to represent both the targets and their libraries.
  #
  class Target
    DEFAULT_VERSION = '1.0.0'.freeze

    # @return [Sandbox] The sandbox where the Pods should be installed.
    #
    attr_reader :sandbox

    # @return [Boolean] Whether the target needs to be implemented as a framework.
    #         Computed by analyzer.
    #
    attr_accessor :host_requires_frameworks
    alias_method :host_requires_frameworks?, :host_requires_frameworks

    # Initialize a new target
    #
    def initialize
      @archs = []
    end

    # @return [String] the name of the library.
    #
    def name
      label
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

    # @return [Boolean] whether the generated target needs to be implemented
    #         as a framework
    #
    def requires_frameworks?
      host_requires_frameworks? || false
    end

    # @return [Boolean] Whether the target should build a static framework.
    #
    def static_framework?
      return if is_a?(Pod::AggregateTarget)
      return if specs.empty?
      specs.all? { |spec| spec.root.static_framework }
    end

    #-------------------------------------------------------------------------#

    # @!group Information storage

    # @return [Hash{String=>Symbol}] A hash representing the user build
    #         configurations where each key corresponds to the name of a
    #         configuration and its value to its type (`:debug` or `:release`).
    #
    attr_accessor :user_build_configurations

    # @return [PBXNativeTarget] the target generated in the Pods project for
    #         this library.
    #
    attr_accessor :native_target

    # @return [Array<String>] The value for the ARCHS build setting.
    #
    attr_accessor :archs

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

    # @return [Pathname] the absolute path of the LLVM module map file that
    #         defines the module structure for the compiler.
    #
    def module_map_path
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
      support_files_dir + 'Info.plist'
    end

    # @return [Pathname] the path of the dummy source generated by CocoaPods
    #
    def dummy_source_path
      support_files_dir + "#{label}-dummy.m"
    end

    # @return [String] The version associated with this target
    #
    def version
      DEFAULT_VERSION
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
  end
end
