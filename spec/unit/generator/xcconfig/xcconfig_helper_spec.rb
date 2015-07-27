require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  module Generator
    module XCConfig
      describe XCConfigHelper do
        before do
          @sut = XCConfigHelper
        end

        #---------------------------------------------------------------------#

        describe '::default_ld_flags' do
          it 'returns the default linker flags' do
            podfile = stub(:set_arc_compatibility_flag? => false)
            target = stub(:podfile => podfile)
            result = @sut.default_ld_flags(target)
            result.should == ''

            result = @sut.default_ld_flags(target, true)
            result.should == '-ObjC'
          end

          it 'includes the ARC compatibility flag if required by the Podfile' do
            podfile = stub(:set_arc_compatibility_flag? => true)
            spec_consumer = stub(:requires_arc? => true)
            target = stub(:podfile => podfile, :spec_consumers => [spec_consumer])
            result = @sut.default_ld_flags(target)
            result.should == '-fobjc-arc'

            result = @sut.default_ld_flags(target, true)
            result.should == '-ObjC -fobjc-arc'
          end
        end

        #---------------------------------------------------------------------#

        describe '::quote' do
          it 'quotes strings' do
            result = @sut.quote(%w(string1 string2))
            result.should == '"string1" "string2"'
          end

          it 'inserts an optional string and then the normal quoted string' do
            result = @sut.quote(%w(string1 string2), '-isystem')
            result.should == '-isystem "string1" -isystem "string2"'
          end
        end

        #---------------------------------------------------------------------#

        describe '::add_spec_build_settings_to_xcconfig' do
          it 'adds the libraries of the xcconfig' do
            xcconfig = Xcodeproj::Config.new
            consumer = stub(
              :pod_target_xcconfig => {},
              :libraries => ['xml2'],
              :frameworks => [],
              :weak_frameworks => [],
              :platform_name => :ios,
            )
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-l"xml2"'
          end

          it 'adds the frameworks of the xcconfig' do
            xcconfig = Xcodeproj::Config.new
            consumer = stub(
              :pod_target_xcconfig => {},
              :libraries => [],
              :frameworks => ['CoreAnimation'],
              :weak_frameworks => [],
              :platform_name => :ios,
            )
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-framework "CoreAnimation"'
          end

          it 'adds the weak frameworks of the xcconfig' do
            xcconfig = Xcodeproj::Config.new
            consumer = stub(
              :pod_target_xcconfig => {},
              :libraries => [],
              :frameworks => [],
              :weak_frameworks => ['iAd'],
              :platform_name => :ios,
            )
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-weak_framework "iAd"'
          end

          it 'adds the ios developer frameworks search paths if needed' do
            xcconfig = Xcodeproj::Config.new
            consumer = stub(
              :pod_target_xcconfig => {},
              :libraries => [],
              :frameworks => ['SenTestingKit'],
              :weak_frameworks => [],
              :platform_name => :ios,
            )
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.include('SDKROOT')
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.not.include('DEVELOPER_LIBRARY_DIR')
          end

          it 'adds the osx developer frameworks search paths if needed' do
            xcconfig = Xcodeproj::Config.new
            consumer = stub(
              :pod_target_xcconfig => {},
              :libraries => [],
              :frameworks => ['SenTestingKit'],
              :weak_frameworks => [],
              :platform_name => :osx,
            )
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.include('DEVELOPER_LIBRARY_DIR')
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.not.include('SDKROOT')
          end
        end

        #---------------------------------------------------------------------#

        describe '::add_framework_build_settings' do
          it 'adds the build settings of a framework to the given xcconfig' do
            framework_path = config.sandbox.root + 'Parse/Parse.framework'
            xcconfig = Xcodeproj::Config.new
            @sut.add_framework_build_settings(framework_path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['OTHER_LDFLAGS'].should == '-framework "Parse"'
            hash_config['FRAMEWORK_SEARCH_PATHS'].should == '"$(PODS_ROOT)/Parse"'
          end

          it "doesn't override existing linker flags" do
            framework_path = config.sandbox.root + 'Parse/Parse.framework'
            xcconfig = Xcodeproj::Config.new('OTHER_LDFLAGS' => '-framework CoreAnimation')
            @sut.add_framework_build_settings(framework_path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['OTHER_LDFLAGS'].should == '-framework "CoreAnimation" -framework "Parse"'
          end

          it "doesn't override existing frameworks search paths" do
            framework_path = config.sandbox.root + 'Parse/Parse.framework'
            xcconfig = Xcodeproj::Config.new('FRAMEWORK_SEARCH_PATHS' => '"path/to/frameworks"')
            @sut.add_framework_build_settings(framework_path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['FRAMEWORK_SEARCH_PATHS'].should == '"path/to/frameworks" "$(PODS_ROOT)/Parse"'
          end
        end

        #---------------------------------------------------------------------#

        describe '::add_library_build_settings' do
          it 'adds the build settings of a framework to the given xcconfig' do
            path = config.sandbox.root + 'MapBox/Proj4/libProj4.a'
            xcconfig = Xcodeproj::Config.new
            @sut.add_library_build_settings(path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['OTHER_LDFLAGS'].should == '-l"Proj4"'
            hash_config['LIBRARY_SEARCH_PATHS'].should == '"$(PODS_ROOT)/MapBox/Proj4"'
          end
        end

        #---------------------------------------------------------------------#

        describe '::add_developers_frameworks_if_needed' do
          it 'adds the developer frameworks search paths to the xcconfig if SenTestingKit has been detected' do
            xcconfig = Xcodeproj::Config.new('OTHER_LDFLAGS' => '-framework SenTestingKit')
            @sut.add_developers_frameworks_if_needed(xcconfig, :ios)
            frameworks_search_paths = xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS']
            frameworks_search_paths.should.include?('$(inherited)')
            frameworks_search_paths.should.include?('"$(SDKROOT)/Developer/Library/Frameworks"')
            frameworks_search_paths.should.not.include?('"$(DEVELOPER_LIBRARY_DIR)/Frameworks"')
          end

          it 'adds the developer frameworks search paths to the xcconfig if XCTest has been detected' do
            xcconfig = Xcodeproj::Config.new('OTHER_LDFLAGS' => '-framework XCTest')
            @sut.add_developers_frameworks_if_needed(xcconfig, :ios)
            frameworks_search_paths = xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS']
            frameworks_search_paths.should.include?('$(inherited)')
            frameworks_search_paths.should.include?('"$(SDKROOT)/Developer/Library/Frameworks"')
            frameworks_path = '"$(PLATFORM_DIR)/Developer/Library/Frameworks"'
            frameworks_search_paths.should.include?(frameworks_path)
            frameworks_search_paths.should.not.include?('"$(DEVELOPER_LIBRARY_DIR)/Frameworks"')
          end

          it "doesn't adds the developer frameworks relative to the SDK for OS X" do
            xcconfig = Xcodeproj::Config.new('OTHER_LDFLAGS' => '-framework XCTest')
            @sut.add_developers_frameworks_if_needed(xcconfig, :ios)
            frameworks_search_paths = xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS']
            frameworks_search_paths.should.include?('"$(SDKROOT)/Developer/Library/Frameworks"')

            xcconfig = Xcodeproj::Config.new('OTHER_LDFLAGS' => '-framework XCTest')
            @sut.add_developers_frameworks_if_needed(xcconfig, :osx)
            frameworks_search_paths = xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS']
            frameworks_search_paths.should.not.include?('"$(SDKROOT)/Developer/Library/Frameworks"')
          end
        end

        #---------------------------------------------------------------------#
      end
    end
  end
end
