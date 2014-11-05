require 'active_support/core_ext/string/strip'

module Pod
  class Installer
    # Controller class responsible of installing the activated specifications
    # of a single Pod.
    #
    # @note This class needs to consider all the activated specs of a Pod.
    #
    class PodSourceInstaller
      # @return [Sandbox]
      #
      attr_reader :sandbox

      # @return [Hash{Symbol=>Array}] The specifications that need to be
      #         installed grouped by platform.
      #
      attr_reader :specs_by_platform

      # @param [Sandbox] sandbox @see sandbox
      # @param [Hash{Symbol=>Array}] specs_by_platform @see specs_by_platform
      #
      def initialize(sandbox, specs_by_platform)
        @sandbox = sandbox
        @specs_by_platform = specs_by_platform
      end

      # @return [String] A string suitable for debugging.
      #
      def inspect
        "<#{self.class} sandbox=#{sandbox.root} pod=#{root_spec.name}"
      end

      #-----------------------------------------------------------------------#

      public

      # @!group Installation

      # Creates the target in the Pods project and the relative support files.
      #
      # @return [void]
      #
      def install!
        download_source unless predownloaded? || local?
        run_prepare_command
      rescue Informative
        raise
      rescue Object => e
        UI.notice("Error installing #{root_spec.name}")
        clean!
        raise
      end

      # Cleans the installations if appropriate.
      #
      # @todo   As the pre install hooks need to run before cleaning this
      #         method should be refactored.
      #
      # @return [void]
      #
      def clean!
        clean_installation unless local?
      end

      # @return [Hash]
      #
      attr_reader :specific_source

      #-----------------------------------------------------------------------#

      private

      # @!group Installation Steps

      # Downloads the source of the Pod. It also stores the specific options
      # needed to recreate the same exact installation if needed in
      # `#specific_source`.
      #
      # @return [void]
      #
      def download_source
        root.rmtree if root.exist?
        if head_pod?
          begin
            downloader.download_head
            @specific_source = downloader.checkout_options
          rescue RuntimeError => e
            if e.message == 'Abstract method'
              raise Informative, "The pod '" + root_spec.name + "' does not " \
                'support the :head option, as it uses a ' + downloader.name +
                ' source. Remove that option to use this pod.'
            else
              raise
            end
          end
        else
          downloader.download
          unless downloader.options_specific?
            @specific_source = downloader.checkout_options
          end
        end

        if specific_source
          sandbox.store_checkout_source(root_spec.name, specific_source)
        end
      end

      extend Executable
      executable :bash

      # Runs the prepare command bash script of the spec.
      #
      # @note   Unsets the `CDPATH` env variable before running the
      #         shell script to avoid issues with relative paths
      #         (issue #1694).
      #
      # @return [void]
      #
      def run_prepare_command
        return unless root_spec.prepare_command
        UI.section(' > Running prepare command', '', 1) do
          Dir.chdir(root) do
            ENV.delete('CDPATH')
            prepare_command = root_spec.prepare_command.strip_heredoc.chomp
            full_command = "\nset -e\n" + prepare_command
            bash!(full_command)
          end
        end
      end

      # Removes all the files not needed for the installation according to the
      # specs by platform.
      #
      # @return [void]
      #
      def clean_installation
        clean_paths.each { |path| FileUtils.rm_rf(path) } if root.exist?
      end

      #-----------------------------------------------------------------------#

      public

      # @!group Dependencies

      # @return [Downloader] The downloader to use for the retrieving the
      #         source.
      #
      def downloader
        @downloader ||= Downloader.for_target(root, root_spec.source.dup)
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Convenience methods.

      # @return [Array<Specifications>] the specification of the Pod used in
      #         this installation.
      #
      def specs
        specs_by_platform.values.flatten
      end

      # @return [Specification] the root specification of the Pod.
      #
      def root_spec
        specs.first.root
      end

      # @return [Pathname] the folder where the source of the Pod is located.
      #
      def root
        sandbox.pod_dir(root_spec.name)
      end

      # @return [Boolean] whether the source has been pre downloaded in the
      #         resolution process to retrieve its podspec.
      #
      def predownloaded?
        sandbox.predownloaded_pods.include?(root_spec.name)
      end

      # @return [Boolean] whether the pod uses the local option and thus
      #         CocoaPods should not interfere with the files of the user.
      #
      def local?
        sandbox.local?(root_spec.name)
      end

      def head_pod?
        sandbox.head_pod?(root_spec.name)
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Private helpers

      # @return [Array<Sandbox::FileAccessor>] the file accessors for all the
      #         specifications on their respective platform.
      #
      def file_accessors
        return @file_accessors if @file_accessors
        @file_accessors = []
        specs_by_platform.each do |platform, specs|
          specs.each do |spec|
            @file_accessors << Sandbox::FileAccessor.new(path_list, spec.consumer(platform))
          end
        end
        @file_accessors
      end

      # @return [Sandbox::PathList] The path list for this Pod.
      #
      def path_list
        @path_list ||= Sandbox::PathList.new(root)
      end

      # Finds the absolute paths, including hidden ones, of the files
      # that are not used by the pod and thus can be safely deleted.
      #
      # @note   Implementation detail: Don't use `Dir#glob` as there is an
      #         unexplained issue (#568, #572 and #602).
      #
      # @todo   The paths are down-cased for the comparison as issues similar
      #         to #602 lead the files not being matched and so cleaning all
      #         the files. This solution might create side effects.
      #
      # @return [Array<Strings>] The paths that can be deleted.
      #
      def clean_paths
        cached_used = used_files
        glob_options = File::FNM_DOTMATCH | File::FNM_CASEFOLD
        files = Pathname.glob(root + '**/*', glob_options).map(&:to_s)

        files.reject! do |candidate|
          candidate = candidate.downcase
          candidate.end_with?('.', '..') || cached_used.any? do |path|
            path = path.downcase
            path.include?(candidate) || candidate.include?(path)
          end
        end
        files
      end

      # @return [Array<String>] The absolute path of all the files used by the
      #         specifications (according to their platform) of this Pod.
      #
      def used_files
        files = [
          file_accessors.map(&:vendored_frameworks),
          file_accessors.map(&:vendored_libraries),
          file_accessors.map(&:resource_bundle_files),
          file_accessors.map(&:license),
          file_accessors.map(&:prefix_header),
          file_accessors.map(&:preserve_paths),
          file_accessors.map(&:readme),
          file_accessors.map(&:resources),
          file_accessors.map(&:source_files),
        ]

        files.flatten.compact.map(&:to_s).uniq
      end

      #-----------------------------------------------------------------------#
    end
  end
end
