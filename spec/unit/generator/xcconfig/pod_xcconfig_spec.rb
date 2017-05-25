require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  module Generator
    module XCConfig
      describe PodXCConfig do
        describe 'in general' do
          before do
            @monkey_spec = fixture_spec('monkey/monkey.podspec')
            @monkey_pod_target = fixture_pod_target(@monkey_spec)

            @spec = fixture_spec('banana-lib/BananaLib.podspec')
            @pod_target = fixture_pod_target(@spec)
            @pod_target.dependent_targets = [@monkey_pod_target]
            @pod_target.host_requires_frameworks = true

            @consumer = @pod_target.spec_consumers.first
            @podfile = @pod_target.podfile
            @generator = PodXCConfig.new(@pod_target)

            @spec.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' }
            @spec.user_target_xcconfig = { 'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11' }
            @spec.frameworks = ['QuartzCore']
            @spec.weak_frameworks = ['iAd']
            @spec.libraries = ['xml2']
            file_accessors = [Sandbox::FileAccessor.new(fixture('banana-lib'), @consumer)]

            @pod_target.stubs(:file_accessors).returns(file_accessors)

            @xcconfig = @generator.generate
          end

          it 'generates the xcconfig' do
            @xcconfig.class.should == Xcodeproj::Config
          end

          it 'includes only the pod_target_xcconfig of the specifications' do
            @xcconfig.to_hash['CLANG_CXX_LANGUAGE_STANDARD'].should.be.nil
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

          it 'includes the vendored dynamic frameworks for dependecy pods of the specification' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include('-framework "dynamic-monkey"')
          end

          it 'does not include vendored static frameworks for dependecy pods of the specification' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include('-l"monkey.a"')
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

          it 'sets the PODS_TARGET_SRCROOT build variable for non local pod' do
            @xcconfig.to_hash['PODS_TARGET_SRCROOT'].should == '${PODS_ROOT}/BananaLib'
          end

          it 'sets the PODS_TARGET_SRCROOT build variable for local pod' do
            @pod_target.sandbox.store_local_path(@pod_target.pod_name, @spec.defined_in_file)
            @xcconfig = @generator.generate
            @xcconfig.to_hash['PODS_TARGET_SRCROOT'].should == '${PODS_ROOT}/../../spec/fixtures/banana-lib/BananaLib.podspec'
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

          it 'sets the PODS_BUILD_DIR build variable' do
            @xcconfig.to_hash['PODS_BUILD_DIR'].should == '$BUILD_DIR'
          end

          it 'sets the PODS_CONFIGURATION_BUILD_DIR build variable' do
            @xcconfig.to_hash['PODS_CONFIGURATION_BUILD_DIR'].should == '$PODS_BUILD_DIR/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)'
          end

          it 'will be skipped when installing' do
            @xcconfig.to_hash['SKIP_INSTALL'].should == 'YES'
          end

          it 'sets PRODUCT_BUNDLE_IDENTIFIER' do
            @xcconfig.to_hash['PRODUCT_BUNDLE_IDENTIFIER'].should == 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
          end

          it 'saves the xcconfig' do
            path = temporary_directory + 'sample.xcconfig'
            @generator.save_as(path)
            generated = Xcodeproj::Config.new(path)
            generated.class.should == Xcodeproj::Config
          end
        end

        describe 'test xcconfig generation' do
          before do
            @monkey_spec = fixture_spec('monkey/monkey.podspec')
            @monkey_pod_target = fixture_pod_target(@monkey_spec)

            @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
            @banana_pod_target = fixture_pod_target(@banana_spec)

            @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
            @coconut_pod_target = fixture_pod_target(@coconut_spec)

            @consumer = @coconut_pod_target.spec_consumers.first
            @podfile = @coconut_pod_target.podfile

            file_accessors = [Sandbox::FileAccessor.new(fixture('coconut-lib'), @consumer)]

            @coconut_pod_target.stubs(:file_accessors).returns(file_accessors)
          end

          it 'includes other ld flags for test dependent targets' do
            @coconut_pod_target.test_dependent_targets = [@monkey_pod_target]
            generator = PodXCConfig.new(@coconut_pod_target, true)
            xcconfig = generator.generate
            xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-l"monkey" -framework "dynamic-monkey"'
          end

          it 'adds settings for test dependent targets' do
            @coconut_pod_target.test_dependent_targets = [@banana_pod_target]
            generator = PodXCConfig.new(@coconut_pod_target, true)
            xcconfig = generator.generate
            xcconfig.to_hash['LIBRARY_SEARCH_PATHS'].should == '$(inherited) "$PODS_CONFIGURATION_BUILD_DIR/BananaLib" "$PODS_CONFIGURATION_BUILD_DIR/CoconutLib" "${PODS_ROOT}/../../spec/fixtures/banana-lib"'
          end

          it 'does not include other ld flags for test dependent targets if its not a test xcconfig' do
            @coconut_pod_target.test_dependent_targets = [@monkey_pod_target]
            generator = PodXCConfig.new(@coconut_pod_target)
            xcconfig = generator.generate
            xcconfig.to_hash['LIBRARY_SEARCH_PATHS'].should.be.nil
            xcconfig.to_hash['OTHER_LDFLAGS'].should.be.nil
          end

          it 'includes default runpath search path list for test xcconfigs' do
            generator = PodXCConfig.new(@coconut_pod_target, true)
            xcconfig = generator.generate
            xcconfig.to_hash['LD_RUNPATH_SEARCH_PATHS'].should == "$(inherited) '@executable_path/Frameworks' '@loader_path/Frameworks'"
          end

          it 'includes default runpath search path list for test xcconfigs for test bundle' do
            @coconut_pod_target.stubs(:platform).returns(Platform.new(:osx, '10.10'))
            generator = PodXCConfig.new(@coconut_pod_target, true)
            xcconfig = generator.generate
            xcconfig.to_hash['LD_RUNPATH_SEARCH_PATHS'].should == "$(inherited) '@executable_path/../Frameworks' '@loader_path/../Frameworks'"
          end
        end
      end
    end
  end
end
