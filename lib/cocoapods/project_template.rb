require 'fileutils'

module Pod
  module ProjectTemplate
    def self.for_platform(platform)
      project = Xcode::Project.new
      root = project.objects.add(Xcode::Project::PBXProject, {
        'attributes' => { 'LastUpgradeCheck' => '0420' },
        'compatibilityVersion' => 'Xcode 3.2',
        'developmentRegion' => 'English',
        'hasScannedForEncodings' => '0',
        'knownRegions' => ['en'],
        'mainGroup' => project.groups.new({ 'sourceTree' => '<group>' }).uuid,
        'projectDirPath' => '',
        'projectRoot' => '',
        'targets' => []
      })
      project.root_object = root
      project.main_group << project.groups.new({
        'name' => 'Pods',
        'sourceTree' => '<group>'
      })
      framework = project.files.new({
        'lastKnownFileType' => 'wrapper.framework',
        'name' => platform == :ios ? 'Foundation.framework' : 'Cocoa.framework',
        'path' => "System/Library/Frameworks/#{platform == :ios ? 'Framework' : 'Cocoa'}.framework",
        'sourceTree' => 'SDKROOT'
      })
      framework.group = project.groups.new({
        'name' => 'Frameworks',
        'sourceTree' => '<group>'
      })
      project.main_group << framework.group
      products = project.groups.new({
        'name' => 'Products',
        'sourceTree' => '<group>'
      })
      project.main_group << products
      project.root_object.products = products
      
      project.root_object.attributes['buildConfigurationList'] = project.objects.add(Xcode::Project::XCConfigurationList, {
        'defaultConfigurationIsVisible' => '0',
        'defaultConfigurationName' => 'Release',
        'buildConfigurations' => [
          project.objects.add(Xcode::Project::XCBuildConfiguration, {
            'name' => 'Debug',
            'buildSettings' => build_settings(platform, :debug)
          }),
          project.objects.add(Xcode::Project::XCBuildConfiguration, {
            'name' => 'Release',
            'buildSettings' => build_settings(platform, :release)
          })
        ].map(&:uuid)
      }).uuid
      project
    end
    
    private
    
    COMMON_BUILD_SETTINGS = {
      :all => {
        'ALWAYS_SEARCH_USER_PATHS' => 'NO',
        'GCC_C_LANGUAGE_STANDARD' => 'gnu99',
        'INSTALL_PATH' => "$(BUILT_PRODUCTS_DIR)",
        'GCC_WARN_ABOUT_MISSING_PROTOTYPES' => 'YES',
        'GCC_WARN_ABOUT_RETURN_TYPE' => 'YES',
        'GCC_WARN_UNUSED_VARIABLE' => 'YES'
      },
      :debug => {
        'GCC_DYNAMIC_NO_PIC' => 'NO',
        'GCC_PREPROCESSOR_DEFINITIONS' => ["DEBUG=1", "$(inherited)"],
        'GCC_SYMBOLS_PRIVATE_EXTERN' => 'NO',
        'GCC_OPTIMIZATION_LEVEL' => '0'
      },
      :ios => {
        'ARCHS' => "$(ARCHS_STANDARD_32_BIT)",
        'GCC_VERSION' => 'com.apple.compilers.llvmgcc42',
        'IPHONEOS_DEPLOYMENT_TARGET' => '4.3',
        'PUBLIC_HEADERS_FOLDER_PATH' => "$(TARGET_NAME)",
        'SDKROOT' => 'iphoneos'
      },
      :osx => {
        'ARCHS' => "$(ARCHS_STANDARD_64_BIT)",
        'GCC_ENABLE_OBJC_EXCEPTIONS' => 'YES',
        'GCC_WARN_64_TO_32_BIT_CONVERSION' => 'YES',
        'GCC_VERSION' => 'com.apple.compilers.llvm.clang.1_0',
        'MACOSX_DEPLOYMENT_TARGET' => '10.7',
        'SDKROOT' => 'macosx'
      }
    }

    def self.build_settings(platform, scheme)
      settings = COMMON_BUILD_SETTINGS[:all].merge(COMMON_BUILD_SETTINGS[platform])
      settings['COPY_PHASE_STRIP'] = scheme == :debug ? 'NO' : 'YES'
      if scheme == :debug
        settings.merge!(COMMON_BUILD_SETTINGS[:debug])
        settings['ONLY_ACTIVE_ARCH'] = 'YES' if platform == :osx
      else
        settings['VALIDATE_PRODUCT'] = 'YES' if platform == :ios
        settings['DEBUG_INFORMATION_FORMAT'] = "dwarf-with-dsym" if platform == :osx
      end
      settings
    end
  end
end
