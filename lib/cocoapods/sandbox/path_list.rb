module Pod
  class Sandbox
    # The PathList class is designed to perform multiple glob matches against
    # a given directory. Basically, it generates a list of all the children
    # paths and matches the globs patterns against them, resulting in just one
    # access to the file system.
    #
    # @note   A PathList once it has generated the list of the paths this is
    #         updated only if explicitly requested by calling
    #         {#read_file_system}
    #
    class PathList
      # @return [Pathname] The root of the list whose files and directories
      #         are used to perform the matching operations.
      #
      attr_accessor :root

      # @return [Absolutepathname] The list of .xcdatamodeld bundles in source files
      attr_accessor :datamodels

      # Initialize a new instance
      #
      # @param  [Pathname] root The root of the PathList.
      #
      def initialize(root)
        @root = root
        @glob_cache = {}
        @datamodels = []
      end

      # @return [Array<String>] The list of absolute the path of all the files
      #         contained in {root}.
      #
      def files
        read_file_system unless @files
        @files
      end

      # @return [Array<String>] The list of absolute the path of all the
      #         directories contained in {root}.
      #
      def dirs
        read_file_system unless @dirs
        @dirs
      end

      # @return [void] the .xcdatamodeld internals are already exposed by Dir.glob,
      # it should be take as a file so that it can be added to project as a source file.
      #
      def wrap_xcdatamodeld_as_file
        @datamodels = @dirs.select { |d| !(d =~ /\.xcdatamodeld$/).nil? }
        return unless @datamodels.count > 0

        # files/dirs under that dir had been globbed, remove them
        left_files = @files
        left_dirs = @dirs
        @datamodels.map do |bundle_dir|
          left_files = left_files.reject { |sub_file| sub_file.include?(bundle_dir) }
          left_dirs = left_dirs.reject { |sub_dir| sub_dir.include?(bundle_dir) && sub_dir.length > bundle_dir.length }
        end
        @files = left_files
        @dirs = left_dirs

        @datamodels = @datamodels.map { |d| "#{root}/" + d }
      end

      # @return [void] Reads the file system and populates the files and paths
      #         lists.
      #
      def read_file_system
        unless root.exist?
          raise Informative, "Attempt to read non existent folder `#{root}`."
        end
        root_length  = root.to_s.length + 1
        escaped_root = escape_path_for_glob(root)
        paths  = Dir.glob(escaped_root + '**/*', File::FNM_DOTMATCH)
        absolute_dirs  = paths.select { |path| File.directory?(path) }
        relative_dirs  = absolute_dirs.map  { |p| p[root_length..-1] }
        absolute_paths = paths.reject { |p| p == "#{root}/." || p == "#{root}/.." }
        relative_paths = absolute_paths.map { |p| p[root_length..-1] }
        @files = relative_paths - relative_dirs
        @dirs  = relative_dirs.map { |d| d.gsub(/\/\.\.?$/, '') }.reject { |d| d == '.' || d == '..' } .uniq
        @glob_cache = {}
      end

      #-----------------------------------------------------------------------#

      public

      # @!group Globbing

      # Similar to {glob} but returns the absolute paths.
      #
      # @param  [String,Array<String>] patterns
      #         @see #relative_glob
      #
      # @param  [Hash] options
      #         @see #relative_glob
      #
      # @return [Array<Pathname>]
      #
      def glob(patterns, options = {})
        relative_glob(patterns, options).map { |p| root + p }
      end

      # The list of relative paths that are case insensitively matched by a
      # given pattern. This method emulates {Dir#glob} with the
      # {File::FNM_CASEFOLD} option.
      #
      # @param  [String,Array<String>] patterns
      #         A single {Dir#glob} like pattern, or a list of patterns.
      #
      # @param  [Hash] options
      #
      # @option options [String] :dir_pattern
      #         An optional pattern to append to a pattern, if it is the path
      #         to a directory.
      #
      # @option options [Array<String>] :exclude_patterns
      #         Exclude specific paths given by those patterns.
      #
      # @option options [Array<String>] :include_dirs
      #         Additional paths to take into account for matching.
      #
      # @return [Array<Pathname>]
      #
      def relative_glob(patterns, options = {})
        return [] if patterns.empty?

        cache_key = options.merge(:patterns => patterns)
        cached_value = @glob_cache[cache_key]
        return cached_value if cached_value

        dir_pattern = options[:dir_pattern]
        exclude_patterns = options[:exclude_patterns]
        include_dirs = options[:include_dirs]

        if include_dirs
          full_list = files + dirs
        else
          full_list = files
        end

        list = Array(patterns).map do |pattern|
          if directory?(pattern) && dir_pattern
            pattern += '/' unless pattern.end_with?('/')
            pattern += dir_pattern
          end
          expanded_patterns = dir_glob_equivalent_patterns(pattern)
          full_list.select do |path|
            expanded_patterns.any? do |p|
              File.fnmatch(p, path, File::FNM_CASEFOLD | File::FNM_PATHNAME)
            end
          end
        end.flatten

        list = list.map { |path| Pathname.new(path) }
        if exclude_patterns
          exclude_options = { :dir_pattern => '**/*', :include_dirs => include_dirs }
          list -= relative_glob(exclude_patterns, exclude_options)
        end
        @glob_cache[cache_key] = list
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Private helpers

      # @return [Bool] Wether a path is a directory. The result of this method
      #         computed without accessing the file system and is case
      #         insensitive.
      #
      # @param  [String, Pathname] sub_path The path that could be a directory.
      #
      def directory?(sub_path)
        sub_path = sub_path.to_s.downcase.sub(/\/$/, '')
        dirs.any? { |dir| dir.downcase == sub_path }
      end

      # @return [Array<String>] An array of patterns converted from a
      #         {Dir.glob} pattern to patterns that {File.fnmatch} can handle.
      #         This is used by the {#relative_glob} method to emulate
      #         {Dir.glob}.
      #
      #   The expansion provides support for:
      #
      #   - Literals
      #
      #       dir_glob_equivalent_patterns('{file1,file2}.{h,m}')
      #       => ["file1.h", "file1.m", "file2.h", "file2.m"]
      #
      #   - Matching the direct children of a directory with `**`
      #
      #       dir_glob_equivalent_patterns('Classes/**/file.m')
      #       => ["Classes/**/file.m", "Classes/file.m"]
      #
      # @param [String] pattern   A {Dir#glob} like pattern.
      #
      def dir_glob_equivalent_patterns(pattern)
        pattern = pattern.gsub('/**/', '{/**/,/}')
        values_by_set = {}
        pattern.scan(/\{[^}]*\}/) do |set|
          values = set.gsub(/[{}]/, '').split(',')
          values_by_set[set] = values
        end

        if values_by_set.empty?
          [pattern]
        else
          patterns = [pattern]
          values_by_set.each do |set, values|
            patterns = patterns.map do |old_pattern|
              values.map do |value|
                old_pattern.gsub(set, value)
              end
            end.flatten
          end
          patterns
        end
      end

      # Escapes the glob metacharacters from a given path so it can used in
      # Dir#glob and similar methods.
      #
      # @note   See CocoaPods/CocoaPods#862.
      #
      # @param  [String, Pathname] path
      #         The path to escape.
      #
      # @return [Pathname] The escaped path.
      #
      def escape_path_for_glob(path)
        result = path.to_s
        characters_to_escape = ['[', ']', '{', '}', '?', '*']
        characters_to_escape.each do |character|
          result.gsub!(character, "\\#{character}")
        end
        Pathname.new(result)
      end

      #-----------------------------------------------------------------------#
    end
  end
end
