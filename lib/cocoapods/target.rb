module Pod
  # Model class which describes a Pods target.
  #
  # The Target class stores and provides the information necessary for
  # working with a target in the Podfile and it's dependent libraries.
  # This class is used to represent both the targets and their libraries.
  #
  class Target
    # @return [PBXNativeTarget] the target definition of the Podfile that
    #         generated this target.
    #
    attr_reader :target_definition

    # @return [Sandbox] The sandbox where the Pods should be installed.
    #
    attr_reader :sandbox

    # @return [Boolean] Whether the target needs to be implemented as a framework.
    #         Computed by analyzer.
    #
    attr_accessor :host_requires_framework
    alias_method :host_requires_framework?, :host_requires_framework

    # @return [String] the name of the library.
    #
    def name
      label
    end

    # @return [String] the name of the product.
    #
    def product_name
      if requires_framework?
        framework_name
      else
        static_library_name
      end
    end

    # @return [String] the name of the product excluding the file extension.
    #
    def product_basename
      label
    end

    # @return [String] the name of the framework, depends on #product_basename.
    #
    def framework_name
      "#{product_basename}.framework"
    end

    # @return [String] the name of the library, depends on #product_basename.
    #
    def static_library_name
      "lib#{product_basename}.a"
    end

    # @return [Symbol] either :framework or :static_library, depends on
    #         #requires_framework?.
    #
    def product_type
      requires_framework? ? :framework : :static_library
    end

    # @return [String] the XCConfig namespaced prefix.
    #
    def xcconfig_prefix
      label.upcase.gsub(/[^A-Z]/, '_') + '_'
    end

    # @return [String] A string suitable for debugging.
    #
    def inspect
      "<#{self.class} name=#{name} >"
    end

    #-------------------------------------------------------------------------#

    # @return [Boolean] whether the generated target need to be implemented
    #         as a framework
    #
    # @note This applies either if Swift was used by the host, which was checked
    #       eagerly by the analyzer before, or in the given target or its
    #       dependents, which can only be checked after the specs were been
    #       fetched.
    #
    def requires_framework?
      host_requires_framework? || uses_swift?
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

    # @return [Platform] the platform for this library.
    #
    def platform
      @platform ||= target_definition.platform
    end

    # @return [String] The value for the ARCHS build setting.
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

    # @return [Pathname] the absolute path of the private xcconfig file.
    #
    def xcconfig_private_path
      support_files_dir + "#{label}-Private.xcconfig"
    end

    # @return [Pathname] the absolute path of the header file which contains
    #         the information about the installed pods.
    #
    def target_environment_header_path
      name = target_definition.label
      sandbox.target_support_files_dir(name) + "#{name}-environment.h"
    end

    # @return [Pathname] the absolute path of the prefix header file.
    #
    def prefix_header_path
      support_files_dir + "#{label}-prefix.pch"
    end

    # @return [Pathname] the absolute path of the bridge support file.
    #
    def bridge_support_path
      support_files_dir + "#{label}.bridgesupport"
    end

    # @return [Pathname] the absolute path of the Info.plist file.
    #
    def info_plist_path
      support_files_dir + "Info.plist"
    end

    # @return [Pathname] the path of the dummy source generated by CocoaPods
    #
    def dummy_source_path
      support_files_dir + "#{label}-dummy.m"
    end

    #-------------------------------------------------------------------------#

    protected

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
