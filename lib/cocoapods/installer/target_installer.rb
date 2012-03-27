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
          'PODS_ROOT' => '$(SRCROOT)/Pods',
          'ALWAYS_SEARCH_USER_PATHS' => 'YES', # needed to make EmbedReader build
          # This makes categories from static libraries work, which many libraries
          # require, so we add these by default.
          'OTHER_LDFLAGS'            => default_ld_flags,
        })
      end

      def copy_resources_script_for(pods)
        @copy_resources_script ||= Generator::CopyResourcesScript.new(pods.map { |p| p.resources }.flatten)
      end

      def bridge_support_generator_for(pods, sandbox)
        Generator::BridgeSupport.new(pods.map do |pod|
          pod.header_files.map { |header| sandbox.root + header }
        end.flatten)
      end

      def bridge_support_filename
        "#{@target_definition.label}.bridgesupport"
      end

      # TODO move out to Generator::PrefixHeader
      def save_prefix_header_as(pathname)
        pathname.open('w') do |header|
          header.puts "#ifdef __OBJC__"
          header.puts "#import #{@podfile.platform == :ios ? '<UIKit/UIKit.h>' : '<Cocoa/Cocoa.h>'}"
          header.puts "#endif"
        end
      end

      def target_support_files
        [:copy_resources_script_name, :prefix_header_name, :xcconfig_name].map { |file| @target_definition.send(file) }
      end

      # TODO move xcconfig related code into the xcconfig method, like copy_resources_script and generate_bridge_support.
      def install!(pods, sandbox)
        self.requires_arc = pods.any? { |pod| pod.requires_arc? }
        
        # First add the target to the project
        @target = @project.targets.new_static_library(@target_definition.label)

        pods.each do |pod|
          xcconfig.merge!(pod.specification.xcconfig)
          pod.add_to_target(@target)
          
          # TODO: this doesn't need to be done here, it has nothing to do with the target
          pod.link_headers
        end
        
        xcconfig.merge!('HEADER_SEARCH_PATHS' => quoted(sandbox.header_search_paths).join(" "))

        support_files_group = @project.group("Targets Support Files").create_group(@target_definition.label)
        support_files_group.create_files(target_support_files)

        xcconfig_file = support_files_group.files.where(:path => @target_definition.xcconfig_name)

        configure_build_configurations(xcconfig_file)
        create_files(pods, sandbox)
      end

      def configure_build_configurations(xcconfig_file)
        @target.build_configurations.each do |config|
          config.base_configuration = xcconfig_file
          config.build_settings['OTHER_LDFLAGS'] = ''
          config.build_settings['GCC_PREFIX_HEADER'] = @target_definition.prefix_header_name
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
        puts "* Generating xcconfig file at `#{sandbox.root + @target_definition.xcconfig_name}'" if config.verbose?
        xcconfig.save_as(sandbox.root + @target_definition.xcconfig_name)
        puts "* Generating prefix header at `#{sandbox.root + @target_definition.prefix_header_name}'" if config.verbose?
        save_prefix_header_as(sandbox.root + @target_definition.prefix_header_name)
        puts "* Generating copy resources script at `#{sandbox.root + @target_definition.copy_resources_script_name}'" if config.verbose?
        copy_resources_script_for(pods).save_as(sandbox.root + @target_definition.copy_resources_script_name)
      end
      
      private
      
      def quoted(strings)
        strings.map { |s| "\"#{s}\"" }
      end
      
      def default_ld_flags
        flags = %w{-ObjC -all_load}
        flags << '-fobjc-arc' if self.requires_arc
        flags.join(" ")
      end
    end
  end
end

