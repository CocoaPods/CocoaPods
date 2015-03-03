require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  module Generator
    module XCConfig
      describe AggregateXCConfig do
        def spec
          fixture_spec('banana-lib/BananaLib.podspec')
        end

        before do
          @spec = spec
          @pod_target = fixture_pod_target(@spec)
          @consumer = @pod_target.spec_consumers.last
          @target = fixture_aggregate_target([@pod_target])
          @target.target_definition.should == @pod_target.target_definition
          @target.target_definition.whitelist_pod_for_configuration(@spec.name, 'Release')
          @podfile = @target.target_definition.podfile
          @generator = AggregateXCConfig.new(@target, 'Release')
        end

        shared 'AggregateXCConfig' do
          it 'returns the path of the pods root relative to the user project' do
            @generator.target.relative_pods_root.should == '${SRCROOT}/Pods'
          end

          #--------------------------------------------------------------------#

          before do
            @xcconfig = @generator.generate
          end

          it 'generates the xcconfig' do
            @xcconfig.class.should == Xcodeproj::Config
          end

          it 'configures the project to load all members that implement Objective-c classes or categories' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-ObjC'
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
            @xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}/Pods'
          end

          it 'adds the COCOAPODS macro definition' do
            @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should.include 'COCOAPODS=1'
          end

          it 'inherits the parent GCC_PREPROCESSOR_DEFINITIONS value' do
            @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should.include '$(inherited)'
          end

          it 'should configure OTHER_LIBTOOLFLAGS flags to include OTHER_LDFLAGS' do
            @xcconfig.to_hash['OTHER_LIBTOOLFLAGS'].should == '$(OTHER_LDFLAGS)'
          end
        end

        #-----------------------------------------------------------------------#

        describe 'if a pod target does not contain source files' do
          before do
            @pod_target.file_accessors.first.stubs(:source_files).returns([])
            @xcconfig = @generator.generate
          end

          it 'does not link with the aggregate integration library target' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include '-l"Pods-BananaLib"'
          end

          it 'does link with vendored frameworks' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-framework "Bananalib"'
          end

          it 'does link with vendored libraries' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-l"Bananalib"'
          end
        end

        #-----------------------------------------------------------------------#

        describe 'with library' do
          def spec
            fixture_spec('banana-lib/BananaLib.podspec')
          end

          behaves_like 'AggregateXCConfig'

          it 'adds the sandbox public headers search paths to the xcconfig, with quotes, as header search paths' do
            expected = "$(inherited) \"#{config.sandbox.public_headers.search_paths(:ios).join('" "')}\""
            @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == expected
          end

          it 'adds the sandbox public headers search paths to the xcconfig, with quotes, as system headers' do
            expected = "$(inherited) -isystem \"#{config.sandbox.public_headers.search_paths(:ios).join('" -isystem "')}\""
            @xcconfig.to_hash['OTHER_CFLAGS'].should == expected
          end

          it 'links the pod targets with the aggregate target' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-l"Pods-BananaLib"'
          end

          it 'does not links the pod targets with the aggregate target for non-whitelisted configuration' do
            @generator = AggregateXCConfig.new(@target, 'Debug')
            @xcconfig = @generator.generate
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include '-l"Pods-BananaLib"'
          end
        end

        describe 'with framework' do
          def spec
            fixture_spec('orange-framework/OrangeFramework.podspec')
          end

          before do
            Target.any_instance.stubs(:requires_frameworks?).returns(true)
          end

          behaves_like 'AggregateXCConfig'

          describe 'with a vendored-library pod' do
            def spec
              fixture_spec('monkey/monkey.podspec')
            end

            it 'does not add the framework build path to the xcconfig' do
              @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.be.nil?
            end
          end

          it 'sets the PODS_FRAMEWORK_BUILD_PATH build variable' do
            @xcconfig.to_hash['PODS_FRAMEWORK_BUILD_PATH'].should == '$(BUILD_DIR)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)/Pods'
          end

          it 'adds the framework build path to the xcconfig, with quotes, as framework search paths' do
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '"$PODS_FRAMEWORK_BUILD_PATH"'
          end

          it 'adds the framework header paths to the xcconfig, with quotes, as local headers' do
            expected = '$(inherited) -iquote "$PODS_FRAMEWORK_BUILD_PATH/OrangeFramework.framework/Headers"'
            @xcconfig.to_hash['OTHER_CFLAGS'].should == expected
          end

          it 'links the pod targets with the aggregate target' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-framework "OrangeFramework"'
          end

          it 'adds the COCOAPODS macro definition' do
            @xcconfig.to_hash['OTHER_SWIFT_FLAGS'].should.include '"-D" "COCOAPODS"'
          end
        end

        #-----------------------------------------------------------------------#

        describe 'serializing and deserializing' do
          before do
            @path = temporary_directory + 'sample.xcconfig'
            @generator.save_as(@path)
          end

          it 'saves the xcconfig' do
            generated = Xcodeproj::Config.new(@path)
            generated.class.should == Xcodeproj::Config
          end
        end
      end
    end
  end
end
