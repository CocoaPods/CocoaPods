require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  module Generator
    module XCConfig
      describe PodXCConfig do
        describe 'in general' do
          before do
            @spec = fixture_spec('banana-lib/BananaLib.podspec')
            @pod_target = fixture_pod_target(@spec)
            @consumer = @pod_target.spec_consumers.first
            @podfile = @pod_target.podfile
            @generator = PodXCConfig.new(@pod_target)

            @spec.xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' }
            @spec.frameworks = ['QuartzCore']
            @spec.weak_frameworks = ['iAd']
            @spec.libraries = ['xml2']
            file_accessors = [Sandbox::FileAccessor.new(fixture('banana-lib'), @consumer)]
            # vendored_framework_paths = [config.sandbox.root + 'BananaLib/BananaLib.framework']
            # Sandbox::FileAccessor.any_instance.stubs(:vendored_frameworks).returns(vendored_framework_paths)

            @pod_target.stubs(:file_accessors).returns(file_accessors)

            @xcconfig = @generator.generate
          end

          it 'generates the xcconfig' do
            @xcconfig.class.should == Xcodeproj::Config
          end

          it 'includes the xcconfig of the specifications' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include('-no_compact_unwind')
          end

          it 'includes the libraries for the specifications' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include('-l"xml2"')
          end

          it 'includes the frameworks of the specifications' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include('-framework "QuartzCore"')
          end

          it 'includes the weak-frameworks of the specifications' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include('-weak_framework "iAd"')
          end

          it 'includes the developer frameworks search paths when SenTestingKit is detected' do
            @spec.xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' }
            @spec.frameworks = ['SenTestingKit']
            xcconfig = @generator.generate
            framework_search_paths = xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS']
            framework_search_paths.should.include('$(SDKROOT)/Developer')
          end

          it 'does not configure the project to load all members that implement Objective-c classes or categories from the static library' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include '-ObjC'
          end

          it 'does not add the -fobjc-arc to OTHER_LDFLAGS by default as Xcode 4.3.2 does not support it' do
            @consumer.stubs(:requires_arc?).returns(true)
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include('-fobjc-arc')
          end

          it 'adds the -fobjc-arc to OTHER_LDFLAGS if any pods require arc and the podfile explicitly requires it' do
            @podfile.stubs(:set_arc_compatibility_flag?).returns(true)
            @consumer.stubs(:requires_arc?).returns(true)
            @xcconfig = @generator.generate
            @xcconfig.to_hash['OTHER_LDFLAGS'].split(' ').should.include('-fobjc-arc')
          end

          it 'sets the PODS_ROOT build variable' do
            @xcconfig.to_hash['PODS_ROOT'].should.not.nil?
          end

          it 'adds the library build headers and public headers search paths to the xcconfig, with quotes' do
            private_headers = "\"#{@pod_target.build_headers.search_paths(:ios).join('" "')}\""
            public_headers = "\"#{config.sandbox.public_headers.search_paths(:ios).join('" "')}\""
            @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should.include private_headers
            @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should.include public_headers
          end

          it 'adds the COCOAPODS macro definition' do
            expected = '$(inherited) COCOAPODS=1'
            @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should == expected
          end

          it 'sets the relative path of the pods root for spec libraries to ${SRCROOT}' do
            @xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}'
          end

          it 'will be skipped when installing' do
            @xcconfig.to_hash['SKIP_INSTALL'].should == 'YES'
          end

          it 'saves the xcconfig' do
            path = temporary_directory + 'sample.xcconfig'
            @generator.save_as(path)
            generated = Xcodeproj::Config.new(path)
            generated.class.should == Xcodeproj::Config
          end
        end
      end
    end
  end
end
