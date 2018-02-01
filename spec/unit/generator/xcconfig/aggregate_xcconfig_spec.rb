require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  module Generator
    module XCConfig
      describe AggregateXCConfig do
        def specs
          [fixture_spec('banana-lib/BananaLib.podspec')]
        end

        def pod_target(spec, target_definition)
          fixture_pod_target(spec, [target_definition])
        end

        before do
          @target_definition = fixture_target_definition
          @specs = specs
          @specs.first.user_target_xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' } unless @specs.empty?
          @specs.first.pod_target_xcconfig = { 'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11' } unless @specs.empty?
          @pod_targets = @specs.map { |spec| pod_target(spec, @target_definition) }
          @target = fixture_aggregate_target(@pod_targets, @target_definition)
          unless @specs.empty?
            @target.target_definition.whitelist_pod_for_configuration(@specs.first.name, 'Release')
          end
          @generator = AggregateXCConfig.new(@target, 'Release')
        end

        shared 'AggregateXCConfig' do
          it 'returns the path of the pods root relative to the user project' do
            @generator.target.relative_pods_root.should == '${SRCROOT}/Pods'
          end

          it 'returns the path of the podfile directory relative to the standard user project' do
            podfile = @target.target_definition.podfile
            podfile.stubs(:defined_in_file).returns(Pathname.new(@target.client_root) + 'Podfile')
            @target.target_definition.stubs(:podfile).returns(podfile)
            @generator.target.podfile_dir_relative_path.should == '${SRCROOT}/.'
          end

          it 'returns the path of the podfile directory relative to a nested user project' do
            podfile = @target.target_definition.podfile
            podfile.stubs(:defined_in_file).returns(Pathname.new(@target.client_root) + 'Podfile')
            @target.target_definition.stubs(:podfile).returns(podfile)
            @target.client_root = Pathname.new(@target.client_root) + 'NestedFolder'
            @generator.target.podfile_dir_relative_path.should == '${SRCROOT}/..'
          end

          it 'returns the standard path if the podfile is not defined in file' do
            podfile = @target.target_definition.podfile
            podfile.stubs(:defined_in_file).returns(nil)
            @target.target_definition.stubs(:podfile).returns(podfile)
            @generator.target.podfile_dir_relative_path.should == '${PODS_ROOT}/..'
          end

          #--------------------------------------------------------------------#

          before do
            @consumer = @pod_targets.first.spec_consumers.last
            @podfile = @target.target_definition.podfile
            @xcconfig = @generator.generate
          end

          it 'generates the xcconfig' do
            @xcconfig.class.should == Xcodeproj::Config
          end

          it 'includes only the user_target_xcconfig of the specifications' do
            @xcconfig.to_hash['CLANG_CXX_LANGUAGE_STANDARD'].should.be.nil
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include('-no_compact_unwind')
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

          it 'sets the PODS_BUILD_DIR build variable' do
            @xcconfig.to_hash['PODS_BUILD_DIR'].should == '${BUILD_DIR}'
          end

          it 'sets the PODS_CONFIGURATION_BUILD_DIR build variable' do
            @xcconfig.to_hash['PODS_CONFIGURATION_BUILD_DIR'].should == '${PODS_BUILD_DIR}/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)'
          end

          it 'adds the COCOAPODS macro definition' do
            @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should.include 'COCOAPODS=1'
          end

          it 'inherits the parent GCC_PREPROCESSOR_DEFINITIONS value' do
            @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should.include '$(inherited)'
          end
        end

        #-----------------------------------------------------------------------#

        describe 'if a pod target does not contain source files' do
          before do
            @pod_targets.first.file_accessors.first.stubs(:source_files).returns([])
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
          def specs
            [fixture_spec('banana-lib/BananaLib.podspec')]
          end

          behaves_like 'AggregateXCConfig'

          it 'configures the project to load all members that implement Objective-c classes or categories' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-ObjC'
          end

          it 'adds the sandbox public headers search paths to the xcconfig, with quotes, as header search paths' do
            expected = "$(inherited) \"#{config.sandbox.public_headers.search_paths(Platform.ios).join('" "')}\""
            @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == expected
          end

          it 'adds the sandbox public headers search paths to the xcconfig, with quotes, as system headers' do
            expected = "$(inherited) -isystem \"#{config.sandbox.public_headers.search_paths(Platform.ios).join('" -isystem "')}\""
            @xcconfig.to_hash['OTHER_CFLAGS'].should == expected
          end

          it 'adds the dependent pods module map file to OTHER_CFLAGS' do
            @pod_targets.each { |pt| pt.stubs(:defines_module? => true) }
            @xcconfig = @generator.generate
            expected = "$(inherited) -fmodule-map-file=\"${PODS_ROOT}/Headers/Private/BananaLib/BananaLib.modulemap\" -isystem \"#{config.sandbox.public_headers.search_paths(Platform.ios).join('" -isystem "')}\""
            @xcconfig.to_hash['OTHER_CFLAGS'].should == expected
          end

          describe 'with a scoped pod target' do
            def pod_target(spec, target_definition)
              fixture_pod_target(spec, [target_definition]).scoped.first
            end

            it 'links the pod targets with the aggregate target' do
              @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-l"BananaLib-Pods"'
            end
          end

          describe 'with an unscoped pod target' do
            it 'links the pod targets with the aggregate target' do
              @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-l"BananaLib"'
            end
          end

          it 'does not links the pod targets with the aggregate target for non-whitelisted configuration' do
            @generator = AggregateXCConfig.new(@target, 'Debug')
            @xcconfig = @generator.generate
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include '-l"Pods-BananaLib"'
          end
        end

        describe 'with framework' do
          def specs
            [fixture_spec('orange-framework/OrangeFramework.podspec')]
          end

          before do
            Target.any_instance.stubs(:requires_frameworks?).returns(true)
          end

          behaves_like 'AggregateXCConfig'

          it "doesn't configure the project to load all members that implement Objective-c classes or categories" do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include '-ObjC'
          end

          describe 'with a vendored-library pod' do
            def specs
              [fixture_spec('monkey/monkey.podspec')]
            end

            it 'does add the framework build path to the xcconfig' do
              @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.not.be.nil
            end

            it 'configures the project to load all members that implement Objective-c classes or categories' do
              @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-ObjC'
            end

            it 'does not include framework header paths as local headers for pods that are linked statically' do
              monkey_headers = '-iquote "${PODS_CONFIGURATION_BUILD_DIR}/monkey.framework/Headers"'
              @xcconfig.to_hash['OTHER_CFLAGS'].should.not.include monkey_headers
            end

            it 'includes the public header paths as system headers' do
              expected = '$(inherited) -iquote "${PODS_CONFIGURATION_BUILD_DIR}/OrangeFramework/OrangeFramework.framework/Headers" -isystem "${PODS_ROOT}/Headers/Public"'
              @generator.stubs(:pod_targets).returns([@pod_targets.first, pod_target(fixture_spec('orange-framework/OrangeFramework.podspec'), @target_definition)])
              @xcconfig = @generator.generate
              @xcconfig.to_hash['OTHER_CFLAGS'].should == expected
            end

            it 'includes the public header paths as user headers' do
              expected = '${PODS_ROOT}/Headers/Public'
              @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should.include expected
            end

            it 'includes $(inherited) in the header search paths' do
              expected = '$(inherited)'
              @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should.include expected
            end

            it 'includes default runpath search path list when not using frameworks but links a vendored dynamic framework' do
              @target.stubs(:requires_frameworks?).returns(false)
              @generator.generate.to_hash['LD_RUNPATH_SEARCH_PATHS'].should == "$(inherited) '@executable_path/Frameworks' '@loader_path/Frameworks'"
            end
          end

          describe 'with a scoped pod target' do
            def specs
              [
                fixture_spec('banana-lib/BananaLib.podspec'),
                fixture_spec('orange-framework/OrangeFramework.podspec'),
              ]
            end

            def pod_target(spec, target_definition)
              target_definition = fixture_target_definition(spec.name)
              target_definition.stubs(:parent).returns(@target_definition.podfile)
              fixture_pod_target(spec, [target_definition, @target_definition].uniq).tap do |pod_target|
                pod_target.stubs(:scope_suffix).returns('iOS')
              end
            end

            it 'adds the framework build path to the xcconfig, with quotes, as framework search paths' do
              @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '$(inherited) "${PODS_CONFIGURATION_BUILD_DIR}/BananaLib-iOS" "${PODS_CONFIGURATION_BUILD_DIR}/OrangeFramework-iOS"'
            end

            it 'adds the framework header paths to the xcconfig, with quotes, as local headers' do
              expected = '$(inherited) -iquote "${PODS_CONFIGURATION_BUILD_DIR}/BananaLib-iOS/BananaLib.framework/Headers" -iquote "${PODS_CONFIGURATION_BUILD_DIR}/OrangeFramework-iOS/OrangeFramework.framework/Headers"'
              @xcconfig.to_hash['OTHER_CFLAGS'].should == expected
            end
          end

          describe 'with an unscoped pod target' do
            it 'adds the framework build path to the xcconfig, with quotes, as framework search paths' do
              @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '$(inherited) "${PODS_CONFIGURATION_BUILD_DIR}/OrangeFramework"'
            end

            it 'adds the framework header paths to the xcconfig, with quotes, as local headers' do
              expected = '$(inherited) -iquote "${PODS_CONFIGURATION_BUILD_DIR}/OrangeFramework/OrangeFramework.framework/Headers"'
              @xcconfig.to_hash['OTHER_CFLAGS'].should == expected
            end
          end

          it 'links the pod targets with the aggregate target' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-framework "OrangeFramework"'
          end

          it 'adds the COCOAPODS macro definition' do
            @xcconfig.to_hash['OTHER_SWIFT_FLAGS'].should.include '$(inherited) "-D" "COCOAPODS"'
          end

          it 'includes default runpath search path list for a non host target' do
            @target.stubs(:requires_host_target?).returns(false)
            @generator.generate.to_hash['LD_RUNPATH_SEARCH_PATHS'].should == "$(inherited) '@executable_path/Frameworks' '@loader_path/Frameworks'"
          end

          it 'includes default runpath search path list for a host target' do
            @target.stubs(:requires_host_target?).returns(true)
            @generator.generate.to_hash['LD_RUNPATH_SEARCH_PATHS'].should == "$(inherited) '@executable_path/Frameworks' '@loader_path/Frameworks' '@executable_path/../../Frameworks'"
          end

          it 'includes correct default runpath search path list for OSX unit test bundle user target' do
            @target.stubs(:platform).returns(Platform.new(:osx, '10.10'))
            mock_user_target = mock('usertarget', :symbol_type => :unit_test_bundle)
            @target.stubs(:user_targets).returns([mock_user_target])
            @generator.generate.to_hash['LD_RUNPATH_SEARCH_PATHS'].should == "$(inherited) '@executable_path/../Frameworks' '@loader_path/../Frameworks'"
          end

          it 'includes correct default runpath search path list for OSX application user target' do
            @target.stubs(:platform).returns(Platform.new(:osx, '10.10'))
            mock_user_target = mock('usertarget', :symbol_type => :application)
            @target.stubs(:user_targets).returns([mock_user_target])
            @generator.generate.to_hash['LD_RUNPATH_SEARCH_PATHS'].should == "$(inherited) '@executable_path/../Frameworks' '@loader_path/Frameworks'"
          end

          it 'uses the target definition swift version' do
            @target_definition.stubs(:swift_version).returns('0.1')
            @generator.send(:target_swift_version).should == '0.1'
          end

          it 'sets EMBEDDED_CONTENT_CONTAINS_SWIFT when the target_swift_version is < 2.3' do
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @generator.stubs(:target_swift_version).returns('2.2')
            @generator.generate.to_hash['EMBEDDED_CONTENT_CONTAINS_SWIFT'].should == 'YES'
          end

          it 'does not set EMBEDDED_CONTENT_CONTAINS_SWIFT when there is no swift' do
            @generator.send(:pod_targets).each { |pt| pt.stubs(:uses_swift?).returns(false) }
            @generator.stubs(:target_swift_version).returns('2.2')
            @generator.generate.to_hash['EMBEDDED_CONTENT_CONTAINS_SWIFT'].should.be.nil
          end

          it 'does not set EMBEDDED_CONTENT_CONTAINS_SWIFT when there is swift, but the target is an extension' do
            @target.stubs(:requires_host_target?).returns(true)
            @generator.stubs(:target_swift_version).returns('2.2')
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @generator.generate.to_hash['EMBEDDED_CONTENT_CONTAINS_SWIFT'].should.be.nil
          end

          it 'sets EMBEDDED_CONTENT_CONTAINS_SWIFT when the target_swift_version is nil' do
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @generator.stubs(:target_swift_version).returns(nil)
            @generator.generate.to_hash['EMBEDDED_CONTENT_CONTAINS_SWIFT'].should == 'YES'
          end

          it 'sets ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES to YES when there is swift >= 2.3' do
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @generator.stubs(:target_swift_version).returns('2.3')
            @generator.generate.to_hash['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'].should == 'YES'
          end

          it 'does not set ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES when there is no swift' do
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(false)
            @generator.stubs(:target_swift_version).returns(nil)
            @generator.generate.to_hash['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'].nil?.should == true
          end

          it 'does not set ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES when there is swift, but the target is an extension' do
            @target.stubs(:requires_host_target?).returns(true)
            @generator.stubs(:target_swift_version).returns('2.3')
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @generator.generate.to_hash['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'].nil?.should == true
          end

          it 'does not set EMBEDDED_CONTENT_CONTAINS_SWIFT when there is swift 2.3 or higher' do
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @generator.stubs(:target_swift_version).returns('2.3')
            @generator.generate.to_hash.key?('EMBEDDED_CONTENT_CONTAINS_SWIFT').should == false
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

        #-----------------------------------------------------------------------#

        describe 'when no pods are whitelisted for the given configuration' do
          before do
            @generator.stubs(:configuration_name).returns('.invalid')
            @xcconfig = @generator.generate
          end

          it 'does not link with vendored frameworks' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include '-framework "Bananalib"'
          end

          it 'does not link with vendored libraries' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include '-l"Bananalib"'
          end
        end

        #-----------------------------------------------------------------------#

        describe 'with multiple pod targets with user_target_xcconfigs' do
          def specs
            [
              fixture_spec('banana-lib/BananaLib.podspec'),
              fixture_spec('orange-framework/OrangeFramework.podspec'),
            ]
          end

          before do
            @consumer_a = @pod_targets[0].spec_consumers.last
            @consumer_b = @pod_targets[1].spec_consumers.last
          end

          describe 'with boolean build settings' do
            it 'does not warn if the values are equal' do
              @consumer_a.stubs(:user_target_xcconfig).returns('ENABLE_HEADER_DEPENDENCIES' => 'YES')
              @consumer_b.stubs(:user_target_xcconfig).returns('ENABLE_HEADER_DEPENDENCIES' => 'YES')
              @xcconfig = @generator.generate
              @xcconfig.to_hash['ENABLE_HEADER_DEPENDENCIES'].should == 'YES'
            end

            it 'warns if the values differ' do
              @consumer_a.stubs(:user_target_xcconfig).returns('ENABLE_HEADER_DEPENDENCIES' => 'YES')
              @consumer_b.stubs(:user_target_xcconfig).returns('ENABLE_HEADER_DEPENDENCIES' => 'NO')
              @xcconfig = @generator.generate
              UI.warnings.should.include 'Can\'t merge user_target_xcconfig for pod targets: ' \
                '["BananaLib", "OrangeFramework"]. Boolean build setting '\
                'ENABLE_HEADER_DEPENDENCIES has different values.'
            end

            it 'make sure "no" or "yes" substring doesnt get treated as boolean' do
              @consumer_a.stubs(:user_target_xcconfig).returns('GCC_PREPROCESSOR_DEFINITIONS' => '-DNOWAY')
              @consumer_b.stubs(:user_target_xcconfig).returns('GCC_PREPROCESSOR_DEFINITIONS' => '-DYESWAY')
              @xcconfig = @generator.generate
              @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should == '$(inherited) COCOAPODS=1 -DNOWAY -DYESWAY'
            end
          end

          describe 'with list build settings' do
            it 'only adds the value once if the values are equal' do
              @consumer_a.stubs(:user_target_xcconfig).returns('OTHER_CPLUSPLUSFLAGS' => '-std=c++1y')
              @consumer_b.stubs(:user_target_xcconfig).returns('OTHER_CPLUSPLUSFLAGS' => '-std=c++1y')
              @xcconfig = @generator.generate
              @xcconfig.to_hash['OTHER_CPLUSPLUSFLAGS'].should == '-std=c++1y'
            end

            it 'adds both values if the values differ' do
              @consumer_a.stubs(:user_target_xcconfig).returns('OTHER_CPLUSPLUSFLAGS' => '-std=c++1y')
              @consumer_b.stubs(:user_target_xcconfig).returns('OTHER_CPLUSPLUSFLAGS' => '-stdlib=libc++')
              @xcconfig = @generator.generate
              @xcconfig.to_hash['OTHER_CPLUSPLUSFLAGS'].should == '-std=c++1y -stdlib=libc++'
            end

            it 'adds values from all subspecs' do
              @consumer_b.stubs(:user_target_xcconfig).returns('OTHER_CPLUSPLUSFLAGS' => '-std=c++1y')
              consumer_c = mock(:user_target_xcconfig => { 'OTHER_CPLUSPLUSFLAGS' => '-stdlib=libc++' }, :script_phases => [])
              @pod_targets[1].stubs(:spec_consumers).returns([@consumer_b, consumer_c])
              @xcconfig = @generator.generate
              @xcconfig.to_hash['OTHER_CPLUSPLUSFLAGS'].should == '-std=c++1y -stdlib=libc++'
            end
          end

          describe 'with singular build settings' do
            it 'does not warn if the values are equal' do
              @consumer_a.stubs(:user_target_xcconfig).returns('STRIP_STYLE' => 'non-global')
              @consumer_b.stubs(:user_target_xcconfig).returns('STRIP_STYLE' => 'non-global')
              @xcconfig = @generator.generate
              @xcconfig.to_hash['STRIP_STYLE'].should == 'non-global'
            end

            it 'does warn if the values differ' do
              @consumer_a.stubs(:user_target_xcconfig).returns('STRIP_STYLE' => 'non-global')
              @consumer_b.stubs(:user_target_xcconfig).returns('STRIP_STYLE' => 'all')
              @xcconfig = @generator.generate
              UI.warnings.should.include 'Can\'t merge user_target_xcconfig for pod targets: ' \
                '["BananaLib", "OrangeFramework"]. Singular build setting '\
                'STRIP_STYLE has different values.'
            end
          end
        end

        describe 'an empty pod target' do
          before do
            @blank_target = fixture_aggregate_target
            @generator = AggregateXCConfig.new(@blank_target, 'Release')
          end

          it 'it should not have any framework search paths' do
            @xcconfig = @generator.generate
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.be.nil
          end

          describe 'with inherited targets' do
            it 'should include inherited search paths' do
              # It's the responsibility of the analyzer to
              # populate this when the file is loaded.
              @blank_target.search_paths_aggregate_targets = [@target]
              @xcconfig = @generator.generate
              @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.not.be.nil
            end
          end
        end
      end
    end
  end
end
