module Pod
  class Installer
    # Links the headers from every pod target into the Sandbox directory.
    #
    class SandboxHeaderLinker
      # @return [Sandbox] The sandbox of the installation.
      #
      attr_reader :sandbox

      # @return [Array<PodTarget>] The pod targets of the installation.
      #
      attr_reader :pod_targets

      # Initialize a new instance
      #
      # @param [Sandbox] sandbox @see #sandbox
      # @param [Array<PodTarget>] pod_targets @see #pod_targets
      #
      def initialize(sandbox, pod_targets)
        @sandbox = sandbox
        @pod_targets = pod_targets
      end

      # Creates the link to the headers of the Pod in the sandbox.
      #
      # @return [void]
      #
      def link!
        UI.message '- Linking headers' do
          pod_targets.each do |pod_target|
            # When integrating Pod as frameworks, built Pods are built into
            # frameworks, whose headers are included inside the built
            # framework. Those headers do not need to be linked from the
            # sandbox.
            next if pod_target.build_as_framework? && pod_target.should_build?

            headers_sandbox = Pathname.new(pod_target.pod_name)
            added_build_headers = false
            added_public_headers = false

            file_accessors = pod_target.file_accessors.reject { |fa| fa.spec.non_library_specification? }
            file_accessors.each do |file_accessor|
              # Private headers will always end up in Pods/Headers/Private/PodA/*.h
              # This will allow for `""` imports to work.
              header_mappings(headers_sandbox, file_accessor, file_accessor.headers).each do |namespaced_path, files|
                added_build_headers = true
                pod_target.build_headers.add_files(namespaced_path, files)
              end

              # Public headers on the other hand will be added in Pods/Headers/Public/PodA/PodA/*.h
              # The extra folder is intentional in order for `<>` imports to work.
              header_mappings(headers_sandbox, file_accessor, file_accessor.public_headers).each do |namespaced_path, files|
                added_public_headers = true
                sandbox.public_headers.add_files(namespaced_path, files)
              end
            end

            pod_target.build_headers.add_search_path(headers_sandbox, pod_target.platform) if added_build_headers
            sandbox.public_headers.add_search_path(headers_sandbox, pod_target.platform) if added_public_headers
          end
        end
      end

      private

      # Computes the destination sub-directory in the sandbox
      #
      # @param  [Pathname] headers_sandbox
      #         The sandbox where the header links should be stored for this
      #         Pod.
      #
      # @param  [Sandbox::FileAccessor] file_accessor
      #         The consumer file accessor for which the headers need to be
      #         linked.
      #
      # @param  [Array<Pathname>] headers
      #         The absolute paths of the headers which need to be mapped.
      #
      # @return [Hash{Pathname => Array<Pathname>}] A hash containing the
      #         headers folders as the keys and the absolute paths of the
      #         header files as the values.
      #
      def header_mappings(headers_sandbox, file_accessor, headers)
        consumer = file_accessor.spec_consumer
        header_mappings_dir = consumer.header_mappings_dir
        dir = headers_sandbox
        dir += consumer.header_dir if consumer.header_dir

        mappings = {}
        headers.each do |header|
          next if header.to_s.include?('.framework/')

          sub_dir = dir
          if header_mappings_dir
            relative_path = header.relative_path_from(file_accessor.path_list.root + header_mappings_dir)
            sub_dir += relative_path.dirname
          end
          mappings[sub_dir] ||= []
          mappings[sub_dir] << header
        end
        mappings
      end
    end
  end
end
