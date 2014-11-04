module Pod
  module Generator
    # Generates the LLVM module map files. A module map file is generated for
    # each Pod and for each Pod target definition, that requires to be built as
    # framework. It specifies a different umbrella header then usual to avoid
    # name conflicts with existing headers of the podspec.
    #
    class ModuleMap
      # @return [Target] the target represented by this Info.plist.
      #
      attr_reader :target

      # @param  [Target] target @see target
      #
      def initialize(target)
        @target = target
      end

      # Generates and saves the Info.plist to the given path.
      #
      # @param  [Pathname] path
      #         the path where the prefix header should be stored.
      #
      # @return [void]
      #
      def save_as(path)
        FileUtils.mkdir_p(path + '..')
        contents = generate
        File.open(path, 'w') do |f|
          f.write(contents)
        end
      end

      # Generates the contents of the module.modulemap file.
      #
      # @return [String]
      #
      def generate
        <<-eos.strip_heredoc
          framework module #{target.product_module_name} {
            umbrella header "#{target.umbrella_header_path.basename}"

            export *
            module * { export * }
          }
        eos
      end
    end
  end
end
