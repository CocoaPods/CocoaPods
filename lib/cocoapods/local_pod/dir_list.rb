module Pod
  class LocalPod

    # The {DirList} class is designed to perform multiple glob matches against
    #   a given directory. Basically, it generates a list of all the children
    #   paths and matches the globs patterns against them, resulting in just
    #   one access to the file system.
    #
    # @note A {DirList} once it has generated the list of the paths this is
    # updated only if explicitly requested by calling
    # {DirList#read_file_system}
    #
    class DirList

      # @return [Pathname] The root of the list whose files and directories
      #   are used to perform the matching operations.
      #
      attr_accessor :root

      # @param [Pathname] root The root of the DirList.
      #
      def initialize(root)
        @root = root
      end

      # @return [Array<String>] The list of absolute the path of all the files
      #   contained in {root}.
      #
      def files
        read_file_system unless @files
        @files
      end

      # @return [Array<String>] The list of absolute the path of all the
      #   directories contained in {root}.
      #
      def dirs
        read_file_system unless @dirs
        @dirs
      end

      # @return [void] Reads the file system and populates the files and paths
      #   lists.
      #
      def read_file_system
        root_length = root.to_s.length+1
        paths  = Dir.glob(root + "**/*", File::FNM_DOTMATCH)
        paths  = paths.map { |p| p[root_length..-1] }
        paths  = paths.reject do |p|
          p == '.' || p == '..'
        end
        dirs_entries  = paths.select { |path| path.end_with?('/.', '/..') }
        @files = paths - dirs_entries
        @dirs  = dirs_entries.map { |d| d.gsub(/\/\.\.?$/,'') }.uniq
      end

      # @return [Array<Pathname>] Similar to {glob} but returns the absolute
      #   paths.
      #
      def glob(patterns, dir_pattern = nil)
        relative_glob(patterns, dir_pattern).map {|p| root + p }
      end

      # @return [Array<Pathname>] The list of the relative paths that are
      #   case insensitively matched by a given pattern. This method emulates
      #   {Dir#glob} with the {File::FNM_CASEFOLD} option.
      #
      # @param [Array<String>] patterns   A {Dir#glob} like pattern.
      #
      # @param [String] dir_pattern       An optional pattern to append to
      #                                   pattern, if this one is the path of a
      #                                   directory.
      #
      def relative_glob(patterns, dir_pattern = nil)
        patterns = [ patterns ] if patterns.is_a? String
        list = patterns.map do |pattern|
          pattern += '/' + dir_pattern if directory?(pattern) && dir_pattern
          expanded_patterns = dir_glob_equivalent_patterns(pattern)
          files.select do |path|
            expanded_patterns.any? do |p|
              File.fnmatch(p, path, File::FNM_CASEFOLD | File::FNM_PATHNAME)
            end
          end
        end.flatten
        list.map { |path| Pathname.new(path) }
      end

      # @return [Bool] Wether a path is a directory. The result of this method
      #   computed without accessing the file system and is case insensitive.
      #
      # @param [String, Pathname] sub_path The path that could be a directory.
      #
      def directory?(sub_path)
        sub_path = sub_path.to_s.downcase.gsub(/\/$/, '')
        dirs.any? { |dir|  dir.downcase == sub_path }
      end

      # @return [Array<String>] An array containing the list of patterns for
      #   necessary to emulate {Dir#glob} with #{File.fnmatch}. If
      #   #{File.fnmatch} invoked with the File::FNM_PATHNAME matches any of
      #   the returned patterns {Dir#glob} would have matched the original
      #   pattern.
      #
      #   The expansion provides support for:
      #
      #   - Literals
      #
      #       expand_pattern_literals('{file1,file2}.{h,m}')
      #       => ["file1.h", "file1.m", "file2.h", "file2.m"]
      #
      #       expand_pattern_literals('file*.*')
      #       => ["file*.*"]
      #
      #   - Matching the direct children of a directory with `**`
      #
      #       expand_pattern_literals('Classes/**/file.m')
      #       => ["Classes/**/file.m", "Classes/file.m"]
      #
      # @param [String] pattern   A {Dir#glob} like pattern.
      #
      def dir_glob_equivalent_patterns(pattern)
        pattern.gsub!('/**/', '{/**/,/}')
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
    end # DirList
  end # LocalPod
end # Pod
