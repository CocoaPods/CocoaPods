require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  module Generator
    module XCConfig
      describe PrivatePodXCConfig do

        describe 'in general' do
          before do
            @spec = fixture_spec('banana-lib/BananaLib.podspec')
            @consumer = @spec.consumer(:ios)
            target_definition = Podfile::TargetDefinition.new('Pods', nil)
            @pod_target = PodTarget.new([@spec], target_definition, config.sandbox)
            @pod_target.stubs(:platform).returns(:ios)
            public_xcconfig = Xcodeproj::Config.new('OTHER_LDFLAGS' => '-framework SystemConfiguration')
            @generator = PrivatePodXCConfig.new(@pod_target, public_xcconfig)
            @podfile = Podfile.new
            @pod_target.target_definition.stubs(:podfile).returns(@podfile)
            @xcconfig = @generator.generate
          end

          it 'generates the xcconfig' do
            @xcconfig.class.should == Xcodeproj::Config
          end

          it 'configures the project to load all members that implement Objective-c classes or categories from the static library' do
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

          it 'adds the pod namespaced configuration items' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include("${#{@pod_target.xcconfig_prefix}OTHER_LDFLAGS}")
          end

          it 'sets the relative path of the pods root for spec libraries to ${SRCROOT}' do
            @xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}'
          end

          it 'saves the xcconfig' do
            path = temporary_directory + 'sample.xcconfig'
            @generator.save_as(path)
            generated = Xcodeproj::Config.new(path)
            generated.class.should == Xcodeproj::Config
          end

        end

        #-------------------------------------------------------------------------#

        describe 'Private Helpers' do

          before do
            @sut = PrivatePodXCConfig.new(stub, stub)
          end

          #----------------------------------------#

          describe '#add_xcconfig_namespaced_keys' do

            it 'appends to the values of the keys of the destination the value of the keys of the source' do
              source_config = { 'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/MyPod' }
              destination_config = { 'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/BuildHeaders' }
              result = @sut.send(:add_xcconfig_namespaced_keys, source_config, destination_config, 'PREFIX_')
              result.should == { 'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/BuildHeaders ${PREFIX_HEADER_SEARCH_PATHS}' }
            end

            it 'uses the key of the destination xcconfig if not present in the source' do
              source_config = {}
              destination_config = { 'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/BuildHeaders' }
              result = @sut.send(:add_xcconfig_namespaced_keys, source_config, destination_config, 'PREFIX_')
              result.should == { 'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/BuildHeaders' }
            end

            it 'preserves any value of the source not present in the destination' do
              source_config = { 'EXCLUDED_SOURCE_FILE_NAMES' => 'ZBarReaderViewImpl_Simulator.m' }
              destination_config = {}
              result = @sut.send(:add_xcconfig_namespaced_keys, source_config, destination_config, 'PREFIX_')
              result.should == { 'EXCLUDED_SOURCE_FILE_NAMES' => '${PREFIX_EXCLUDED_SOURCE_FILE_NAMES}' }
            end

          end

          #----------------------------------------#

          describe '#conditional_less_key' do

            it 'returns the key without the xcconfig conditional syntax if present' do
              result = @sut.send(:conditional_less_key, 'EXCLUDED_SOURCE_FILE_NAMES[sdk=iphoneos*][arch=*]')
              result.should == 'EXCLUDED_SOURCE_FILE_NAMES'
            end

            it 'returns the key as it is if no conditional syntax is present' do
              result = @sut.send(:conditional_less_key, 'EXCLUDED_SOURCE_FILE_NAMES')
              result.should == 'EXCLUDED_SOURCE_FILE_NAMES'
            end

          end

        end

        #-------------------------------------------------------------------------#

      end
    end
  end
end
