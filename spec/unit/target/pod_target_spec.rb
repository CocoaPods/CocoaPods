require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe PodTarget do
    before do
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      @target_definition = Podfile::TargetDefinition.new('Pods', nil)
      @target_definition.abstract = false
      @pod_target = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [spec], [@target_definition])
    end

    describe 'Meta' do
      describe '#scope_suffix' do
        it 'returns target copies per target definition, which are scoped' do
          @pod_target.scope_suffix.should.be.nil
          @pod_target.scoped.first.scope_suffix.should == 'Pods'
          @pod_target.scope_suffix.should.be.nil
        end
      end
    end

    describe 'In general' do
      it 'returns the target definitions' do
        @pod_target.target_definitions.should == [@target_definition]
      end

      it 'is initialized with empty archs' do
        @pod_target.archs.should == []
      end

      it 'returns its name' do
        @pod_target.name.should == 'BananaLib'
        @pod_target.scoped.first.name.should == 'BananaLib-Pods'
      end

      it 'returns its label' do
        @pod_target.label.should == 'BananaLib'
        @pod_target.scoped.first.label.should == 'BananaLib-Pods'
      end

      it 'returns its label' do
        @pod_target.label.should == 'BananaLib'
        @pod_target.scoped.first.label.should == 'BananaLib-Pods'
        spec_scoped_pod_target = @pod_target.scoped.first.tap { |t| t.stubs(:scope_suffix).returns('.default-GreenBanana') }
        spec_scoped_pod_target.label.should == 'BananaLib.default-GreenBanana'
      end

      it 'returns the name of its product' do
        @pod_target.product_name.should == 'libBananaLib.a'
        @pod_target.scoped.first.product_name.should == 'libBananaLib-Pods.a'
      end

      it 'returns the spec consumers for the pod targets' do
        @pod_target.spec_consumers.should.not.nil?
      end

      it 'returns the root spec' do
        @pod_target.root_spec.name.should == 'BananaLib'
      end

      it 'returns the name of the Pod' do
        @pod_target.pod_name.should == 'BananaLib'
      end

      it 'returns the name of the resources bundle target' do
        @pod_target.resources_bundle_target_label('Fruits').should == 'BananaLib-Fruits'
        @pod_target.scoped.first.resources_bundle_target_label('Fruits').should == 'BananaLib-Pods-Fruits'
      end

      it 'returns the name of the Pods on which this target depends' do
        @pod_target.dependencies.should == ['monkey']
      end

      it 'builds a pod target if there are actual source files' do
        fa = Sandbox::FileAccessor.new(nil, @pod_target)
        fa.stubs(:source_files).returns([Pathname.new('foo.m')])
        @pod_target.stubs(:file_accessors).returns([fa])

        @pod_target.should_build?.should == true
      end

      it 'does not build a pod target if there are only header files' do
        fa = Sandbox::FileAccessor.new(nil, @pod_target)
        fa.stubs(:source_files).returns([Pathname.new('foo.h')])
        @pod_target.stubs(:file_accessors).returns([fa])

        @pod_target.should_build?.should == false
      end

      it 'builds a pod target if there are no actual source files but there are script phases' do
        fa = Sandbox::FileAccessor.new(nil, @pod_target)
        fa.stubs(:source_files).returns([Pathname.new('foo.h')])
        @pod_target.stubs(:file_accessors).returns([fa])
        @pod_target.root_spec.script_phase = { :name => 'Hello World', :script => 'echo "Hello World"' }

        @pod_target.should_build?.should == true
      end
    end

    describe 'target version' do
      it 'handles when the version is more than 3 numeric parts' do
        version = Version.new('0.2.0.1')
        @pod_target.root_spec.stubs(:version).returns(version)
        @pod_target.version.should == '0.2.0'
      end

      it 'handles when the version is less than 3 numeric parts' do
        version = Version.new('0.2')
        @pod_target.root_spec.stubs(:version).returns(version)
        @pod_target.version.should == '0.2.0'
      end

      it 'handles when the version is a pre-release' do
        version = Version.new('1.0.0-beta.1')
        @pod_target.root_spec.stubs(:version).returns(version)
        @pod_target.version.should == '1.0.0'

        version = Version.new('1.0-beta.5')
        @pod_target.root_spec.stubs(:version).returns(version)
        @pod_target.version.should == '1.0.0'
      end
    end

    describe 'swift version' do
      it 'uses the swift version defined in the specification' do
        @pod_target.root_spec.stubs(:swift_version).returns('3.0')
        @target_definition.stubs(:swift_version).returns('2.3')
        @pod_target.swift_version.should == '3.0'
      end

      it 'uses the swift version defined by the target definitions if no swift version is specifed in the spec' do
        @pod_target.root_spec.stubs(:swift_version).returns(nil)
        @target_definition.stubs(:swift_version).returns('2.3')
        @pod_target.swift_version.should == '2.3'
      end
    end

    describe 'Support files' do
      it 'returns the absolute path of the xcconfig file' do
        @pod_target.xcconfig_path('Release').to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib.release.xcconfig',
        )
        @pod_target.scoped.first.xcconfig_path('Release').to_s.should.include?(
          'Pods/Target Support Files/BananaLib-Pods/BananaLib-Pods.release.xcconfig',
        )
      end

      it 'escapes the file separators in variant build configuration name in the xcconfig file' do
        @pod_target.xcconfig_path("Release#{File::SEPARATOR}1").to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib.release-1.xcconfig',
        )
        @pod_target.scoped.first.xcconfig_path("Release#{File::SEPARATOR}1").to_s.should.include?(
          'Pods/Target Support Files/BananaLib-Pods/BananaLib-Pods.release-1.xcconfig',
        )
      end

      it 'returns the absolute path of the prefix header file' do
        @pod_target.prefix_header_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib-prefix.pch',
        )
        @pod_target.scoped.first.prefix_header_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib-Pods/BananaLib-Pods-prefix.pch',
        )
      end

      it 'returns the absolute path of the bridge support file' do
        @pod_target.bridge_support_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib.bridgesupport',
        )
      end

      it 'returns the absolute path of the info plist file' do
        @pod_target.info_plist_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib-Info.plist',
        )
        @pod_target.scoped.first.info_plist_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib-Pods/BananaLib-Pods-Info.plist',
        )
      end

      it 'returns the absolute path of the dummy source file' do
        @pod_target.dummy_source_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib-dummy.m',
        )
        @pod_target.scoped.first.dummy_source_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib-Pods/BananaLib-Pods-dummy.m',
        )
      end

      it 'returns the absolute path of the public and private xcconfig files' do
        @pod_target.xcconfig_path.to_s.should.include?(
          'Pods/Target Support Files/BananaLib/BananaLib.xcconfig',
        )
      end

      it 'returns the path for the CONFIGURATION_BUILD_DIR build setting' do
        @pod_target.configuration_build_dir.should == '${PODS_CONFIGURATION_BUILD_DIR}/BananaLib'
        @pod_target.scoped.first.configuration_build_dir.should == '${PODS_CONFIGURATION_BUILD_DIR}/BananaLib-Pods'
        @pod_target.configuration_build_dir('${PODS_BUILD_DIR}').should == '${PODS_BUILD_DIR}/BananaLib'
        @pod_target.scoped.first.configuration_build_dir('${PODS_BUILD_DIR}').should == '${PODS_BUILD_DIR}/BananaLib-Pods'
      end

      it 'returns the path for the CONFIGURATION_BUILD_DIR build setting' do
        @pod_target.build_product_path.should == '${PODS_CONFIGURATION_BUILD_DIR}/BananaLib/libBananaLib.a'
        @pod_target.scoped.first.build_product_path.should == '${PODS_CONFIGURATION_BUILD_DIR}/BananaLib-Pods/libBananaLib-Pods.a'
        @pod_target.build_product_path('$BUILT_PRODUCTS_DIR').should == '$BUILT_PRODUCTS_DIR/BananaLib/libBananaLib.a'
        @pod_target.scoped.first.build_product_path('$BUILT_PRODUCTS_DIR').should == '$BUILT_PRODUCTS_DIR/BananaLib-Pods/libBananaLib-Pods.a'
      end

      it 'returns prefix header path' do
        @pod_target.prefix_header_path.to_s.should.include 'Pods/Target Support Files/BananaLib/BananaLib-prefix.pch'
      end

      describe 'non modular header search paths' do
        it 'returns the correct search paths' do
          @pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
          header_search_paths = @pod_target.header_search_paths
          header_search_paths.sort.should == [
            '${PODS_ROOT}/Headers/Private',
            '${PODS_ROOT}/Headers/Private/BananaLib',
            '${PODS_ROOT}/Headers/Public',
            '${PODS_ROOT}/Headers/Public/BananaLib',
          ]
        end

        it 'returns the correct header search paths recursively for dependent targets' do
          @pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('monkey', Platform.ios)
          monkey_spec = fixture_spec('monkey/monkey.podspec')
          monkey_pod_target = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [monkey_spec], [@target_definition])
          monkey_pod_target.stubs(:platform).returns(Platform.ios)
          @pod_target.stubs(:dependent_targets).returns([monkey_pod_target])
          header_search_paths = @pod_target.header_search_paths
          header_search_paths.sort.should == [
            '${PODS_ROOT}/Headers/Private',
            '${PODS_ROOT}/Headers/Private/BananaLib',
            '${PODS_ROOT}/Headers/Public',
            '${PODS_ROOT}/Headers/Public/BananaLib',
            '${PODS_ROOT}/Headers/Public/monkey',
          ]
        end

        it 'returns the correct header search paths recursively for dependent targets excluding platform' do
          @pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('monkey', Platform.osx)
          monkey_spec = fixture_spec('monkey/monkey.podspec')
          monkey_pod_target = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [monkey_spec], [@target_definition])
          monkey_pod_target.stubs(:platform).returns(Platform.ios)
          @pod_target.stubs(:dependent_targets).returns([monkey_pod_target])
          header_search_paths = @pod_target.header_search_paths
          # The monkey lib header search paths should not be present since they are only present in OSX.
          header_search_paths.sort.should == [
            '${PODS_ROOT}/Headers/Private',
            '${PODS_ROOT}/Headers/Private/BananaLib',
            '${PODS_ROOT}/Headers/Public',
            '${PODS_ROOT}/Headers/Public/BananaLib',
          ]
        end
      end

      describe 'modular header search paths' do
        before do
          @pod_target.stubs(:defines_module?).returns(true)
        end

        it 'uses modular header search paths when specified in the podfile' do
          @pod_target.unstub(:defines_module?)
          @pod_target.target_definitions.first.stubs(:build_pod_as_module?).with('BananaLib').returns(true)

          @pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
          header_search_paths = @pod_target.header_search_paths
          header_search_paths.sort.should == [
            '${PODS_ROOT}/Headers/Private',
            '${PODS_ROOT}/Headers/Private/BananaLib',
            '${PODS_ROOT}/Headers/Public',
          ]
        end

        it 'returns the correct header search paths' do
          @pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
          header_search_paths = @pod_target.header_search_paths
          header_search_paths.sort.should == [
            '${PODS_ROOT}/Headers/Private',
            '${PODS_ROOT}/Headers/Private/BananaLib',
            '${PODS_ROOT}/Headers/Public',
          ]
        end

        it 'returns the correct header search paths recursively for dependent targets' do
          @pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('monkey', Platform.ios)
          monkey_spec = fixture_spec('monkey/monkey.podspec')
          monkey_pod_target = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [monkey_spec], [@target_definition])
          monkey_pod_target.stubs(:platform).returns(Platform.ios)
          @pod_target.stubs(:dependent_targets).returns([monkey_pod_target])
          header_search_paths = @pod_target.header_search_paths
          header_search_paths.sort.should == [
            '${PODS_ROOT}/Headers/Private',
            '${PODS_ROOT}/Headers/Private/BananaLib',
            '${PODS_ROOT}/Headers/Public',
          ]
        end

        it 'returns header search path including header_dir from dependent' do
          @pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('monkey', Platform.ios)
          @monkey_pod_target = fixture_pod_target('monkey/monkey.podspec')
          @monkey_pod_target.stubs(:platform).returns(Platform.ios)
          @pod_target.stubs(:dependent_targets).returns([@monkey_pod_target])
          @file_accessor = @monkey_pod_target.file_accessors.first
          @file_accessor.spec_consumer.stubs(:header_dir).returns('Sub_dir')
          header_search_paths = @pod_target.header_search_paths
          header_search_paths.sort.should == [
            '${PODS_ROOT}/Headers/Private',
            '${PODS_ROOT}/Headers/Private/BananaLib',
            '${PODS_ROOT}/Headers/Public',
            '${PODS_ROOT}/Headers/Public/monkey',
          ]
        end

        it 'returns the correct header search paths recursively for dependent targets excluding platform' do
          @pod_target.build_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('BananaLib', Platform.ios)
          @pod_target.sandbox.public_headers.add_search_path('monkey', Platform.osx)
          monkey_spec = fixture_spec('monkey/monkey.podspec')
          monkey_pod_target = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [monkey_spec], [@target_definition])
          monkey_pod_target.stubs(:platform).returns(Platform.ios)
          @pod_target.stubs(:dependent_targets).returns([monkey_pod_target])
          header_search_paths = @pod_target.header_search_paths
          # The monkey lib header search paths should not be present since they are only present in OSX.
          header_search_paths.sort.should == [
            '${PODS_ROOT}/Headers/Private',
            '${PODS_ROOT}/Headers/Private/BananaLib',
            '${PODS_ROOT}/Headers/Public',
          ]
        end
      end
    end

    describe 'Product type dependent helpers' do
      describe 'With libraries' do
        before do
          @pod_target = fixture_pod_target('banana-lib/BananaLib.podspec')
        end

        it 'returns that it does not use swift' do
          @pod_target.uses_swift?.should == false
        end

        describe 'Host requires frameworks' do
          before do
            @pod_target = fixture_pod_target('banana-lib/BananaLib.podspec', true)
          end

          it 'returns the product name' do
            @pod_target.product_name.should == 'BananaLib.framework'
          end

          it 'returns the framework name' do
            @pod_target.framework_name.should == 'BananaLib.framework'
          end

          it 'returns the library name' do
            @pod_target.static_library_name.should == 'libBananaLib.a'
            @pod_target.scoped.first.static_library_name.should == 'libBananaLib-Pods.a'
          end

          it 'returns :framework as product type' do
            @pod_target.product_type.should == :framework
          end

          it 'returns that it requires being built as framework' do
            @pod_target.requires_frameworks?.should == true
          end

          it 'returns that it has no test specifications' do
            @pod_target.contains_test_specifications?.should == false
          end
        end

        describe 'Host does not requires frameworks' do
          it 'returns the product name' do
            @pod_target.product_name.should == 'libBananaLib.a'
            @pod_target.scoped.first.product_name.should == 'libBananaLib-Pods.a'
          end

          it 'returns the framework name' do
            @pod_target.framework_name.should == 'BananaLib.framework'
          end

          it 'returns the library name' do
            @pod_target.static_library_name.should == 'libBananaLib.a'
            @pod_target.scoped.first.static_library_name.should == 'libBananaLib-Pods.a'
          end

          it 'returns :static_library as product type' do
            @pod_target.product_type.should == :static_library
          end

          it 'returns that it does not require being built as framework' do
            @pod_target.requires_frameworks?.should == false
          end
        end
      end

      describe 'With frameworks' do
        before do
          @pod_target = fixture_pod_target('orange-framework/OrangeFramework.podspec', true)
        end

        it 'returns that it uses swift' do
          @pod_target.uses_swift?.should == true
        end

        it 'returns the product module name' do
          @pod_target.product_module_name.should == 'OrangeFramework'
        end

        it 'returns the product name' do
          @pod_target.product_name.should == 'OrangeFramework.framework'
        end

        it 'returns the framework name' do
          @pod_target.framework_name.should == 'OrangeFramework.framework'
        end

        it 'returns the library name' do
          @pod_target.static_library_name.should == 'libOrangeFramework.a'
          @pod_target.scoped.first.static_library_name.should == 'libOrangeFramework-Pods.a'
        end

        it 'returns :framework as product type' do
          @pod_target.product_type.should == :framework
        end

        it 'returns that it requires being built as framework' do
          @pod_target.requires_frameworks?.should == true
        end
      end

      describe 'With dependencies' do
        before do
          @pod_dependency = fixture_pod_target('orange-framework/OrangeFramework.podspec', false, {}, [], Platform.ios, @pod_target.target_definitions)
          @test_pod_dependency = fixture_pod_target('matryoshka/matryoshka.podspec', false, {}, [], Platform.ios, @pod_target.target_definitions)
          @pod_target.dependent_targets = [@pod_dependency]
          @pod_target.test_dependent_targets_by_spec_name = { @pod_dependency.name => [@test_pod_dependency] }
        end

        it 'resolves simple dependencies' do
          @pod_target.recursive_dependent_targets.should == [@pod_dependency]
        end

        it 'scopes test and non test dependencies' do
          scoped_pod_target = @pod_target.scoped
          scoped_pod_target.first.dependent_targets.count.should == 1
          scoped_pod_target.first.dependent_targets.first.name.should == 'OrangeFramework-Pods'
          scoped_pod_target.first.test_dependent_targets_by_spec_name.count.should == 1
          scoped_pod_target.first.test_dependent_targets_by_spec_name['OrangeFramework'].first.name.should == 'matryoshka-Pods'
        end

        describe 'With cyclic dependencies' do
          before do
            @pod_dependency = fixture_pod_target('orange-framework/OrangeFramework.podspec')
            @pod_dependency.dependent_targets = [@pod_target]
            @pod_target.dependent_targets = [@pod_dependency]
          end

          it 'resolves the cycle' do
            @pod_target.recursive_dependent_targets.should == [@pod_dependency]
          end
        end
      end

      describe 'script phases support' do
        before do
          @pod_target = fixture_pod_target('coconut-lib/CoconutLib.podspec')
        end

        it 'returns false if it does not contain test specifications' do
          @pod_target.contains_script_phases?.should == false
        end

        it 'returns true if it contains test specifications' do
          @pod_target.root_spec.script_phase = { :name => 'Hello World', :script => 'echo "Hello World"' }
          @pod_target.contains_script_phases?.should == true
        end
      end

      describe 'test spec support' do
        before do
          @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
          @test_spec_target_definition = Podfile::TargetDefinition.new('Pods', nil)
          @test_spec_target_definition.abstract = false
          @test_pod_target = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [@coconut_spec, *@coconut_spec.recursive_subspecs], [@test_spec_target_definition])
          @test_pod_target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
        end

        it 'returns that it has test specifications' do
          @test_pod_target.contains_test_specifications?.should == true
        end

        it 'returns supported test types' do
          @test_pod_target.supported_test_types.should == [:unit]
        end

        it 'returns test label based on test type' do
          @test_pod_target.test_target_label(:unit).should == 'CoconutLib-Unit-Tests'
        end

        it 'returns app host label based on test type' do
          @test_pod_target.app_host_label(:unit).should == 'AppHost-iOS-Unit-Tests'
        end

        it 'returns the correct product type for test type' do
          @test_pod_target.product_type_for_test_type(:unit).should == :unit_test_bundle
        end

        it 'raises for unknown test type' do
          exception = lambda { @test_pod_target.product_type_for_test_type(:weird_test_type) }.should.raise Informative
          exception.message.should.include 'Unknown test type `weird_test_type`.'
        end

        it 'returns the correct test type for product type' do
          @test_pod_target.test_type_for_product_type(:unit_test_bundle).should == :unit
        end

        it 'raises for unknown product type' do
          exception = lambda { @test_pod_target.test_type_for_product_type(:weird_product_type) }.should.raise Informative
          exception.message.should.include 'Unknown product type `weird_product_type`'
        end

        it 'returns correct app host info plist path for test type' do
          @test_pod_target.app_host_info_plist_path_for_test_type(:unit).to_s.should.include 'Pods/Target Support Files/CoconutLib/AppHost-iOS-Unit-Tests-Info.plist'
        end

        it 'returns correct copy resources script path for test unit test type' do
          @test_pod_target.copy_resources_script_path_for_test_type(:unit).to_s.should.include 'Pods/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-resources.sh'
        end

        it 'returns correct embed frameworks script path for test unit test type' do
          @test_pod_target.embed_frameworks_script_path_for_test_type(:unit).to_s.should.include 'Pods/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-frameworks.sh'
        end

        it 'returns correct prefix header path for test unit test type' do
          @test_pod_target.prefix_header_path_for_test_type(:unit).to_s.should.include 'Pods/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-prefix.pch'
        end

        it 'returns correct path for info plist for unit test type' do
          @test_pod_target.info_plist_path_for_test_type(:unit).to_s.should.include 'Pods/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-Info.plist'
        end

        it 'returns the correct resource path for test resource bundles' do
          fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
          fa.stubs(:resource_bundles).returns('TestResourceBundle' => [Pathname.new('Model.xcdatamodeld')])
          fa.stubs(:resources).returns([])
          fa.stubs(:spec).returns(stub(:test_specification? => true))
          @test_pod_target.stubs(:file_accessors).returns([fa])
          @test_pod_target.resource_paths.should == ['${PODS_CONFIGURATION_BUILD_DIR}/TestResourceBundle.bundle']
        end

        it 'includes framework paths from test specifications' do
          fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
          fa.stubs(:vendored_dynamic_artifacts).returns([config.sandbox.root + Pathname.new('Vendored/Vendored.framework')])
          fa.stubs(:spec).returns(stub(:test_specification? => false))
          test_fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
          test_fa.stubs(:vendored_dynamic_artifacts).returns([config.sandbox.root + Pathname.new('Vendored/TestVendored.framework')])
          test_fa.stubs(:spec).returns(stub(:test_specification? => true))
          @test_pod_target.stubs(:file_accessors).returns([fa, test_fa])
          @test_pod_target.stubs(:should_build?).returns(true)
          @test_pod_target.framework_paths.should == [
            { :name => 'Vendored.framework',
              :input_path => '${PODS_ROOT}/Vendored/Vendored.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/Vendored.framework' },
            { :name => 'TestVendored.framework',
              :input_path => '${PODS_ROOT}/Vendored/TestVendored.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/TestVendored.framework' },
          ]
        end

        it 'excludes framework paths from test specifications when not requested' do
          fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
          fa.stubs(:vendored_dynamic_artifacts).returns([config.sandbox.root + Pathname.new('Vendored/Vendored.framework')])
          fa.stubs(:spec).returns(stub(:test_specification? => false))
          test_fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
          test_fa.stubs(:vendored_dynamic_artifacts).returns([config.sandbox.root + Pathname.new('Vendored/TestVendored.framework')])
          test_fa.stubs(:spec).returns(stub(:test_specification? => true))
          @test_pod_target.stubs(:file_accessors).returns([fa, test_fa])
          @test_pod_target.stubs(:should_build?).returns(true)
          @test_pod_target.framework_paths(false).should == [
            { :name => 'Vendored.framework',
              :input_path => '${PODS_ROOT}/Vendored/Vendored.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/Vendored.framework' },
          ]
        end

        it 'includes resource paths from test specifications' do
          config.sandbox.stubs(:project => stub(:path => Pathname.new('ProjectPath')))
          fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
          fa.stubs(:resource_bundles).returns({})
          fa.stubs(:resources).returns([Pathname.new('Model.xcdatamodeld')])
          fa.stubs(:spec).returns(stub(:test_specification? => false))
          test_fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
          test_fa.stubs(:resource_bundles).returns({})
          test_fa.stubs(:resources).returns([Pathname.new('TestModel.xcdatamodeld')])
          test_fa.stubs(:spec).returns(stub(:test_specification? => true))
          @test_pod_target.stubs(:file_accessors).returns([fa, test_fa])
          @test_pod_target.resource_paths.should == ['${PODS_ROOT}/Model.xcdatamodeld', '${PODS_ROOT}/TestModel.xcdatamodeld']
        end

        it 'excludes resource paths from test specifications when not requested' do
          config.sandbox.stubs(:project => stub(:path => Pathname.new('ProjectPath')))
          fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
          fa.stubs(:resource_bundles).returns({})
          fa.stubs(:resources).returns([Pathname.new('Model.xcdatamodeld')])
          fa.stubs(:spec).returns(stub(:test_specification? => false))
          test_fa = Sandbox::FileAccessor.new(nil, @test_pod_target)
          test_fa.stubs(:resource_bundles).returns({})
          test_fa.stubs(:resources).returns([Pathname.new('TestModel.xcdatamodeld')])
          test_fa.stubs(:spec).returns(stub(:test_specification? => true))
          @test_pod_target.stubs(:file_accessors).returns([fa, test_fa])
          @test_pod_target.resource_paths(false).should == ['${PODS_ROOT}/Model.xcdatamodeld']
        end
      end
    end
  end
end
