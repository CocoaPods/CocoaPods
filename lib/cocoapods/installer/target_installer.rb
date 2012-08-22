module Pod
  class Installer
    class TargetInstaller
      include Config::Mixin

      attr_reader :podfile, :project, :target_definition, :target
      attr_accessor :requires_arc

      def initialize(podfile, project, target_definition)
        @podfile, @project, @target_definition = podfile, project, target_definition
      end

      def xcconfig
        @xcconfig ||= Xcodeproj::Config.new({
          # In a workspace this is where the static library headers should be found.
          'PODS_ROOT'                     => @target_definition.relative_pods_root,
          'PODS_HEADERS_SEARCH_PATHS'     => '${PODS_PUBLIC_HEADERS_SEARCH_PATHS}',
          'ALWAYS_SEARCH_USER_PATHS'      => 'YES', # needed to make EmbedReader build
          'OTHER_LDFLAGS'                 => default_ld_flags
        })
      end

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

      # TODO move xcconfig related code into the xcconfig method, like copy_resources_script and generate_bridge_support.
      def install!(pods, sandbox)
        self.requires_arc = pods.any? { |pod| pod.requires_arc? }

        @target = @project.add_pod_target(@target_definition.label, @target_definition.platform)

        source_file_descriptions = []
        pods.each do |pod|
          xcconfig.merge!(pod.xcconfig)
          source_file_descriptions += pod.source_file_descriptions

          # TODO: this doesn't need to be done here, it has nothing to do with the target
          pod.link_headers
        end
        @target.add_source_files(source_file_descriptions)

        xcconfig.merge!('HEADER_SEARCH_PATHS' => '${PODS_HEADERS_SEARCH_PATHS}')
        xcconfig.merge!('PODS_BUILD_HEADERS_SEARCH_PATHS' => quoted(sandbox.build_headers.search_paths).join(" "))
        xcconfig.merge!('PODS_PUBLIC_HEADERS_SEARCH_PATHS' => quoted(sandbox.public_headers.search_paths).join(" "))

        support_files_group = @project.group("Targets Support Files").create_group(@target_definition.label)
        support_files_group.create_files(target_support_files)

        xcconfig_file = support_files_group.files.where(:path => @target_definition.xcconfig_name)
        configure_build_configurations(xcconfig_file, sandbox)
        create_files(pods, sandbox)
      end

      def configure_build_configurations(xcconfig_file, sandbox)
        @target.build_configurations.each do |config|
          config.base_configuration = xcconfig_file
          config.build_settings['OTHER_LDFLAGS'] = ''
          config.build_settings['GCC_PREFIX_HEADER'] = @target_definition.prefix_header_name
          config.build_settings['PODS_ROOT'] = '${SRCROOT}'
          config.build_settings['PODS_HEADERS_SEARCH_PATHS'] = '${PODS_BUILD_HEADERS_SEARCH_PATHS}'
          config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = @target_definition.inhibit_all_warnings? ? 'YES' : 'NO'
        end
      end

      def create_files(pods, sandbox)
        if @podfile.generate_bridge_support?
          bridge_support_metadata_path = sandbox.root + @target_definition.bridge_support_name
          puts "- Generating BridgeSupport metadata file at `#{bridge_support_metadata_path}'" if config.verbose?
          bridge_support_generator_for(pods, sandbox).save_as(bridge_support_metadata_path)
          copy_resources_script_for(pods).resources << @target_definition.bridge_support_name
        end
        puts "- Generating xcconfig file at `#{sandbox.root + @target_definition.xcconfig_name}'" if config.verbose?
        xcconfig.save_as(sandbox.root + @target_definition.xcconfig_name)
        @target_definition.xcconfig = xcconfig

        puts "- Generating prefix header at `#{sandbox.root + @target_definition.prefix_header_name}'" if config.verbose?
        save_prefix_header_as(sandbox.root + @target_definition.prefix_header_name, pods)
        puts "- Generating copy resources script at `#{sandbox.root + @target_definition.copy_resources_script_name}'" if config.verbose?
        copy_resources_script_for(pods).save_as(sandbox.root + @target_definition.copy_resources_script_name)
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

