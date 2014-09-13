require 'active_support/core_ext/string/strip'

module Pod
  class Installer
    # Controller class responsible of installing the activated specifications
    # of a single Pod.
    #
    # @note This class needs to consider all the activated specs of a Pod.
    #
    class PodSourceInstaller
      # @return [Sandbox] The installation target.
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
        PodSourcePreparer.new(root_spec, root).prepare! if local?
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

      # Locks the source files if appropriate.
      #
      # @todo   As the pre install hooks need to run before cleaning this
      #         method should be refactored.
      #
      # @return [void]
      #
      def lock_files!
        lock_installation unless local?
      end

      # @return [Hash] @see Downloader#checkout_options
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
        download_result = Downloader.download(download_request, root)

        if (@specific_source = download_result.checkout_options) && specific_source != root_spec.source
          sandbox.store_checkout_source(root_spec.name, specific_source)
        end
      end

      def download_request
        Downloader::Request.new(
          :spec => root_spec,
          :released => released?,
          :head => head_pod?,
        )
      end

      # Locks all of the files in this pod (source, license, etc). This will
      # cause Xcode to warn you if you try to accidently edit one of the files.
      #
      # @return [void]
      #
      def lock_installation
        # We don't want to lock diretories, as that forces you to override
        # those permissions if you decide to delete the Pods folder.
        Dir.glob(root + '**/*').each do |file|
          if File.file?(file)
            # Only remove write permission, since some pods (like Crashlytics)
            # have executable files.
            new_permissions = File.stat(file).mode & ~0222
            File.chmod(new_permissions, file)
          end
        end
      end

      # Removes all the files not needed for the installation according to the
      # specs by platform.
      #
      # @return [void]
      #
      def clean_installation
        cleaner = Sandbox::PodDirCleaner.new(root, specs_by_platform)
        cleaner.clean!
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

      def released?
        !local? && !head_pod? && !predownloaded? && sandbox.specification(root_spec.name) != root_spec
      end

      #-----------------------------------------------------------------------#
    end
  end
end
