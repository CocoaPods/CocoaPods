require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Target
    class BuildSettings
      describe AggregateTargetSettings do
        def specs
          [fixture_spec('banana-lib/BananaLib.podspec')]
        end

        def pod_target(spec, target_definition)
          fixture_pod_target(spec, false, {}, [], Platform.new(:ios, '6.0'), [target_definition])
        end

        before do
          @target_definition = fixture_target_definition
          @specs = specs
          @specs.first.user_target_xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind', 'USE_HEADERMAP' => 'NO' } unless @specs.empty?
          @specs.first.pod_target_xcconfig = { 'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11' } unless @specs.empty?
          @pod_targets = @specs.map { |spec| pod_target(spec, @target_definition) }
          @target = fixture_aggregate_target(@pod_targets, false, { 'Release' => :release }, [], Platform.new(:ios, '6.0'), @target_definition)
          unless @specs.empty?
            @target.target_definition.whitelist_pod_for_configuration(@specs.first.name, 'Release')
          end
          @generator = AggregateTargetSettings.new(@target, 'Release')
        end

        shared 'Aggregate' do
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
            client_root = Pathname.new(@target.client_root) + 'NestedFolder'
            @target.stubs(:client_root).returns(client_root)
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
            @xcconfig = @generator.dup.generate
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

          it 'excludes the `USE_HEADERMAP` from the user project' do
            @xcconfig.to_hash['USE_HEADERMAP'].should.be.nil
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
          before do
            config.sandbox.public_headers.stubs(:search_paths).returns(['${PODS_ROOT}/Headers/Public/BananaLib'])
          end

          def specs
            [fixture_spec('banana-lib/BananaLib.podspec')]
          end

          behaves_like 'Aggregate'

          it 'configures the project to load all members that implement Objective-c classes or categories' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-ObjC'
          end

          it 'adds the sandbox public headers search paths to the xcconfig, with quotes, as header search paths' do
            expected = '$(inherited) "${PODS_ROOT}/Headers/Public/BananaLib"'
            @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == expected
          end

          describe 'with a pod target inhibiting warnings' do
            def pod_target(spec, target_definition)
              fixture_pod_target(spec, false, {}, [], Platform.new(:ios, '6.0'), [target_definition]).tap { |pt| pt.stubs(:inhibit_warnings? => true) }
            end

            it 'adds the sandbox public headers search paths to the xcconfig, with quotes, as system headers' do
              expected = "-isystem \"#{config.sandbox.public_headers.search_paths(Platform.ios).join('" -isystem "')}\""
              @xcconfig.to_hash['OTHER_CFLAGS'].should.include expected
            end
          end

          describe 'with pod targets that define modules' do
            def pod_target(spec, target_definition)
              fixture_pod_target(spec, false, {}, [], Platform.new(:ios, '6.0'), [target_definition]).tap { |pt| pt.stubs(:defines_module? => true) }
            end

            it 'adds the dependent pods module map file to OTHER_CFLAGS' do
              @pod_targets.each { |pt| pt.stubs(:defines_module? => true) }
              @xcconfig = @generator.generate
              expected = '$(inherited) -fmodule-map-file="${PODS_ROOT}/Headers/Private/BananaLib/BananaLib.modulemap"'
              @xcconfig.to_hash['OTHER_CFLAGS'].should == expected
            end

            it 'adds the dependent pods module map file to OTHER_SWIFT_FLAGS' do
              @pod_targets.each { |pt| pt.stubs(:defines_module? => true) }
              @xcconfig = @generator.generate
              expected = '$(inherited) -D COCOAPODS -Xcc -fmodule-map-file="${PODS_ROOT}/Headers/Private/BananaLib/BananaLib.modulemap"'
              @xcconfig.to_hash['OTHER_SWIFT_FLAGS'].should == expected
            end
          end

          describe 'with a scoped pod target' do
            def pod_target(spec, target_definition)
              fixture_pod_target(spec, false, {}, [], Platform.new(:ios, '6.0'), [target_definition]).scoped.first
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
            @generator = AggregateTargetSettings.new(@target, 'Debug')
            @xcconfig = @generator.dup.generate
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.be.nil
          end

          it 'does propagate framework or libraries from a non test specification to an aggregate target' do
            target_definition = stub('target_definition', :inheritance => 'complete', :abstract? => false, :podfile => Podfile.new, :platform => Platform.ios)
            spec = stub('spec', :library_specification? => true, :spec_type => :library)
            consumer = stub('consumer',
                            :libraries => ['xml2'],
                            :frameworks => ['XCTest'],
                            :weak_frameworks => [],
                            :spec => spec,
                           )
            file_accessor = stub('file_accessor',
                                 :spec => spec,
                                 :spec_consumer => consumer,
                                 :vendored_static_frameworks => [config.sandbox.root + 'StaticFramework.framework'],
                                 :vendored_static_libraries => [config.sandbox.root + 'StaticLibrary.a'],
                                 :vendored_dynamic_frameworks => [config.sandbox.root + 'VendoredFramework.framework'],
                                 :vendored_dynamic_libraries => [config.sandbox.root + 'VendoredDyld.dyld'],
                                )
            file_accessor.stubs(:vendored_frameworks => file_accessor.vendored_static_frameworks + file_accessor.vendored_dynamic_frameworks,
                                :vendored_dynamic_artifacts => file_accessor.vendored_dynamic_frameworks + file_accessor.vendored_dynamic_libraries)
            pod_target = stub('pod_target',
                              :file_accessors => [file_accessor],
                              :spec_consumers => [consumer],
                              :build_as_framework? => false,
                              :build_as_static_library? => true,
                              :build_as_static? => true,
                              :build_as_dynamic_library? => false,
                              :build_as_dynamic_framework? => false,
                              :build_as_dynamic? => false,
                              :build_as_static_framework? => false,
                              :dependent_targets => [],
                              :recursive_dependent_targets => [],
                              :sandbox => config.sandbox,
                              :should_build? => true,
                              :configuration_build_dir => 'CBD',
                              :include_in_build_config? => true,
                              :uses_swift? => false,
                              :build_product_path => 'BPP',
                              :product_basename => 'PodTarget',
                              :target_definitions => [target_definition],
                             )
            pod_target.stubs(:build_settings => PodTargetSettings.new(pod_target))
            aggregate_target = fixture_aggregate_target([pod_target])
            @generator = AggregateTargetSettings.new(aggregate_target, 'Release')
            @generator.other_ldflags.should == %w(-ObjC -l"PodTarget" -l"StaticLibrary" -l"VendoredDyld" -l"xml2" -framework "StaticFramework" -framework "VendoredFramework" -framework "XCTest")
          end
        end

        describe 'with framework' do
          def specs
            [fixture_spec('orange-framework/OrangeFramework.podspec')]
          end

          before do
            Target.any_instance.stubs(:build_type).returns(Target::BuildType.dynamic_framework)
          end

          behaves_like 'Aggregate'

          it "doesn't configure the project to load all members that implement Objective-c classes or categories" do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include '-ObjC'
          end

          describe 'with a vendored-library pod' do
            before do
              config.sandbox.public_headers.stubs(:search_paths).returns(['${PODS_ROOT}/Headers/Public/monkey'])
            end

            def specs
              [fixture_spec('monkey/monkey.podspec')]
            end

            it 'does add the framework build path to the xcconfig' do
              @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.not.be.nil
            end

            it 'configures the project to load all members that implement Objective-c classes or categories' do
              @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-ObjC'
            end

            it 'does not include framework header paths in header search paths for pods that are linked statically' do
              expected = '$(inherited) "${PODS_ROOT}/Headers/Public/monkey"'
              @xcconfig = @generator.generate
              @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == expected
            end

            it 'includes the public header paths in header search paths' do
              expected = '"${PODS_ROOT}/Headers/Public/monkey"'
              @generator.stubs(:pod_targets).returns([@pod_targets.first, pod_target(fixture_spec('orange-framework/OrangeFramework.podspec'), @target_definition)])
              @xcconfig = @generator.generate
              @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should.include expected
            end

            it 'includes the public header paths as user headers' do
              expected = '${PODS_ROOT}/Headers/Public/monkey'
              @xcconfig = @generator.generate
              @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should.include expected
            end

            it 'includes $(inherited) in the header search paths' do
              expected = '$(inherited)'
              @xcconfig = @generator.generate
              @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should.include expected
            end

            it 'includes default runpath search path list when not using frameworks but links a vendored dynamic framework' do
              @target.stubs(:build_type => Target::BuildType.static_library)
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
              fixture_pod_target(spec, false, {}, [], Platform.new(:ios, '6.0'), [@target_definition], 'iOS')
            end

            it 'adds the framework build path to the xcconfig, with quotes, as framework search paths' do
              @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '$(inherited) "${PODS_CONFIGURATION_BUILD_DIR}/BananaLib-iOS" "${PODS_CONFIGURATION_BUILD_DIR}/OrangeFramework-iOS" "${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            end

            it 'adds the framework header paths to the xcconfig, with quotes, as local headers' do
              expected = '$(inherited) "${PODS_CONFIGURATION_BUILD_DIR}/BananaLib-iOS/BananaLib.framework/Headers" "${PODS_CONFIGURATION_BUILD_DIR}/OrangeFramework-iOS/OrangeFramework.framework/Headers"'
              @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == expected
            end
          end

          describe 'with an unscoped pod target' do
            it 'adds the framework build path to the xcconfig, with quotes, as framework search paths' do
              @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '$(inherited) "${PODS_CONFIGURATION_BUILD_DIR}/OrangeFramework"'
            end

            it 'adds the framework header paths to the xcconfig, with quotes, as local headers' do
              expected = '$(inherited) "${PODS_CONFIGURATION_BUILD_DIR}/OrangeFramework/OrangeFramework.framework/Headers"'
              @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == expected
            end
          end

          describe 'with a pod target inhibiting warnings' do
            def pod_target(spec, target_definition)
              fixture_pod_target(spec, false, {}, [], Platform.new(:ios, '6.0'), [target_definition]).tap { |pt| pt.stubs(:inhibit_warnings? => true) }
            end

            it 'adds the framework build path to the xcconfig, with quotes, as system framework search paths' do
              @xcconfig.to_hash['OTHER_CFLAGS'].should.include '-iframework "${PODS_CONFIGURATION_BUILD_DIR}/OrangeFramework"'
            end

            it 'adds the framework header paths to the xcconfig, with quotes, as system headers' do
              @xcconfig.to_hash['OTHER_CFLAGS'].should.include '-isystem "${PODS_CONFIGURATION_BUILD_DIR}/OrangeFramework/OrangeFramework.framework/Headers"'
            end
          end

          it 'links the pod targets with the aggregate target' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include '-framework "OrangeFramework"'
          end

          it 'adds the COCOAPODS macro definition' do
            @xcconfig.to_hash['OTHER_SWIFT_FLAGS'].should.include '$(inherited) -D COCOAPODS'
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
            @generator.send(:target_swift_version).should == Version.new('0.1')
          end

          it 'sets EMBEDDED_CONTENT_CONTAINS_SWIFT when the target_swift_version is < 2.3' do
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @target_definition.stubs(:swift_version).returns('2.2')
            @generator.generate.to_hash['EMBEDDED_CONTENT_CONTAINS_SWIFT'].should == 'YES'
          end

          it 'does not set EMBEDDED_CONTENT_CONTAINS_SWIFT when there is no swift' do
            @generator.send(:pod_targets).each { |pt| pt.stubs(:uses_swift?).returns(false) }
            @target_definition.stubs(:swift_version).returns('2.2')
            @generator.generate.to_hash['EMBEDDED_CONTENT_CONTAINS_SWIFT'].should.be.nil
          end

          it 'does not set EMBEDDED_CONTENT_CONTAINS_SWIFT when there is swift, but the target is an extension' do
            @target.stubs(:requires_host_target?).returns(true)
            @target_definition.stubs(:swift_version).returns('2.2')
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @generator.generate.to_hash['EMBEDDED_CONTENT_CONTAINS_SWIFT'].should.be.nil
          end

          it 'sets EMBEDDED_CONTENT_CONTAINS_SWIFT when the target_swift_version is nil' do
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @target_definition.stubs(:swift_version).returns(nil)
            @generator.generate.to_hash['EMBEDDED_CONTENT_CONTAINS_SWIFT'].should == 'YES'
          end

          it 'sets ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES to YES when there is swift >= 2.3' do
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @target_definition.stubs(:swift_version).returns('2.3')
            @generator.generate.to_hash['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'].should == 'YES'
          end

          it 'does not set ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES when there is no swift' do
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(false)
            @target_definition.stubs(:swift_version).returns(nil)
            @generator.generate.to_hash['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'].nil?.should == true
          end

          it 'does not set ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES when there is swift, but the target is an extension' do
            @target.stubs(:requires_host_target?).returns(true)
            @target_definition.stubs(:swift_version).returns('2.3')
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @generator.generate.to_hash['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'].nil?.should == true
          end

          it 'does not set EMBEDDED_CONTENT_CONTAINS_SWIFT when there is swift 2.3 or higher' do
            @generator.send(:pod_targets).first.stubs(:uses_swift?).returns(true)
            @target_definition.stubs(:swift_version).returns('2.3')
            @generator.generate.to_hash.key?('EMBEDDED_CONTENT_CONTAINS_SWIFT').should == false
          end

          it 'does propagate framework or libraries from a non test specification to an aggregate target' do
            target_definition = stub('target_definition', :inheritance => 'complete', :abstract? => false, :podfile => Podfile.new, :platform => Platform.ios)
            spec = stub('spec', :library_specification? => true, :spec_type => :library)
            consumer = stub('consumer',
                            :libraries => ['xml2'],
                            :frameworks => ['XCTest'],
                            :weak_frameworks => [],
                            :spec => spec,
                           )
            file_accessor = stub('file_accessor',
                                 :spec => spec,
                                 :spec_consumer => consumer,
                                 :vendored_static_frameworks => [config.sandbox.root + 'StaticFramework.framework'],
                                 :vendored_static_libraries => [config.sandbox.root + 'StaticLibrary.a'],
                                 :vendored_dynamic_frameworks => [config.sandbox.root + 'VendoredFramework.framework'],
                                 :vendored_dynamic_libraries => [config.sandbox.root + 'VendoredDyld.dyld'],
                                )
            file_accessor.stubs(:vendored_frameworks => file_accessor.vendored_static_frameworks + file_accessor.vendored_dynamic_frameworks,
                                :vendored_dynamic_artifacts => file_accessor.vendored_dynamic_frameworks + file_accessor.vendored_dynamic_libraries,
                                :vendored_static_artifacts => file_accessor.vendored_static_frameworks + file_accessor.vendored_static_libraries)
            pod_target = stub('pod_target',
                              :file_accessors => [file_accessor],
                              :spec_consumers => [consumer],
                              :build_as_framework? => true,
                              :build_as_static? => false,
                              :build_as_static_library? => false,
                              :build_as_static_framework? => false,
                              :build_as_dynamic_library? => false,
                              :build_as_dynamic_framework? => true,
                              :build_as_dynamic? => true,
                              :dependent_targets => [],
                              :recursive_dependent_targets => [],
                              :sandbox => config.sandbox,
                              :should_build? => true,
                              :configuration_build_dir => 'CBD',
                              :include_in_build_config? => true,
                              :uses_swift? => false,
                              :build_product_path => 'BPP',
                              :product_basename => 'PodTarget',
                              :target_definitions => [target_definition],
                             )
            pod_target.stubs(:build_settings => PodTargetSettings.new(pod_target))
            aggregate_target = fixture_aggregate_target([pod_target])
            @generator = AggregateTargetSettings.new(aggregate_target, 'Release')
            @generator.other_ldflags.should == %w(-ObjC -l"VendoredDyld" -l"xml2" -framework "PodTarget" -framework "VendoredFramework" -framework "XCTest")
          end

          it 'does propagate system frameworks or system libraries from a non test specification to an aggregate target that uses static libraries' do
            target_definition = stub('target_definition', :inheritance => 'complete', :abstract? => false, :podfile => Podfile.new, :platform => Platform.ios)
            spec = stub('spec', :library_specification? => true, :spec_type => :library)
            consumer = stub('consumer',
                            :libraries => ['xml2'],
                            :frameworks => ['XCTest'],
                            :weak_frameworks => ['iAd'],
                            :spec => spec,
                           )
            file_accessor = stub('file_accessor',
                                 :spec => spec,
                                 :spec_consumer => consumer,
                                 :vendored_static_frameworks => [config.sandbox.root + 'StaticFramework.framework'],
                                 :vendored_static_libraries => [config.sandbox.root + 'StaticLibrary.a'],
                                 :vendored_dynamic_frameworks => [config.sandbox.root + 'VendoredFramework.framework'],
                                 :vendored_dynamic_libraries => [config.sandbox.root + 'VendoredDyld.dyld'],
                                )
            file_accessor.stubs(:vendored_frameworks => file_accessor.vendored_static_frameworks + file_accessor.vendored_dynamic_frameworks,
                                :vendored_dynamic_artifacts => file_accessor.vendored_dynamic_frameworks + file_accessor.vendored_dynamic_libraries,
                                :vendored_static_artifacts => file_accessor.vendored_static_frameworks + file_accessor.vendored_static_libraries)
            pod_target = stub('pod_target',
                              :file_accessors => [file_accessor],
                              :spec_consumers => [consumer],
                              :build_as_framework? => false,
                              :build_as_static_library? => true,
                              :build_as_static_framework? => false,
                              :build_as_dynamic_framework? => false,
                              :build_as_dynamic_library? => false,
                              :build_as_dynamic? => false,
                              :build_as_static? => true,
                              :dependent_targets => [],
                              :recursive_dependent_targets => [],
                              :sandbox => config.sandbox,
                              :should_build? => true,
                              :configuration_build_dir => 'CBD',
                              :include_in_build_config? => true,
                              :uses_swift? => false,
                              :build_product_path => 'BPP',
                              :product_basename => 'PodTarget',
                              :target_definitions => [target_definition],
                             )
            pod_target.stubs(:build_settings => PodTargetSettings.new(pod_target))
            aggregate_target = fixture_aggregate_target([pod_target])
            @generator = AggregateTargetSettings.new(aggregate_target, 'Release')
            @generator.other_ldflags.should == %w(-ObjC -l"PodTarget" -l"StaticLibrary" -l"VendoredDyld" -l"xml2" -framework "StaticFramework" -framework "VendoredFramework" -framework "XCTest" -weak_framework "iAd")
          end

          it 'does propagate framework or libraries from a non test specification static framework to an aggregate target' do
            target_definition = stub('target_definition', :inheritance => 'complete', :abstract? => false, :podfile => Podfile.new, :platform => Platform.ios)
            spec = stub('spec', :library_specification? => true, :spec_type => :library)
            consumer = stub('consumer',
                            :libraries => ['xml2'],
                            :frameworks => ['XCTest'],
                            :weak_frameworks => [],
                            :spec => spec,
                           )
            file_accessor = stub('file_accessor',
                                 :spec => spec,
                                 :spec_consumer => consumer,
                                 :vendored_static_frameworks => [config.sandbox.root + 'StaticFramework.framework'],
                                 :vendored_static_libraries => [config.sandbox.root + 'StaticLibrary.a'],
                                 :vendored_dynamic_frameworks => [config.sandbox.root + 'VendoredFramework.framework'],
                                 :vendored_dynamic_libraries => [config.sandbox.root + 'VendoredDyld.dyld'],
                                )
            file_accessor.stubs(:vendored_frameworks => file_accessor.vendored_static_frameworks + file_accessor.vendored_dynamic_frameworks,
                                :vendored_dynamic_artifacts => file_accessor.vendored_dynamic_frameworks + file_accessor.vendored_dynamic_libraries,
                                :vendored_static_artifacts => file_accessor.vendored_static_frameworks + file_accessor.vendored_static_libraries)
            pod_target = stub('pod_target',
                              :file_accessors => [file_accessor],
                              :spec_consumers => [consumer],
                              :build_as_framework? => true,
                              :build_as_static_framework? => true,
                              :build_as_static? => true,
                              :build_as_static_library? => false,
                              :build_as_dynamic_library? => false,
                              :build_as_dynamic? => false,
                              :build_as_dynamic_framework? => false,
                              :dependent_targets => [],
                              :recursive_dependent_targets => [],
                              :sandbox => config.sandbox,
                              :should_build? => true,
                              :configuration_build_dir => 'CBD',
                              :include_in_build_config? => true,
                              :uses_swift? => false,
                              :build_product_path => 'BPP',
                              :product_basename => 'PodTarget',
                              :target_definitions => [target_definition],
                             )
            pod_target.stubs(:build_settings => PodTargetSettings.new(pod_target))
            aggregate_target = fixture_aggregate_target([pod_target])
            @generator = AggregateTargetSettings.new(aggregate_target, 'Release')
            @generator.other_ldflags.should == %w(-ObjC -l"StaticLibrary" -l"VendoredDyld" -l"xml2" -framework "PodTarget" -framework "StaticFramework" -framework "VendoredFramework" -framework "XCTest")
          end
        end

        #-----------------------------------------------------------------------#

        describe 'serializing and deserializing' do
          before do
            @path = temporary_directory + 'sample.xcconfig'
            @generator.dup.save_as(@path)
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

          it 'does not link with vendored frameworks or libraries' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.be.nil
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
              consumer_c = mock('consumer_c', :user_target_xcconfig => { 'OTHER_CPLUSPLUSFLAGS' => '-stdlib=libc++' },
                                              :spec => mock(:spec_type => :library), :frameworks => [],
                                              :libraries => [], :weak_frameworks => [])
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
            @generator = AggregateTargetSettings.new(@blank_target, 'Release')
          end

          it 'it should not have any framework search paths' do
            @xcconfig = @generator.generate
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.be.nil
          end

          describe 'with inherited targets' do
            before do
              # It's the responsibility of the analyzer to
              # populate this when the file is loaded.
              @blank_target.search_paths_aggregate_targets.replace [@target]
            end

            it 'should include inherited search paths' do
              @xcconfig = @generator.generate
              @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '$(inherited) "${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            end

            it 'should include OTHER_LDFLAGS to link against dynamic libraries' do
              @target.pod_targets.each { |pt| pt.spec_consumers.each { |sc| sc.stubs(:frameworks => %w(UIKit), :libraries => %w(z c++)) } }

              @xcconfig = @generator.generate
              @xcconfig.to_hash['OTHER_LDFLAGS'].should == '$(inherited) -l"c++" -l"z" -framework "UIKit"'
            end

            it 'should not doubly link static libraries' do
              @specs.each { |s| s.user_target_xcconfig = nil }
              @target.pod_targets.each { |pt| pt.spec_consumers.each { |sc| sc.stubs(:frameworks => %w(UIKit), :libraries => %w(z), :vendored_libraries => %w()) } }
              @blank_target.pod_targets.replace @target.pod_targets

              @xcconfig = @generator.generate
              # -lBananaLib is not added
              @xcconfig.to_hash['OTHER_LDFLAGS'].should == '$(inherited) -l"z" -framework "UIKit"'
            end
          end
        end
      end
    end
  end
end
