require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe PodTarget do
    before do
      @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
      @target_definition = fixture_target_definition
      @pod_target = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [@banana_spec], [@target_definition])
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
        fa = Sandbox::FileAccessor.new(nil, @banana_spec.consumer(Platform.ios))
        fa.stubs(:source_files).returns([Pathname.new('foo.m')])
        @pod_target.stubs(:file_accessors).returns([fa])

        @pod_target.should_build?.should == true
      end

      it 'does not build a pod target if there are only header files' do
        fa = Sandbox::FileAccessor.new(nil, @banana_spec.consumer(Platform.ios))
        fa.stubs(:source_files).returns([Pathname.new('foo.h')])
        @pod_target.stubs(:file_accessors).returns([fa])

        @pod_target.should_build?.should == false
      end

      it 'does not build a pod target if there are no actual source files but there are script phases' do
        fa = Sandbox::FileAccessor.new(nil, @banana_spec.consumer(Platform.ios))
        fa.stubs(:source_files).returns([Pathname.new('foo.h')])
        @pod_target.stubs(:file_accessors).returns([fa])
        @pod_target.root_spec.script_phase = { :name => 'Hello World', :script => 'echo "Hello World"' }

        @pod_target.should_build?.should == false
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
      it 'returns the swift version with the given requirements from the target definition' do
        @target_definition.store_swift_version_requirements('>= 4.0')
        @pod_target.root_spec.stubs(:swift_versions).returns([Version.new('3.0'), Version.new('4.0')])
        @pod_target.swift_version.should == '4.0'
      end

      it 'returns the swift version with the given requirements from all target definitions' do
        target_definition_one = fixture_target_definition('App1')
        target_definition_one.store_swift_version_requirements('>= 4.0')
        target_definition_two = fixture_target_definition('App2')
        target_definition_two.store_swift_version_requirements('= 4.2')
        pod_target = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [@banana_spec], [target_definition_one,
                                                                                                 target_definition_two])
        @pod_target.root_spec.stubs(:swift_versions).returns([Version.new('3.0'), Version.new('4.0'),
                                                              Version.new('4.2')])
        pod_target.swift_version.should == '4.2'
      end

      it 'returns an empty swift version if none of the requirements match' do
        target_definition_one = fixture_target_definition('App1')
        target_definition_one.store_swift_version_requirements('>= 4.0')
        target_definition_two = fixture_target_definition('App2')
        target_definition_two.store_swift_version_requirements('= 4.2')
        pod_target = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [@banana_spec], [target_definition_one,
                                                                                                 target_definition_two])
        @pod_target.root_spec.stubs(:swift_versions).returns([Version.new('3.0'), Version.new('4.0')])
        pod_target.swift_version.should == ''
      end

      it 'uses the swift version defined in the specification' do
        @pod_target.root_spec.stubs(:swift_versions).returns([Version.new('3.0')])
        @target_definition.stubs(:swift_version).returns('2.3')
        @pod_target.swift_version.should == '3.0'
      end

      it 'uses the max swift version defined in the specification' do
        @pod_target.root_spec.stubs(:swift_versions).returns([Version.new('3.0'), Version.new('4.0')])
        @target_definition.stubs(:swift_version).returns('2.3')
        @pod_target.swift_version.should == '4.0'
      end

      it 'uses the swift version defined by the target definitions if no swift version is specified in the spec' do
        @pod_target.root_spec.stubs(:swift_versions).returns([])
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
          monkey_pod_target = PodTarget.new(config.sandbox, false, {}, [],
                                            Platform.ios, [monkey_spec], [@target_definition])
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
          monkey_pod_target = PodTarget.new(config.sandbox, false, {}, [],
                                            Platform.ios, [monkey_spec], [@target_definition])
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
          monkey_pod_target = PodTarget.new(config.sandbox, false, {}, [],
                                            Platform.ios, [monkey_spec], [@target_definition])
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
          monkey_pod_target = PodTarget.new(config.sandbox, false, {}, [],
                                            Platform.ios, [monkey_spec], [@target_definition])
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

    describe '#defines_module?' do
      it 'returns false when building as a library' do
        @pod_target.should.not.defines_module
      end

      it 'returns true when building as a framework' do
        @pod_target.stubs(:requires_frameworks? => true)
        @pod_target.should.defines_module
      end

      it 'returns true when building as a static framework' do
        @pod_target.stubs(:requires_frameworks? => true, :static_framework? => true)
        @pod_target.should.defines_module
      end

      it 'returns true when the target definition says to' do
        @target_definition.set_use_modular_headers_for_pod('BananaLib', true)
        @pod_target.should.defines_module
      end

      it 'returns false when any target definition says to' do
        @target_definition.set_use_modular_headers_for_pod('BananaLib', true)

        other_target_definition = Podfile::TargetDefinition.new('Other', nil)
        other_target_definition.abstract = false

        @pod_target.stubs(:target_definitions).returns([@target_definition, other_target_definition])

        @pod_target.should.not.defines_module
      end

      it 'warns if multiple target definitions do not agree on whether to use a module or not' do
        banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
        first_target_definition = fixture_target_definition('SampleApp')
        first_target_definition.abstract = false
        first_target_definition.store_pod('BananaLib', [])
        first_target_definition.set_use_modular_headers_for_pod('BananaLib', true)
        second_target_definition = fixture_target_definition('SampleApp2')
        second_target_definition.abstract = false
        second_target_definition.store_pod('BananaLib', [])
        second_target_definition.set_use_modular_headers_for_pod('BananaLib', false)
        pod_target = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [banana_spec],
                                   [first_target_definition, second_target_definition])
        pod_target.should.not.defines_module
        UI.warnings.should.include 'Unable to determine whether to build `BananaLib` as a module due to a conflict ' \
          "between the following target definitions:\n\t- `Pods-SampleApp` requires `BananaLib` as a module\n\t- " \
          "`Pods-SampleApp2` does not require `BananaLib` as a module\n\nDefaulting to skip building `BananaLib` as a module.\n"
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
          @watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
          @test_spec_target_definition = Podfile::TargetDefinition.new('Pods', nil)
          @test_spec_target_definition.abstract = false
          @test_pod_target = fixture_pod_target_with_specs([@watermelon_spec, *@watermelon_spec.recursive_subspecs],
                                                           true, {}, [], Platform.new(:ios, '6.0'),
                                                           [@test_spec_target_definition])
        end

        it 'returns that it has test specifications' do
          @test_pod_target.contains_test_specifications?.should == true
        end

        it 'returns test label based on test type' do
          @test_pod_target.test_target_label(@test_pod_target.test_specs.first).should == 'WatermelonLib-Unit-Tests'
        end

        it 'returns the correct product type for test type' do
          @test_pod_target.product_type_for_test_type(:unit).should == :unit_test_bundle
        end

        it 'raises for unknown test type' do
          exception = lambda { @test_pod_target.product_type_for_test_type(:weird_test_type) }.should.raise ArgumentError
          exception.message.should.include 'Unknown test type `weird_test_type`.'
        end

        it 'returns correct copy resources script path for test unit test type' do
          @test_pod_target.copy_resources_script_path_for_test_spec(@test_pod_target.test_specs.first).to_s.should.include 'Pods/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-resources.sh'
        end

        it 'returns correct embed frameworks script path for test unit test type' do
          @test_pod_target.embed_frameworks_script_path_for_test_spec(@test_pod_target.test_specs.first).to_s.should.include 'Pods/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-frameworks.sh'
        end

        it 'returns correct prefix header path for test unit test type' do
          @test_pod_target.prefix_header_path_for_test_spec(@test_pod_target.test_specs.first).to_s.should.include 'Pods/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-prefix.pch'
        end

        it 'returns correct path for info plist for unit test type' do
          @test_pod_target.info_plist_path_for_test_spec(@test_pod_target.test_specs.first).to_s.should.include 'Pods/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-Info.plist'
        end

        it 'returns the correct resource paths' do
          @test_pod_target.resource_paths.should == {
            'WatermelonLib' => [],
            'WatermelonLib/Tests' => ['${PODS_CONFIGURATION_BUILD_DIR}/WatermelonLibTestResources.bundle'],
            'WatermelonLib/SnapshotTests' => [],
          }
        end

        it 'returns the correct framework paths' do
          @test_pod_target.framework_paths.should == {
            'WatermelonLib' => [
              Target::FrameworkPaths.new('${BUILT_PRODUCTS_DIR}/WatermelonLib/WatermelonLib.framework'),
            ],
            'WatermelonLib/Tests' => [],
            'WatermelonLib/SnapshotTests' => [],
          }
        end

        it 'returns correct whether a test spec uses Swift or not' do
          @test_pod_target.uses_swift_for_non_library_spec?(@test_pod_target.test_specs[0]).should.be.true
          @test_pod_target.uses_swift_for_non_library_spec?(@test_pod_target.test_specs[1]).should.be.false
        end
      end
    end
  end
end
