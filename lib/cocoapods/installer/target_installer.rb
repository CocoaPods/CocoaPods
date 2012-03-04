module Pod
  class Installer
    class TargetInstaller
      include Config::Mixin

      attr_reader :podfile, :project, :target_definition, :target

      def initialize(podfile, project, target_definition)
        @podfile, @project, @target_definition = podfile, project, target_definition
      end

      def xcconfig
        @xcconfig ||= Xcodeproj::Config.new({
          # In a workspace this is where the static library headers should be found.
          'PODS_ROOT' => '$(SRCROOT)/Pods',
          'HEADER_SEARCH_PATHS' => '"$(PODS_ROOT)/Headers"',
          'ALWAYS_SEARCH_USER_PATHS' => 'YES', # needed to make EmbedReader build
          # This makes categories from static libraries work, which many libraries
          # require, so we add these by default.
          'OTHER_LDFLAGS'            => '-ObjC -all_load',
        })
      end

      def xcconfig_filename
        "#{@target_definition.lib_name}.xcconfig"
      end

      def copy_resources_script_for(pods)
        @copy_resources_script ||= Generator::CopyResourcesScript.new(pods.map { |p| p.resources }.flatten)
      end

      def copy_resources_filename
        "#{@target_definition.lib_name}-resources.sh"
      end

      def bridge_support_generator_for(pods, sandbox)
        Generator::BridgeSupport.new(pods.map do |pod|
          pod.header_files.map { |header| sandbox.root + header }
        end.flatten)
      end

      def bridge_support_filename
        "#{@target_definition.lib_name}.bridgesupport"
      end

      # TODO move out to Generator::PrefixHeader
      def save_prefix_header_as(pathname)
        pathname.open('w') do |header|
          header.puts "#ifdef __OBJC__"
          header.puts "#import #{@podfile.platform == :ios ? '<UIKit/UIKit.h>' : '<Cocoa/Cocoa.h>'}"
          header.puts "#endif"
        end
      end

      def prefix_header_filename
        "#{@target_definition.lib_name}-prefix.pch"
      end
      
      def target_support_files
        [copy_resources_filename, prefix_header_filename, xcconfig_filename]
      end

      # TODO move xcconfig related code into the xcconfig method, like copy_resources_script and generate_bridge_support.
      def install!(pods, sandbox)
        # First add the target to the project
        @target = @project.targets.new_static_library(@target_definition.lib_name)

        pods.each do |pod|
          xcconfig.merge!(pod.specification.xcconfig)
          pod.add_to_target(@target)
          pod.link_headers
        end
        
        xcconfig.merge!('HEADER_SEARCH_PATHS' => sandbox.header_search_paths.join(" "))

        support_files_group = @project.group("Targets Support Files").create_group(@target_definition.lib_name)
        support_files_group.add_file_paths(target_support_files)

        xcconfig_file = support_files_group.file_with_path(xcconfig_filename)

        configure_build_configurations(xcconfig_file)
        create_files(pods, sandbox)
      end
      
      def configure_build_configurations(xcconfig_file)
        @target.build_configurations.each do |config|
          config.baseConfiguration = xcconfig_file
          config.build_settings['OTHER_LDFLAGS'] = ''
          config.build_settings['GCC_PREFIX_HEADER'] = prefix_header_filename
          config.build_settings['PODS_ROOT'] = '$(SRCROOT)'
        end
      end

      def create_files(pods, sandbox)
        if @podfile.generate_bridge_support?
          bridge_support_metadata_path = sandbox.root + bridge_support_filename
          puts "* Generating BridgeSupport metadata file at `#{bridge_support_metadata_path}'" if config.verbose?
          bridge_support_generator_for(pods, sandbox).save_as(bridge_support_metadata_path)
          copy_resources_script_for(pods).resources << bridge_support_filename
        end
        puts "* Generating xcconfig file at `#{sandbox.root + xcconfig_filename}'" if config.verbose?
        xcconfig.save_as(sandbox.root + xcconfig_filename)
        puts "* Generating prefix header at `#{sandbox.root + prefix_header_filename}'" if config.verbose?
        save_prefix_header_as(sandbox.root + prefix_header_filename)
        puts "* Generating copy resources script at `#{sandbox.root + copy_resources_filename}'" if config.verbose?
        copy_resources_script_for(pods).save_as(sandbox.root + copy_resources_filename)
      end
    end
  end
end

