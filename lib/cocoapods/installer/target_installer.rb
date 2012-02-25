module Pod
  class Installer
    class TargetInstaller
      include Config::Mixin
      include Shared

      attr_reader :podfile, :project, :definition, :target

      def initialize(podfile, project, definition)
        @podfile, @project, @definition = podfile, project, definition
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
        "#{@definition.lib_name}.xcconfig"
      end

      def copy_resources_script_for(pods)
        @copy_resources_script ||= Generator::CopyResourcesScript.new(pods.map { |p| p.resources }.flatten)
      end

      def copy_resources_filename
        "#{@definition.lib_name}-resources.sh"
      end

      def bridge_support_generator
        Generator::BridgeSupport.new(build_specifications.map do |spec|
          spec.header_files.map do |header|
            config.project_pods_root + header
          end
        end.flatten)
      end

      def bridge_support_filename
        "#{@definition.lib_name}.bridgesupport"
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
        "#{@definition.lib_name}-prefix.pch"
      end

      # TODO move xcconfig related code into the xcconfig method, like copy_resources_script and generate_bridge_support.
      def install!(pods, sandbox)
        # First add the target to the project
        @target = @project.targets.new_static_library(@definition.lib_name)

        pods.each do |pod|
          xcconfig.merge!(pod.specification.xcconfig)
          pod.add_to_target(@target)
          pod.link_headers
        end
        
        xcconfig.merge!('HEADER_SEARCH_PATHS' => sandbox.header_search_paths.join(" "))

        # Add all the target related support files to the group, even the copy
        # resources script although the project doesn't actually use them.
        support_files_group = @project.groups.find do |group|
          group.name == "Targets Support Files"
        end.groups.new("name" => @definition.lib_name)
        support_files_group.files.new('path' => copy_resources_filename)
        prefix_file = support_files_group.files.new('path' => prefix_header_filename)
        xcconfig_file = support_files_group.files.new("path" => xcconfig_filename)
        
        # Assign the xcconfig as the base config of each config.
        @target.buildConfigurations.each do |config|
          config.baseConfiguration = xcconfig_file
          config.buildSettings['OTHER_LDFLAGS'] = ''
          config.buildSettings['GCC_PREFIX_HEADER'] = prefix_header_filename
          config.buildSettings['PODS_ROOT'] = '$(SRCROOT)'
        end
        
        create_files(pods, sandbox)
      end

      def create_files(pods, sandbox)
        if @podfile.generate_bridge_support?
          bridge_support_metadata_path = sandbox.root + bridge_support_filename
          puts "* Generating BridgeSupport metadata file at `#{bridge_support_metadata_path}'" if config.verbose?
          bridge_support_generator.save_as(bridge_support_metadata_path)
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

