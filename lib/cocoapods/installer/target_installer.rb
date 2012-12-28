module Pod
  class Installer

    # This class is reponsible of creating and configuring the static library
    # target in Pods project. Every target is generated from a target
    # definition of the Podfile.
    #
    class TargetInstaller
      include Config::Mixin

      # @return [Podfile]
      #
      # TODO: is really needed to pass the podfile?
      #
      attr_reader :podfile

      # @return [Project] The Pods project.
      #
      attr_reader :project

      # @return [TargetDefinition] The target definition whoose target needs to
      # be generated.
      #
      attr_reader :target_definition

      def initialize(podfile, project, target_definition)
        @podfile = podfile
        @project = project
        @target_definition = target_definition
      end

      # @return [void] Creates the target in the Pods project and its support
      # files.
      #
      # @param [Array<LocalPod>] pods   The pods are required by the target
      #                                 definition of this installer.
      #
      # @param [Sandbox] sandbox        The sanbox where the support files
      #                                 should be generated.
      #
      def install!(pods, sandbox)
        pods.each { |p| p.top_specification.activate_platform(@target_definition.platform) }
      
        self.requires_arc = pods.any? { |pod| pod.requires_arc? }

        @target = @project.add_pod_target(@target_definition.label, @target_definition.platform)

        source_file_descriptions = []
        pods.each { |p| p.add_build_files_to_target(@target) }

        support_files_group = @project.support_files_group.new_group(@target_definition.label)
        target_support_files.each { |path| support_files_group.new_file(path) }

        xcconfig_file = support_files_group.files.find { |f| f.path == @target_definition.xcconfig_name }
        configure_build_configurations(xcconfig_file, sandbox)
        create_files(pods, sandbox)
      end

      # @return [PBXNativeTarget] The target generated by the installation
      # process.
      #
      attr_reader :target


      # @return [Boold] Wether the any of the pods requires arc.
      #
      # TODO: This should not be an attribute reader.
      #
      attr_accessor :requires_arc

      attr_reader :xcconfig

      # In a workspace this is where the static library headers should be found.
      #
      def generate_xcconfig(pods, sandbox)
        xcconfig = Xcodeproj::Config.new({
          'ALWAYS_SEARCH_USER_PATHS' => 'YES', # needed to make EmbedReader build
          'OTHER_LDFLAGS'            => default_ld_flags,
          'HEADER_SEARCH_PATHS'      => '${PODS_HEADERS_SEARCH_PATHS}',
          # CocoaPods global keys
          'PODS_ROOT'                         => @target_definition.relative_pods_root,
          'PODS_BUILD_HEADERS_SEARCH_PATHS'   => quoted(sandbox.build_headers.search_paths).join(" "),
          'PODS_PUBLIC_HEADERS_SEARCH_PATHS'  => quoted(sandbox.public_headers.search_paths).join(" "),
          # Pods project specific keys
          'PODS_HEADERS_SEARCH_PATHS' => '${PODS_PUBLIC_HEADERS_SEARCH_PATHS}'
        })
        pods.each { |pod| xcconfig.merge!(pod.xcconfig) }
        @xcconfig = xcconfig
      end

      #
      #
      def copy_resources_script_for(pods)
        @copy_resources_script ||= Generator::CopyResourcesScript.new(pods.map { |p| p.relative_resource_files }.flatten)
      end

      def bridge_support_generator_for(pods, sandbox)
        Generator::BridgeSupport.new(pods.map do |pod|
          pod.relative_header_files.map { |header| sandbox.root + header }
        end.flatten)
      end

      # TODO This has to be removed, but this means the specs have to be updated if they need a reference to the prefix header.
      def prefix_header_filename
        @target_definition.prefix_header_name
      end

      # TODO move out to Generator::PrefixHeader
      def save_prefix_header_as(pathname, pods)
        pathname.open('w') do |header|
          header.puts "#ifdef __OBJC__"
          header.puts "#import #{@target_definition.platform == :ios ? '<UIKit/UIKit.h>' : '<Cocoa/Cocoa.h>'}"
          header.puts "#endif"
          pods.each do |pod|
            if prefix_header_contents = pod.top_specification.prefix_header_contents
              header.puts
              header.puts prefix_header_contents
            elsif prefix_header = pod.prefix_header_file
              header.puts
              header.puts prefix_header.read
            end
          end
        end
      end

      def target_support_files
        [:copy_resources_script_name, :prefix_header_name, :xcconfig_name].map { |file| @target_definition.send(file) }
      end

      def configure_build_configurations(xcconfig_file, sandbox)
        @target.build_configurations.each do |config|
          config.base_configuration_reference = xcconfig_file
          config.build_settings['OTHER_LDFLAGS'] = ''
          config.build_settings['GCC_PREFIX_HEADER'] = @target_definition.prefix_header_name
          config.build_settings['PODS_ROOT'] = '${SRCROOT}'
          config.build_settings['PODS_HEADERS_SEARCH_PATHS'] = '${PODS_BUILD_HEADERS_SEARCH_PATHS}'
          config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = @target_definition.inhibit_all_warnings? ? 'YES' : 'NO'
        end
      end

      #
      #
      def create_files(pods, sandbox)
        bridge_support_metadata_path = sandbox.root + @target_definition.bridge_support_name
        UI.message "- Generating BridgeSupport metadata file at #{UI.path bridge_support_metadata_path}" do
          bridge_support_generator_for(pods, sandbox).save_as(bridge_support_metadata_path)
          copy_resources_script_for(pods).resources << @target_definition.bridge_support_name
        end if @podfile.generate_bridge_support?

        UI.message "- Generating xcconfig file at #{UI.path(sandbox.root + @target_definition.xcconfig_name)}" do
          generate_xcconfig(pods, sandbox)
          xcconfig.save_as(sandbox.root + @target_definition.xcconfig_name)
          @target_definition.xcconfig = xcconfig
        end

        UI.message "- Generating prefix header at #{UI.path(sandbox.root + @target_definition.prefix_header_name)}" do
          save_prefix_header_as(sandbox.root + @target_definition.prefix_header_name, pods)
        end

        UI.message "- Generating copy resources script at #{UI.path(sandbox.root + @target_definition.copy_resources_script_name)}" do
          copy_resources_script_for(pods).save_as(sandbox.root + @target_definition.copy_resources_script_name)
        end
      end

      private

      def quoted(strings)
        strings.map { |s| "\"#{s}\"" }
      end

      def default_ld_flags
        flags = %w{-ObjC}
        flags << '-fobjc-arc' if @podfile.set_arc_compatibility_flag? && self.requires_arc
        flags.join(" ")
      end
    end
  end
end

