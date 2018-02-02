module Pod
  module Generator
    # Generates LLVM module map files. A module map file is generated for each
    # Pod and for each Pod target definition that is built as a framework. It
    # specifies a different umbrella header than usual to avoid name conflicts
    # with existing headers of the podspec.
    #
    class ModuleMap
      # @return [PodTarget] the target represented by this Info.plist.
      #
      attr_reader :target

      attr_reader :headers

      Header = Struct.new(:path, :umbrella, :private, :textual, :size, :mtime) do
        alias private? private
        def to_s
          [
            (:private if private?),
            (:textual if textual),
            (:umbrella if umbrella),
            'header',
            %("#{path}"),
            attrs,
        ].compact.join(' ')
        end

        def attrs
          attrs = {
            'size' => size,
            'mtime' => mtime,
          }.reject {|k,v| v.nil? }
          return nil if attrs.empty?
          attrs.to_s
        end
      end

      # Initialize a new instance
      #
      # @param  [PodTarget] target @see target
      #
      def initialize(target)
        @target = target
        @headers = [Header.new(target.umbrella_header_path.basename, true)]
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
        <<-MODULE_MAP.strip_heredoc
          #{module_specificier_prefix}module #{target.product_module_name} {
            #{headers.join("\n  ")}

            export *
            module * { export * }
          }
        MODULE_MAP
      end

      private

      # The prefix to `module` to prepend in the module map.
      # Ensures that only framework targets have `framework` prepended.
      #
      def module_specificier_prefix
        if target.requires_frameworks?
          'framework '
        else
          ''
        end
      end
    end
  end
end
