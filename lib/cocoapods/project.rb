require 'xcodeproj/project'
require 'xcodeproj/project/object/build_phase'

Xcodeproj::Project::Object::PBXCopyFilesBuildPhase.instance_eval do
  def self.new_pod_dir(project, pod_name, path)
    new(project, nil, {
      "dstPath" => "Pods/#{path}",
      "name"    => "Copy #{pod_name} Public Headers",
    })
  end
end

module Pod
  class Project < Xcodeproj::Project
    # Shortcut access to the `Pods' PBXGroup.
    def pods
      groups.find { |g| g.name == 'Pods' } || groups.new({ 'name' => 'Pods' })
    end

    # Adds a group as child to the `Pods' group.
    def add_pod_group(name)
      pods.groups.new('name' => name)
    end
    
    def build_configuration_list
      objects[root_object.attributes['buildConfigurationList']]
    end
    
    # Shortcut access to build configurations
    def build_configurations
      build_configuration_list.build_configurations
    end
    
    def build_configuration(name)
      build_configurations.find { |c| c.name == name }
    end

    def self.for_platform(platform)
      Pod::Project.new.tap do |project|
        project.main_group << project.groups.new({ 'name' => 'Pods' })
        framework = project.add_system_framework(platform == :ios ? 'Foundation' : 'Cocoa')
        framework.group = project.groups.new({ 'name' => 'Frameworks' })
        project.main_group << framework.group

        configuration_list = project.objects.add(Xcodeproj::Project::Object::XCConfigurationList, {
          'defaultConfigurationIsVisible' => '0',
          'defaultConfigurationName' => 'Release',
        })

        configuration_list.build_configurations.new(
          'name' => 'Debug',
          'buildSettings' => build_settings(platform, :debug)
        )

        configuration_list.build_configurations.new(
          'name' => 'Release',
          'buildSettings' => build_settings(platform, :release)
        )

        project.root_object.attributes['buildConfigurationList'] = configuration_list.uuid
      end
    end

    private

    COMMON_BUILD_SETTINGS = {
      :all => {
        'ALWAYS_SEARCH_USER_PATHS' => 'NO',
        'GCC_C_LANGUAGE_STANDARD' => 'gnu99',
        'INSTALL_PATH' => "$(BUILT_PRODUCTS_DIR)",
        'GCC_WARN_ABOUT_MISSING_PROTOTYPES' => 'YES',
        'GCC_WARN_ABOUT_RETURN_TYPE' => 'YES',
        'GCC_WARN_UNUSED_VARIABLE' => 'YES',
        'OTHER_LDFLAGS' => ''
      }.freeze,
      :debug => {
        'GCC_DYNAMIC_NO_PIC' => 'NO',
        'GCC_PREPROCESSOR_DEFINITIONS' => ["DEBUG=1", "$(inherited)"],
        'GCC_SYMBOLS_PRIVATE_EXTERN' => 'NO',
        'GCC_OPTIMIZATION_LEVEL' => '0'
      }.freeze,
      :ios => {
        'ARCHS' => "$(ARCHS_STANDARD_32_BIT)",
        'GCC_VERSION' => 'com.apple.compilers.llvmgcc42',
        'IPHONEOS_DEPLOYMENT_TARGET' => '4.3',
        'PUBLIC_HEADERS_FOLDER_PATH' => "$(TARGET_NAME)",
        'SDKROOT' => 'iphoneos'
      }.freeze,
      :osx => {
        'ARCHS' => "$(ARCHS_STANDARD_64_BIT)",
        'GCC_ENABLE_OBJC_EXCEPTIONS' => 'YES',
        'GCC_WARN_64_TO_32_BIT_CONVERSION' => 'YES',
        'GCC_VERSION' => 'com.apple.compilers.llvm.clang.1_0',
        'MACOSX_DEPLOYMENT_TARGET' => '10.7',
        'SDKROOT' => 'macosx'
      }.freeze
    }.freeze

    def self.build_settings(platform, scheme)
      COMMON_BUILD_SETTINGS[:all].dup.tap do |settings|
        settings.merge!(COMMON_BUILD_SETTINGS[platform.name])
        
        settings['COPY_PHASE_STRIP'] = scheme == :debug ? 'NO' : 'YES'

        if platform.requires_legacy_ios_archs?
          settings['ARCHS'] = "armv6 armv7"
        end
        if platform == :ios && platform.deployment_target
          settings['IPHONEOS_DEPLOYMENT_TARGET'] = platform.deployment_target.to_s
        end
        if scheme == :debug
          settings.merge!(COMMON_BUILD_SETTINGS[:debug])
          settings['ONLY_ACTIVE_ARCH'] = 'YES' if platform == :osx
        else
          settings['VALIDATE_PRODUCT'] = 'YES' if platform == :ios
          settings['DEBUG_INFORMATION_FORMAT'] = "dwarf-with-dsym" if platform == :osx
        end
      end
    end
  end
end
