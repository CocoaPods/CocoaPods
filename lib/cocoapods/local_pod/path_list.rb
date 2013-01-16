module Pod
  class LocalPod

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

      # @param  [Pathname] root The root of the PathList.
      #
      def initialize(root)
        @root = root
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

      # @return [void] Reads the file system and populates the files and paths
      #         lists.
      #
      def read_file_system
        root_length  = root.to_s.length+1
        paths  = Dir.glob(root + "**/*", File::FNM_DOTMATCH)
        paths  = paths.reject { |p| p == "#{root}/." || p == "#{root}/.." }
        dirs   = paths.select { |path| File.directory?(path) }
        dirs   = dirs.map { |p| p[root_length..-1] }
        paths  = paths.map { |p| p[root_length..-1] }
        @files = paths - dirs
        @dirs  = dirs.map { |d| d.gsub(/\/\.\.?$/,'') }.uniq
      end

      # @return [Array<Pathname>] Similar to {glob} but returns the absolute
      #         paths.
      #
      def glob(patterns, dir_pattern = nil, exclude_patterns = nil)
        relative_glob(patterns, dir_pattern, exclude_patterns).map {|p| root + p }
      end

      # @return [Array<Pathname>] The list of relative paths that are case
      #         insensitively matched by a given pattern. This method emulates
      #         {Dir#glob} with the {File::FNM_CASEFOLD} option.
      #
      # @param  [String,Array<String>] patterns
      #         A single {Dir#glob} like pattern, or a list of patterns.
      #
      # @param  [String] dir_pattern
      #         An optional pattern to append to a pattern, if it is the path
      #         to a directory.
      #
      def relative_glob(patterns, dir_pattern = nil, exclude_patterns = nil)
        return [] if patterns.empty?
        patterns = [ patterns ] if patterns.is_a? String

        list = patterns.map do |pattern|
          if pattern.is_a?(String)
            pattern += '/' + dir_pattern if directory?(pattern) && dir_pattern
            expanded_patterns = dir_glob_equivalent_patterns(pattern)
            files.select do |path|
              expanded_patterns.any? do |p|
                File.fnmatch(p, path, File::FNM_CASEFOLD | File::FNM_PATHNAME)
              end
            end
          else
            files.select { |path| path.match(pattern) }
          end
        end.flatten

        list -= relative_glob(exclude_patterns) if exclude_patterns

        list.map { |path| Pathname.new(path) }
      end

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
        pattern.gsub('/**/', '{/**/,/}')
        values_by_set = {}
        pattern.scan(/\{[^}]*\}/) do |set|
          values = set.gsub(/[{}]/, '').split(',')
          values_by_set[set] = values
        end

        if values_by_set.empty?
          [ pattern ]
        else
          patterns = [ pattern ]
          values_by_set.each do |set, values|
            patterns = patterns.map do |pattern|
              values.map do |value|
                pattern.gsub(set, value)
              end
            end.flatten
          end
          patterns
        end
      end
    end # PathList
  end # LocalPod
end # Pod
