require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  module Generator
    module XCConfig
      describe XCConfigHelper do

        before do
          @sut = XCConfigHelper
        end

        #---------------------------------------------------------------------#

        describe "::default_ld_flags" do
          it "returns the default linker flags" do
            podfile = stub( :set_arc_compatibility_flag? => false )
            target_definition = stub( :podfile => podfile )
            target = stub( :target_definition => target_definition )
            result = @sut.default_ld_flags(target)
            result.should == '-ObjC'
          end

          it "includes the ARC compatibility flag if required by the Podfile" do
            podfile = stub( :set_arc_compatibility_flag? => true )
            target_definition = stub( :podfile => podfile )
            spec_consumer = stub( :requires_arc? => true )
            target = stub( :target_definition => target_definition,  :spec_consumers => [spec_consumer] )
            result = @sut.default_ld_flags(target)
            result.should == '-ObjC -fobjc-arc'
          end
        end

        #---------------------------------------------------------------------#

        describe "::quote" do
          it "quotes strings" do
            result = @sut.quote(['string1', 'string2'])
            result.should == '"string1" "string2"'
          end
        end

        #---------------------------------------------------------------------#

        describe "::add_spec_build_settings_to_xcconfig" do
          it "adds the build settings of the consumer" do
            xcconfig = Xcodeproj::Config.new
            consumer = stub({
              :xcconfig => { 'OTHER_LDFLAGS' => '-framework SenTestingKit' },
              :libraries => [],
              :frameworks => [],
              :weak_frameworks => [],
            })
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-framework SenTestingKit'
          end

          it "adds the libraries of the xcconfig" do
            xcconfig = Xcodeproj::Config.new
            consumer = stub({
              :xcconfig => {},
              :libraries => ['xml2'],
              :frameworks => [],
              :weak_frameworks => [],
            })
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-lxml2'
          end

          it "adds the frameworks of the xcconfig" do
            xcconfig = Xcodeproj::Config.new
            consumer = stub({
              :xcconfig => {},
              :libraries => [],
              :frameworks => ['CoreAnimation'],
              :weak_frameworks => [],
            })
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-framework CoreAnimation'
          end

          it "adds the weak frameworks of the xcconfig" do
            xcconfig = Xcodeproj::Config.new
            consumer = stub({
              :xcconfig => {},
              :libraries => [],
              :frameworks => [],
              :weak_frameworks => ['iAd'],
            })
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '-weak_framework iAd'
          end

          it "adds the developer frameworks search paths if needed" do
            xcconfig = Xcodeproj::Config.new
            consumer = stub({
              :xcconfig => {},
              :libraries => [],
              :frameworks => ['SenTestingKit'],
              :weak_frameworks => [],
            })
            @sut.add_spec_build_settings_to_xcconfig(consumer, xcconfig)
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.include('DEVELOPER_LIBRARY_DIR')
          end
        end

        #---------------------------------------------------------------------#

        describe "::add_framework_build_settings" do
          it "adds the build settings of a framework to the given xcconfig" do
            framework_path = config.sandbox.root + 'Parse/Parse.framework'
            xcconfig = Xcodeproj::Config.new
            @sut.add_framework_build_settings(framework_path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['OTHER_LDFLAGS'].should == "-framework Parse"
            hash_config['FRAMEWORK_SEARCH_PATHS'].should == '"$(PODS_ROOT)/Parse"'
          end

          it "doesn't ovverides exiting linker flags" do
            framework_path = config.sandbox.root + 'Parse/Parse.framework'
            xcconfig = Xcodeproj::Config.new( { 'OTHER_LDFLAGS' => '-framework CoreAnimation' } )
            @sut.add_framework_build_settings(framework_path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['OTHER_LDFLAGS'].should == "-framework CoreAnimation -framework Parse"
          end

          it "doesn't ovverides exiting frameworks search paths" do
            framework_path = config.sandbox.root + 'Parse/Parse.framework'
            xcconfig = Xcodeproj::Config.new( { 'FRAMEWORK_SEARCH_PATHS' => '"path/to/frameworks"' } )
            @sut.add_framework_build_settings(framework_path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['FRAMEWORK_SEARCH_PATHS'].should == '"path/to/frameworks" "$(PODS_ROOT)/Parse"'
          end
        end

        #---------------------------------------------------------------------#

        describe "::add_library_build_settings" do
          it "adds the build settings of a framework to the given xcconfig" do
            path = config.sandbox.root + 'MapBox/Proj4/libProj4.a'
            xcconfig = Xcodeproj::Config.new
            @sut.add_library_build_settings(path, xcconfig, config.sandbox.root)
            hash_config = xcconfig.to_hash
            hash_config['OTHER_LDFLAGS'].should == "-lProj4"
            hash_config['LIBRARY_SEARCH_PATHS'].should == '"$(PODS_ROOT)/MapBox/Proj4"'
          end
        end

        #---------------------------------------------------------------------#

        describe "::add_framework_build_settings" do
          it "adds the developer frameworks search paths to the xcconfig if SenTestingKit has been detected" do
            xcconfig = Xcodeproj::Config.new({'OTHER_LDFLAGS' => '-framework SenTestingKit'})
            @sut.add_developers_frameworks_if_needed(xcconfig)
            frameworks_search_paths = xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS']
            frameworks_search_paths.should.include?('$(inherited)')
            frameworks_search_paths.should.include?('"$(SDKROOT)/Developer/Library/Frameworks"')
            frameworks_search_paths.should.include?('"$(DEVELOPER_LIBRARY_DIR)/Frameworks"')
          end
        end

        #---------------------------------------------------------------------#

      end
    end
  end
end
