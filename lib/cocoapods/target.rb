module Pod


  # Model class which describes a Pods target.
  #
  # The Target class stores and provides the information necessary for
  # working with a target in the Podfile and it's dependent libraries.
  # This class is used to represent both the targets and their libraries.
  #
  class Target

    autoload :PathsProvider, 'cocoapods/target/paths_provider'

    # @return [PBXNativeTarget] the target definition of the Podfile that
    #         generated this target.
    #
    attr_reader :target_definition

    # @return [Sandbox] The sandbox where the Pods should be installed.
    #
    attr_reader :sandbox

    def path_provider
      root = sandbox.library_support_files_dir(name)
      Target::PathsProvider.new(label, root)
    end

    # @return [String] the name of the library.
    #
    def name
      label
    end

    # @return [String] the name of the library.
    #
    def product_name
      "lib#{label}.a"
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

    # @!group Information storage

    # @return [Hash{String=>Symbol}] A hash representing the user build
    #         configurations where each key corresponds to the name of a
    #         configuration and its value to its type (`:debug` or `:release`).
    #
    attr_accessor :user_build_configurations

    # @return [PBXNativeTarget] the target generated in the Pods project for
    #         this library.
    #
    attr_accessor :target

    attr_accessor :platform

    # @return [Platform] the platform for this library.
    #
    def platform
      @platform ||= target_definition.platform
    end

    #-------------------------------------------------------------------------#

  end
end
