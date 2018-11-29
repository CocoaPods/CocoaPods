require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Target
    class BuildSettings
      describe PodTargetSettings do
        describe 'in general' do
          before do
            @monkey_spec = fixture_spec('monkey/monkey.podspec')
            @monkey_pod_target = fixture_pod_target(@monkey_spec)

            vspec = stub(:library_specification? => true, :spec_type => :library)
            consumer = stub(
              "Spec Consumer (#{vspec} iOS)",
              :spec => vspec,
              :pod_target_xcconfig => {},
              :libraries => ['xml2'],
              :frameworks => [],
              :weak_frameworks => [],
              :platform_name => :ios,
            )
            file_accessor = stub(
              'File Accessor',
              :spec => vspec,
              :spec_consumer => consumer,
              :vendored_static_frameworks => [config.sandbox.root + 'AAA/StaticFramework.framework'],
              :vendored_static_libraries => [config.sandbox.root + 'BBB/StaticLibrary.a'],
              :vendored_dynamic_frameworks => [config.sandbox.root + 'CCC/VendoredFramework.framework'],
              :vendored_dynamic_libraries => [config.sandbox.root + 'DDD/VendoredDyld.dyld'],
            )
            file_accessor.stubs(:vendored_libraries => file_accessor.vendored_static_libraries + file_accessor.vendored_dynamic_libraries,
                                :vendored_frameworks => file_accessor.vendored_static_frameworks + file_accessor.vendored_dynamic_frameworks)
            vendored_dep_target = stub(
              'Vendored Dependent Target',
              :name => 'BananaLib',
              :pod_name => 'BananaLib',
              :sandbox => config.sandbox,
              :should_build? => false,
              :build_as_framework? => true,
              :dependent_targets => [],
              :_add_recursive_dependent_targets => [],
              :recursive_dependent_targets => [],
              :file_accessors => [file_accessor],
              :spec_consumers => [consumer],
              :uses_modular_headers? => false,
              :uses_swift? => false,
              :specs => [vspec],
            )
            vendored_dep_target.stubs(:build_settings => PodTargetSettings.new(vendored_dep_target))

            @spec = fixture_spec('banana-lib/BananaLib.podspec')
            @pod_target = fixture_pod_target(@spec, true)
            @pod_target.dependent_targets = [@monkey_pod_target, vendored_dep_target]

            @consumer = @pod_target.spec_consumers.first
            @podfile = @pod_target.podfile
            @generator = PodTargetSettings.new(@pod_target)

            @spec.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '-no_compact_unwind' }
            @spec.user_target_xcconfig = { 'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11' }
            @spec.frameworks = ['QuartzCore']
            @spec.weak_frameworks = ['iAd']
            @spec.libraries = ['xml2']
            file_accessors = [Sandbox::FileAccessor.new(fixture('banana-lib'), @consumer)]

            @pod_target.stubs(:file_accessors).returns(file_accessors)

            @xcconfig = @generator.dup.generate
          end

          it 'generates the xcconfig' do
            @xcconfig.class.should == Xcodeproj::Config
          end

          it 'includes only the pod_target_xcconfig of the specifications' do
            @xcconfig.to_hash['CLANG_CXX_LANGUAGE_STANDARD'].should.be.nil
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.include('-no_compact_unwind')
          end

          it 'does not include the libraries for the specifications' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include('-l"xml2"')
          end

          it 'should not include the frameworks of the specifications' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include('-framework "QuartzCore"')
          end

          it 'does not include the weak-frameworks of the specifications' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include('-weak_framework "iAd"')
          end

          it 'does not include the vendored dynamic frameworks for dependency pods of the specification' do
            @xcconfig.to_hash['OTHER_LDFLAGS'].should.not.include('-framework "dynamic-monkey"')
          end

          it 'does not include vendored static frameworks for dependency pods of the specification' do
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

          it 'sets the framework search paths' do
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.include('spec/fixtures/banana-lib')
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.include('spec/fixtures/monkey')
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.include('${PODS_ROOT}/AAA')
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.not.include('${PODS_ROOT}/BBB')
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.include('${PODS_ROOT}/CCC')
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.not.include('${PODS_ROOT}/DDD')
          end

          it 'vendored frameworks should be added to frameworks paths if use_frameworks! isnt set' do
            @pod_target.stubs(:build_type).returns(Target::BuildType.static_library)
            @xcconfig = @generator.generate
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.include('spec/fixtures/monkey')
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.include('${PODS_ROOT}/AAA')
            @xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should.include('${PODS_ROOT}/CCC')
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
            @xcconfig.to_hash['PODS_TARGET_SRCROOT'].should == '${PODS_ROOT}/../../spec/fixtures/banana-lib'
          end

          it 'does not add root public or private header search paths to the xcconfig' do
            @xcconfig.to_hash['HEADER_SEARCH_PATHS'].should.be.nil
          end

          it 'adds the COCOAPODS macro definition' do
            expected = '$(inherited) COCOAPODS=1'
            @xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should == expected
          end

          it 'sets the relative path of the pods root for spec libraries to ${SRCROOT}' do
            @xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}'
          end

          it 'sets the PODS_BUILD_DIR build variable' do
            @xcconfig.to_hash['PODS_BUILD_DIR'].should == '${BUILD_DIR}'
          end

          it 'sets the PODS_CONFIGURATION_BUILD_DIR build variable' do
            @xcconfig.to_hash['PODS_CONFIGURATION_BUILD_DIR'].should == '${PODS_BUILD_DIR}/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)'
          end

          it 'sets the CONFIGURATION_BUILD_DIR build variable' do
            @xcconfig.to_hash['CONFIGURATION_BUILD_DIR'].should.be == '${PODS_CONFIGURATION_BUILD_DIR}/BananaLib'
          end

          it 'will be skipped when installing' do
            @xcconfig.to_hash['SKIP_INSTALL'].should == 'YES'
          end

          it 'sets PRODUCT_BUNDLE_IDENTIFIER' do
            @xcconfig.to_hash['PRODUCT_BUNDLE_IDENTIFIER'].should == 'org.cocoapods.${PRODUCT_NAME:rfc1034identifier}'
          end

          it 'does not have a module map to import if it is not built' do
            @pod_target.stubs(:should_build? => false, :build_as_framework? => false, :defines_module? => true)
            @generator.generate
            @generator.module_map_file_to_import.should.be.nil
          end

          it 'saves the xcconfig' do
            path = temporary_directory + 'sample.xcconfig'
            @generator.save_as(path)
            generated = Xcodeproj::Config.new(path)
            generated.class.should == Xcodeproj::Config
          end

          it 'does propagate framework or libraries' do
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
            pod_target = stub('pod_target',
                              :file_accessors => [file_accessor],
                              :spec_consumers => [consumer],
                              :build_as_framework? => true,
                              :build_as_static_framework? => true,
                              :build_as_dynamic_library? => false,
                              :build_as_dynamic_framework? => false,
                              :dependent_targets => [],
                              :recursive_dependent_targets => [],
                              :sandbox => config.sandbox,
                              :should_build? => true,
                             )
            pod_target.stubs(:build_settings => PodTargetSettings.new(pod_target))
            @generator.spec_consumers.each { |sc| sc.stubs(:frameworks => []) }
            @generator.stubs(:dependent_targets => [pod_target])
            @generator.other_ldflags.should.
              be == %w(-l"Bananalib" -framework "Bananalib")
          end
        end

        describe 'test xcconfig generation' do
          before do
            @monkey_spec = fixture_spec('monkey/monkey.podspec')
            @monkey_pod_target = fixture_pod_target(@monkey_spec)

            @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
            @banana_pod_target = fixture_pod_target(@banana_spec)

            @matryoshka_spec = fixture_spec('matryoshka/matryoshka.podspec')
            @matryoshka_pod_target = fixture_pod_target_with_specs([@matryoshka_spec, *@matryoshka_spec.subspecs])

            @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
            @coconut_test_spec = @coconut_spec.test_specs.first
            @coconut_pod_target = fixture_pod_target_with_specs([@coconut_spec, @coconut_test_spec])
          end

          it 'does not merge pod target xcconfig of test specifications for a non test xcconfig' do
            @coconut_spec.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => 'NON_TEST_FLAG=1' }
            @coconut_test_spec.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => 'TEST_ONLY=1' }
            generator = PodTargetSettings.new(@coconut_pod_target)
            xcconfig = generator.generate
            xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should == '$(inherited) COCOAPODS=1 NON_TEST_FLAG=1'
          end

          it 'merges pod target xcconfig settings from subspecs' do
            @matryoshka_spec.subspecs[0].pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => 'FIRST_SUBSPEC_FLAG=1' }
            @matryoshka_spec.subspecs[1].pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => 'SECOND_SUBSPEC_FLAG=1' }
            generator = PodTargetSettings.new(@matryoshka_pod_target)
            xcconfig = generator.generate
            xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should == '$(inherited) COCOAPODS=1 FIRST_SUBSPEC_FLAG=1 SECOND_SUBSPEC_FLAG=1'
          end

          it 'merges the pod target xcconfig of non test specifications for test xcconfigs' do
            @coconut_spec.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => 'NON_TEST_FLAG=1' }
            @coconut_test_spec.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => 'TEST_ONLY=1' }
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['GCC_PREPROCESSOR_DEFINITIONS'].should == '$(inherited) COCOAPODS=1 NON_TEST_FLAG=1 TEST_ONLY=1'
          end

          it 'includes correct other ld flags' do
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '$(inherited) -ObjC -l"CoconutLib"'
          end

          it 'includes correct other ld flags when requires frameworks' do
            @coconut_pod_target.stubs(:build_type => Target::BuildType.dynamic_framework)
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '$(inherited) -ObjC -framework "CoconutLib"'
          end

          it 'includes other ld flags for transitive dependent targets' do
            @coconut_pod_target.dependent_targets = [@monkey_pod_target]
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '$(inherited) -ObjC -l"CoconutLib" -l"monkey" -framework "dynamic-monkey"'
          end

          it 'includes other ld flags for test dependent targets' do
            @coconut_pod_target.test_dependent_targets_by_spec_name = { @coconut_test_spec.name => [@monkey_pod_target] }
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['OTHER_LDFLAGS'].should == '$(inherited) -ObjC -l"CoconutLib" -l"monkey" -framework "dynamic-monkey"'
          end

          it 'adds settings for test dependent targets' do
            @coconut_pod_target.test_dependent_targets_by_spec_name = { @coconut_test_spec.name => [@banana_pod_target] }
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '$(inherited) "${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            xcconfig.to_hash['LIBRARY_SEARCH_PATHS'].should == '$(inherited) "${PODS_CONFIGURATION_BUILD_DIR}/BananaLib" "${PODS_CONFIGURATION_BUILD_DIR}/CoconutLib" "${PODS_ROOT}/../../spec/fixtures/banana-lib"'
          end

          it 'adds settings for test dependent targets excluding the parents targets' do
            @coconut_pod_target.dependent_targets = [@banana_pod_target]
            @coconut_pod_target.test_dependent_targets_by_spec_name = { @coconut_test_spec.name => [@banana_pod_target] }
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '$(inherited) "${PODS_ROOT}/../../spec/fixtures/banana-lib"'
            xcconfig.to_hash['LIBRARY_SEARCH_PATHS'].should == '$(inherited) "${PODS_CONFIGURATION_BUILD_DIR}/BananaLib" "${PODS_CONFIGURATION_BUILD_DIR}/CoconutLib" "${PODS_ROOT}/../../spec/fixtures/banana-lib"'
          end

          it 'adds the developer frameworks dir when XCTest is used but not linked' do
            @banana_pod_target.spec_consumers.each { |sc| sc.stubs(:frameworks => %w(XCTest), :vendored_frameworks => []) }
            @coconut_pod_target.dependent_targets = [@banana_pod_target]

            generator = PodTargetSettings.new(@coconut_pod_target)
            xcconfig = generator.generate
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '$(inherited) "$(PLATFORM_DIR)/Developer/Library/Frameworks"'

            generator = PodTargetSettings.new(@banana_pod_target)
            xcconfig = generator.generate
            xcconfig.to_hash['FRAMEWORK_SEARCH_PATHS'].should == '$(inherited) "$(PLATFORM_DIR)/Developer/Library/Frameworks"'
          end

          it 'adds correct header search paths for dependent and test targets without modular headers' do
            @monkey_pod_target.build_headers.add_search_path('monkey', Platform.ios)
            @monkey_pod_target.sandbox.public_headers.add_search_path('monkey', Platform.ios)
            @banana_pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
            @banana_pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
            @coconut_pod_target.stubs(:uses_modular_headers?).returns(false)
            @coconut_pod_target.stubs(:defines_module?).returns(false)
            @coconut_pod_target.build_headers.add_search_path('CoconutLib', Platform.ios)
            @coconut_pod_target.sandbox.public_headers.add_search_path('CoconutLib', Platform.ios)
            @coconut_pod_target.test_dependent_targets_by_spec_name = { @coconut_test_spec.name => [@monkey_pod_target] }
            @coconut_pod_target.dependent_targets = [@banana_pod_target]
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == '$(inherited) "${PODS_ROOT}/Headers/Private"' \
              ' "${PODS_ROOT}/Headers/Private/CoconutLib"' \
              ' "${PODS_ROOT}/Headers/Public"' \
              ' "${PODS_ROOT}/Headers/Public/BananaLib"' \
              ' "${PODS_ROOT}/Headers/Public/CoconutLib"' \
              ' "${PODS_ROOT}/Headers/Public/monkey"'
          end

          it 'adds correct header search paths for dependent and test targets for non test xcconfigs without modular headers' do
            @monkey_pod_target.build_headers.add_search_path('monkey', Platform.ios)
            @monkey_pod_target.sandbox.public_headers.add_search_path('monkey', Platform.ios)
            @banana_pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
            @banana_pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
            @coconut_pod_target.stubs(:uses_modular_headers?).returns(false)
            @coconut_pod_target.stubs(:defines_module?).returns(false)
            @coconut_pod_target.build_headers.add_search_path('CoconutLib', Platform.ios)
            @coconut_pod_target.sandbox.public_headers.add_search_path('CoconutLib', Platform.ios)
            @coconut_pod_target.test_dependent_targets_by_spec_name = { @coconut_test_spec.name => [@monkey_pod_target] }
            @coconut_pod_target.dependent_targets = [@banana_pod_target]
            # This is not an test xcconfig so it should exclude header search paths for the 'monkey' pod
            generator = PodTargetSettings.new(@coconut_pod_target)
            xcconfig = generator.generate
            xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == '$(inherited) "${PODS_ROOT}/Headers/Private"' \
              ' "${PODS_ROOT}/Headers/Private/CoconutLib"' \
              ' "${PODS_ROOT}/Headers/Public"' \
              ' "${PODS_ROOT}/Headers/Public/BananaLib"' \
              ' "${PODS_ROOT}/Headers/Public/CoconutLib"' \
          end

          it 'adds correct header search paths for dependent and test targets with modular headers' do
            @monkey_pod_target.build_headers.add_search_path('monkey', Platform.ios)
            @monkey_pod_target.sandbox.public_headers.add_search_path('monkey', Platform.ios)
            @banana_pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
            @banana_pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
            @coconut_pod_target.stubs(:uses_modular_headers?).returns(true)
            @coconut_pod_target.stubs(:defines_module?).returns(true)
            @coconut_pod_target.build_headers.add_search_path('CoconutLib', Platform.ios)
            @coconut_pod_target.sandbox.public_headers.add_search_path('CoconutLib', Platform.ios)
            @coconut_pod_target.test_dependent_targets_by_spec_name = { @coconut_test_spec.name => [@monkey_pod_target] }
            @coconut_pod_target.dependent_targets = [@banana_pod_target]
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == '$(inherited) "${PODS_ROOT}/Headers/Private"' \
              ' "${PODS_ROOT}/Headers/Private/CoconutLib"' \
              ' "${PODS_ROOT}/Headers/Public"' \
          end

          it 'adds correct header search paths for dependent and test targets for non test xcconfigs with modular headers' do
            @monkey_pod_target.build_headers.add_search_path('monkey', Platform.ios)
            @monkey_pod_target.sandbox.public_headers.add_search_path('monkey', Platform.ios)
            @banana_pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
            @banana_pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
            @coconut_pod_target.stubs(:uses_modular_headers?).returns(true)
            @coconut_pod_target.stubs(:defines_module?).returns(true)
            @coconut_pod_target.build_headers.add_search_path('CoconutLib', Platform.ios)
            @coconut_pod_target.sandbox.public_headers.add_search_path('CoconutLib', Platform.ios)
            @coconut_pod_target.test_dependent_targets_by_spec_name = { @coconut_test_spec.name => [@monkey_pod_target] }
            @coconut_pod_target.dependent_targets = [@banana_pod_target]
            generator = PodTargetSettings.new(@coconut_pod_target)
            xcconfig = generator.generate
            xcconfig.to_hash['HEADER_SEARCH_PATHS'].should == '$(inherited) "${PODS_ROOT}/Headers/Private"' \
              ' "${PODS_ROOT}/Headers/Private/CoconutLib"' \
              ' "${PODS_ROOT}/Headers/Public"' \
          end

          it 'does not include other ld flags for test dependent targets if its not a test xcconfig' do
            @coconut_pod_target.test_dependent_targets_by_spec_name = { @coconut_test_spec.name => [@monkey_pod_target] }
            generator = PodTargetSettings.new(@coconut_pod_target)
            xcconfig = generator.generate
            xcconfig.to_hash['LIBRARY_SEARCH_PATHS'].should.be.nil
            xcconfig.to_hash['OTHER_LDFLAGS'].should.be.nil
          end

          it 'includes default runpath search path list for test xcconfigs' do
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['LD_RUNPATH_SEARCH_PATHS'].should == "$(inherited) '@executable_path/Frameworks' '@loader_path/Frameworks'"
          end

          it 'includes default runpath search path list for test xcconfigs for test bundle' do
            @coconut_pod_target.stubs(:platform).returns(Platform.new(:osx, '10.10'))
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['LD_RUNPATH_SEARCH_PATHS'].should == "$(inherited) '@executable_path/../Frameworks' '@loader_path/../Frameworks'"
          end

          it 'does not set configuration build dir for test xcconfigs' do
            generator = PodTargetSettings.new(@coconut_pod_target, @coconut_test_spec)
            xcconfig = generator.generate
            xcconfig.to_hash['CONFIGURATION_BUILD_DIR'].should.be.nil
          end
        end
      end
    end
  end
end
