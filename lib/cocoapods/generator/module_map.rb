module Pod
  module Generator
    # Generates LLVM module map files. A module map file is generated for each
    # Pod and for each Pod target definition that is built as a framework. It
    # specifies a different umbrella header than usual to avoid name conflicts
    # with existing headers of the podspec.
    #
    class ModuleMap
      # @return [Target] the target represented by this Info.plist.
      #
      attr_reader :target

      # @return [Array] the private headers of the module
      #
      attr_accessor :private_headers

      # @param  [Target] target @see target
      #
      def initialize(target)
        @target = target
        @private_headers = []
      end

      # Generates and saves the Info.plist to the given path.
      #
      # @param  [Pathname] path
      #         the path where the prefix header should be stored.
      #
      # @return [void]
      #
      def save_as(path)
        contents = generate
        path.open('w') do |f|
          f.write(contents)
        end
      end

      # Generates the contents of the module.modulemap file.
      #
      # @return [String]
      #
      def generate
        result = <<-eos.strip_heredoc
          framework module #{target.product_module_name} {
            umbrella header "#{target.umbrella_header_path.basename}"

            export *
            module * { export * }
        eos

        result << "\n#{generate_private_header_exports}" unless private_headers.empty?
        result << "}\n"
      end

      private

      def generate_private_header_exports
        private_headers.reduce('') do |string, header|
          string << %(  private header "#{header}"\n)
        end
      end
    end
  end
end
