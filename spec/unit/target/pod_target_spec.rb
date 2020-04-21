require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe PodTarget do
    before do
      @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
      @target_definition = fixture_target_definition
      @pod_target = fixture_pod_target(@banana_spec, BuildType.static_library, {}, [], Platform.ios, [@target_definition])
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

      it 'returns the swift version' do
        multiswift_spec = fixture_spec('multi-swift/MultiSwift.podspec')
        pod_target = fixture_pod_target(multiswift_spec, BuildType.dynamic_framework, {}, [], Platform.ios,
                                        [@target_definition], nil, '4.0')
        pod_target.scoped.first.swift_version.should == '4.0'
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

      it 'returns empty sets of dependent targets' do
        grapefruits = fixture_spec('grapefruits-lib/GrapefruitsLib.podspec')
        @pod_target = fixture_pod_target_with_specs([grapefruits, *grapefruits.recursive_subspecs], false, {}, [], Platform.ios, [@target_definition])

        @pod_target.dependent_targets.should == []
        @pod_target.dependent_targets_by_config.should == { :debug => [], :release => [] }

        @pod_target.test_dependent_targets_by_spec_name.should == { 'GrapefruitsLib/Tests' => [] }
        @pod_target.test_dependent_targets_by_spec_name_by_config.should == { 'GrapefruitsLib/Tests' => { :debug => [], :release => [] } }

        @pod_target.app_dependent_targets_by_spec_name.should == { 'GrapefruitsLib/App' => [] }
        @pod_target.app_dependent_targets_by_spec_name_by_config.should == { 'GrapefruitsLib/App' => { :debug => [], :release => [] } }
      end

      describe '#headers_sandbox' do
        it 'returns the correct path' do
          @pod_target.headers_sandbox.should == Pathname.new('BananaLib')
        end

        it 'returns the correct path when a custom module name is set' do
          @pod_target.stubs(:product_module_name).returns('BananaLibModule')
          @pod_target.headers_sandbox.should == Pathname.new('BananaLib')
        end

        it 'returns the correct path when headers_dir is set' do
          @pod_target.stubs(:product_module_name).returns('BananaLibModule')
          @file_accessor = @pod_target.file_accessors.first
          @file_accessor.spec_consumer.stubs(:header_dir).returns('Sub_dir')
          @pod_target.headers_sandbox.should == Pathname.new('BananaLib')
        end
      end

      describe '#build_settings_for_spec' do
        before do
          @watermelon_spec = fixture_spec('grapefruits-lib/GrapefruitsLib.podspec')
          @pod_target = fixture_pod_target_with_specs([@watermelon_spec, *@watermelon_spec.recursive_subspecs],
                                                      true, Pod::Target::DEFAULT_BUILD_CONFIGURATIONS, [], Platform.new(:ios, '6.0'), [@target_definition])
        end

        it 'raises when the target does not contain the spec' do
          -> { @pod_target.build_settings_for_spec(stub('spec', :spec_type => :test, :name => 'Test/Test')) }.should.raise(ArgumentError, /No build settings for/)
        end

        it 'returns the build settings for a library spec' do
          @pod_target.build_settings_for_spec(@watermelon_spec, :configuration => :debug).should.equal @pod_target.build_settings[:debug]
          @pod_target.build_settings_for_spec(@watermelon_spec, :configuration => :release).should.equal @pod_target.build_settings[:release]
        end

        it 'returns the build settings for a test spec' do
          test_spec = @watermelon_spec.recursive_subspecs.find { |s| s.name == 'GrapefruitsLib/Tests' }
          @pod_target.build_settings_for_spec(test_spec, :configuration => :debug).non_library_spec.should == test_spec
          @pod_target.build_settings_for_spec(test_spec, :configuration => :release).non_library_spec.should == test_spec
        end

        it 'returns the build settings for an app spec' do
          app_spec = @watermelon_spec.recursive_subspecs.find { |s| s.name == 'GrapefruitsLib/App' }
          @pod_target.build_settings_for_spec(app_spec, :configuration => :debug).non_library_spec.should == app_spec
          @pod_target.build_settings_for_spec(app_spec, :configuration => :release).non_library_spec.should == app_spec
        end
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

    describe 'project name' do
      it 'returns the project name from the target definition if one is specified' do
        @target_definition.store_pod('BananaLib', :project_name => 'SomeProject')
        @pod_target.project_name.should == 'SomeProject'
      end

      it 'returns the project name from the pod target by default' do
        @pod_target.project_name.should == 'BananaLib'
      end

      it 'returns the correct project name across multiple target definitions' do
        target_definition_one = fixture_target_definition
        target_definition_two = fixture_target_definition
        target_definition_two.store_pod('BananaLib', :project_name => 'SomeProject')
        pod_target = fixture_pod_target(@banana_spec, BuildType.static_library, {}, [], Platform.ios,
                                        [target_definition_one, target_definition_two])
        pod_target.project_name.should == 'SomeProject'
      end
    end

    describe 'Inhibit warnings' do
      it 'should inhibit warnings for pods that are part of the target definition and require it' do
        target_definition = fixture_target_definition('App1')
        target_definition.store_pod('BananaLib', :inhibit_warnings => true)
        pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [@banana_spec], [target_definition])
        pod_target.inhibit_warnings?.should.be.true
      end

      it "should not inhibit warnings for pods that are part of the target definition but don't require it" do
        target_definition = fixture_target_definition('App1')
        target_definition.store_pod('BananaLib', :inhibit_warnings => false)
        pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [@banana_spec], [target_definition])
        pod_target.inhibit_warnings?.should.be.false
      end

      it 'should not inhibit warnings for pods that do not belong into the target definition' do
        target_definition = fixture_target_definition('App1')
        target_definition.store_pod('CoconutLib', :inhibit_warnings => true)
        pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [@banana_spec], [target_definition])
        pod_target.inhibit_warnings?.should.be.false
      end

      it 'should not warn for pods that belong into multiple target definitions but have the same setting' do
        target_definition_one = fixture_target_definition('App1')
        target_definition_one.store_pod('BananaLib', :inhibit_warnings => true)
        target_definition_two = fixture_target_definition('App2')
        target_definition_two.store_pod('BananaLib', :inhibit_warnings => true)
        pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [@banana_spec],
                                   [target_definition_one, target_definition_two])
        pod_target.inhibit_warnings?.should.be.true
        UI.warnings.should.be.empty
      end

      it 'warns and picks the root target definition setting if inhibit warnings values collide' do
        target_definition_one = fixture_target_definition('App1')
        target_definition_one.podfile.root_target_definitions = [target_definition_one]
        target_definition_one.store_pod('BananaLib', :inhibit_warnings => true)
        target_definition_two = fixture_target_definition('App2')
        target_definition_two.store_pod('BananaLib', :inhibit_warnings => false)
        pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [@banana_spec],
                                   [target_definition_one, target_definition_two])
        pod_target.inhibit_warnings?.should.be.true
        UI.warnings.should.include 'The pod `BananaLib` is linked to different targets (`App1` and `App2`), which ' \
          'contain different settings to inhibit warnings. CocoaPods does not currently support different settings ' \
          "and will fall back to your preference set in the root target definition.\n"
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
          monkey_pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [],
                                            Platform.ios, [monkey_spec], [@target_definition])
          @pod_target.dependent_targets = [monkey_pod_target]
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
          monkey_pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [],
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
          monkey_pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [],
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
          @pod_target.dependent_targets = [@monkey_pod_target]
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
          monkey_pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [],
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
        @pod_target.stubs(:build_type => BuildType.dynamic_framework)
        @pod_target.should.defines_module
      end

      it 'returns true when building as a static framework' do
        @pod_target.stubs(:build_type => BuildType.static_framework)
        @pod_target.should.defines_module
      end

      it 'returns true when the target definition says to' do
        @target_definition.set_use_modular_headers_for_pod('BananaLib', true)
        @pod_target.should.defines_module
      end

      it 'returns false when any target definition says to' do
        @target_definition.set_use_modular_headers_for_pod('BananaLib', true)

        other_target_definition = fixture_target_definition('Other')
        other_target_definition.store_pod('BananaLib')

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
        pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [banana_spec],
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
            @pod_target = fixture_pod_target('banana-lib/BananaLib.podspec', BuildType.dynamic_framework)
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

      describe '#header_mappings' do
        before do
          @file_accessor = @pod_target.file_accessors.first
        end

        it 'returns the correct public header mappings' do
          headers = [Pathname.new('Banana.h')]
          mappings = @pod_target.send(:header_mappings, @file_accessor, headers)
          mappings.should == {
            Pathname.new('BananaLib') => [Pathname.new('Banana.h')],
          }
        end

        it 'takes into account the header dir specified in the spec for public headers' do
          headers = [Pathname.new('Banana.h')]
          @file_accessor.spec_consumer.stubs(:header_dir).returns('Sub_dir')
          mappings = @pod_target.send(:header_mappings, @file_accessor, headers)
          mappings.should == {
            Pathname.new('BananaLib/Sub_dir') => [Pathname.new('Banana.h')],
          }
        end

        it 'takes into account the header dir specified in the spec for private headers' do
          headers = [Pathname.new('Banana.h')]
          @file_accessor.spec_consumer.stubs(:header_dir).returns('Sub_dir')
          mappings = @pod_target.send(:header_mappings, @file_accessor, headers)
          mappings.should == {
            Pathname.new('BananaLib/Sub_dir') => [Pathname.new('Banana.h')],
          }
        end

        it 'takes into account the header mappings dir specified in the spec' do
          header_1 = @file_accessor.root + 'BananaLib/sub_dir/dir_1/banana_1.h'
          header_2 = @file_accessor.root + 'BananaLib/sub_dir/dir_2/banana_2.h'
          headers = [header_1, header_2]
          @file_accessor.spec_consumer.stubs(:header_mappings_dir).returns('BananaLib/sub_dir')
          mappings = @pod_target.send(:header_mappings, @file_accessor, headers)
          mappings.should == {
            (@pod_target.headers_sandbox + 'dir_1') => [header_1],
            (@pod_target.headers_sandbox + 'dir_2') => [header_2],
          }
        end
      end

      describe 'With frameworks' do
        before do
          @pod_target = fixture_pod_target('orange-framework/OrangeFramework.podspec', BuildType.dynamic_framework)
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
          @orangeframework_pod_target = fixture_pod_target('orange-framework/OrangeFramework.podspec',
                                                           BuildType.static_library, {}, [], Platform.ios,
                                                           @pod_target.target_definitions)
          @matryoshka_pod_target = fixture_pod_target('matryoshka/matryoshka.podspec', BuildType.static_library, {}, [],
                                                      Platform.ios, @pod_target.target_definitions)
          @monkey_pod_target = fixture_pod_target('monkey/monkey.podspec', BuildType.static_library, {}, [],
                                                  Platform.ios, @pod_target.target_definitions)
          @coconut_pod_target = fixture_pod_target('coconut-lib/CoconutLib.podspec', BuildType.static_library, {}, [],
                                                   Platform.ios, @pod_target.target_definitions)
          @pod_target.dependent_targets = [@orangeframework_pod_target]
          @pod_target.test_dependent_targets_by_spec_name = { @orangeframework_pod_target.name => [@matryoshka_pod_target] }
          @pod_target.app_dependent_targets_by_spec_name = { @orangeframework_pod_target.name => [@monkey_pod_target] }
          @pod_target.test_app_hosts_by_spec = {
            fixture_spec('orange-framework/OrangeFramework.podspec') => [@matryoshka_pod_target.specs.first, @matryoshka_pod_target],
          }
        end

        it 'resolves simple dependencies' do
          @pod_target.recursive_dependent_targets.should == [@orangeframework_pod_target]
        end

        it 'scopes test and non test dependencies' do
          scoped_pod_target = @pod_target.scoped
          scoped_pod_target.first.dependent_targets.count.should == 1
          scoped_pod_target.first.dependent_targets.first.name.should == 'OrangeFramework-Pods'
          scoped_pod_target.first.test_dependent_targets_by_spec_name.count.should == 1
          scoped_pod_target.first.test_dependent_targets_by_spec_name['OrangeFramework'].first.name.should == 'matryoshka-Pods'
          scoped_pod_target.first.app_dependent_targets_by_spec_name.count.should == 1
          scoped_pod_target.first.app_dependent_targets_by_spec_name['OrangeFramework'].first.name.should == 'monkey-Pods'
        end

        it 'scopes test app host dependencies' do
          scoped_pod_target = @pod_target.scoped.first
          scoped_pod_target.test_app_hosts_by_spec.count.should == 1
          scoped_pod_target.test_app_hosts_by_spec[@orangeframework_pod_target.root_spec].first.should == @matryoshka_pod_target.specs.first
          scoped_pod_target.test_app_hosts_by_spec[@orangeframework_pod_target.root_spec].last.name.should == 'matryoshka-Pods'
        end

        it 'responds to #test_app_hosts_by_name for compatibility' do
          # TODO: Remove in 2.0
          scoped_pod_target = @pod_target.scoped.first
          scoped_pod_target.test_app_hosts_by_spec_name.count.should == 1
          scoped_pod_target.test_app_hosts_by_spec_name[@orangeframework_pod_target.root_spec.name].first.should == @matryoshka_pod_target.specs.first
          scoped_pod_target.test_app_hosts_by_spec_name[@orangeframework_pod_target.root_spec.name].last.name.should == 'matryoshka-Pods'
        end

        describe 'With cyclic dependencies' do
          before do
            @orangeframework_pod_target = fixture_pod_target('orange-framework/OrangeFramework.podspec')
            @orangeframework_pod_target.dependent_targets = [@pod_target]
            @pod_target.dependent_targets = [@orangeframework_pod_target]
          end

          it 'resolves the cycle' do
            @pod_target.recursive_dependent_targets.should == [@orangeframework_pod_target]
          end
        end

        describe 'With per configuration dependencies' do
          before do
            @per_config_dependencies = { :debug => [@orangeframework_pod_target, @matryoshka_pod_target], :release => [@coconut_pod_target] }
          end

          it 'returns correct set of dependencies depending on configuration' do
            @pod_target.dependent_targets_by_config = @per_config_dependencies
            @pod_target.recursive_dependent_targets(:configuration => :debug).should == [@orangeframework_pod_target, @matryoshka_pod_target]
            @pod_target.recursive_dependent_targets(:configuration => :release).should == [@coconut_pod_target]
            @pod_target.recursive_dependent_targets.should == [@orangeframework_pod_target, @matryoshka_pod_target, @coconut_pod_target]
          end

          it 'returns correct set of test dependencies depending on configuration' do
            watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
            watermelon_pod_target = fixture_pod_target_with_specs([watermelon_spec,
                                                                   *watermelon_spec.recursive_subspecs],
                                                                  BuildType.static_library, {}, [], Platform.ios,
                                                                  @pod_target.target_definitions)
            test_spec = watermelon_pod_target.test_specs.first
            watermelon_pod_target.test_dependent_targets_by_spec_name_by_config = { test_spec.name => @per_config_dependencies }
            watermelon_pod_target.recursive_test_dependent_targets(test_spec, :configuration => :debug).should == [@orangeframework_pod_target, @matryoshka_pod_target]
            watermelon_pod_target.recursive_test_dependent_targets(test_spec, :configuration => :release).should == [@coconut_pod_target]
            watermelon_pod_target.recursive_test_dependent_targets(test_spec).should == [@orangeframework_pod_target, @matryoshka_pod_target, @coconut_pod_target]
          end

          it 'returns correct set of app dependencies depending on configuration' do
            watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
            watermelon_pod_target = fixture_pod_target_with_specs([watermelon_spec,
                                                                   *watermelon_spec.recursive_subspecs],
                                                                  BuildType.static_library, {}, [], Platform.ios,
                                                                  @pod_target.target_definitions)
            app_spec = watermelon_pod_target.app_specs.first
            watermelon_pod_target.app_dependent_targets_by_spec_name_by_config = { app_spec.name => @per_config_dependencies }
            watermelon_pod_target.recursive_app_dependent_targets(app_spec, :configuration => :debug).should == [@orangeframework_pod_target, @matryoshka_pod_target]
            watermelon_pod_target.recursive_app_dependent_targets(app_spec, :configuration => :release).should == [@coconut_pod_target]
          end
        end
      end

      describe 'Deployment target' do
        before do
          @watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
          @pod_target = fixture_pod_target(@watermelon_spec, BuildType.static_library, {}, [], Platform.new(:ios, '9.0'))
        end

        it 'returns the correct deployment target it was initialized with' do
          @pod_target.platform.deployment_target.to_s.should == '9.0'
        end

        it 'returns the correct non library spec deployment target that is inherited from parent' do
          @pod_target.deployment_target_for_non_library_spec(@watermelon_spec.app_specs.first).to_s.should == '9.0'
        end

        it 'returns the overridden non library spec deployment target that is inherited from parent' do
          @watermelon_spec.test_specs.first.ios.deployment_target = '8.0'
          @watermelon_spec.app_specs.first.ios.deployment_target = '8.0'
          @pod_target.deployment_target_for_non_library_spec(@watermelon_spec.test_specs.first).to_s.should == '8.0'
          @pod_target.deployment_target_for_non_library_spec(@watermelon_spec.app_specs.first).to_s.should == '8.0'
        end

        it 'returns the determined deployment target even if the podspec does not explicitly specify one' do
          # The coconut spec does not specify a deployment target at all. We expect the deployment target for the non
          # library spec to be set with the one by the pod target itself instead.
          coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
          pod_target = fixture_pod_target(coconut_spec, false, {}, [], Platform.new(:ios, '4.3'))
          pod_target.deployment_target_for_non_library_spec(coconut_spec.test_specs.first).to_s.should == '4.3'
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

      describe 'scheme support' do
        before do
          @matryoshka_spec = fixture_spec('matryoshka/matryoshka.podspec')
          @matryoshka_spec.scheme = { :launch_arguments => %w(Arg1 Arg2), :environment_variables => { 'Key1' => 'Val1' } }
          @watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
          @watermelon_spec.scheme = { :launch_arguments => %w(Arg1 Arg2), :environment_variables => { 'Key1' => 'Val1' } }
          @watermelon_spec.test_specs.first.scheme = { :launch_arguments => ['TestArg1'] }
          @pod_target = fixture_pod_target(@watermelon_spec)
        end

        it 'returns the correct scheme configuration for the requested spec' do
          @pod_target.scheme_for_spec(@watermelon_spec).should == { :launch_arguments => %w(Arg1 Arg2),
                                                                    :environment_variables => { 'Key1' => 'Val1' } }
          @pod_target.scheme_for_spec(@watermelon_spec.test_specs.first).should == { :launch_arguments => ['TestArg1'] }
        end

        it 'returns an empty scheme configuration for the requested sub spec' do
          @pod_target.scheme_for_spec(@matryoshka_spec).should == { :launch_arguments => %w(Arg1 Arg2),
                                                                    :environment_variables => { 'Key1' => 'Val1' } }
          @pod_target.scheme_for_spec(@matryoshka_spec.subspecs.first).should == {}
        end

        it 'returns an empty scheme configuration for a spec with an unsupported platform' do
          @matryoshka_spec.ios.deployment_target = '7.0'
          @matryoshka_spec.subspecs.first.watchos.deployment_target = '4.2'
          pod_target = fixture_pod_target(@matryoshka_spec.subspecs.first, BuildType.dynamic_framework, {}, {}, Platform.watchos)
          pod_target.scheme_for_spec(@matryoshka_spec).should == {}
        end
      end

      describe 'resource and framework paths' do
        before do
          @watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
          @monkey_spec = fixture_spec('monkey/monkey.podspec')
          @target_definition = fixture_target_definition('Pods')
          @watermelon_pod_target = fixture_pod_target_with_specs([@watermelon_spec, *@watermelon_spec.recursive_subspecs],
                                                                 BuildType.dynamic_framework, {}, [], Platform.new(:ios, '6.0'),
                                                                 [@target_definition])
          @monkey_pod_target = fixture_pod_target(@monkey_spec, BuildType.dynamic_framework, {}, [], Platform.new(:ios, '6.0'),
                                                  [@target_definition])
        end

        it 'returns the correct resource paths' do
          @watermelon_pod_target.resource_paths.should == {
            'WatermelonLib' => [],
            'WatermelonLib/Tests' => ['${PODS_CONFIGURATION_BUILD_DIR}/WatermelonLibTestResources.bundle'],
            'WatermelonLib/UITests' => [],
            'WatermelonLib/SnapshotTests' => [],
            'WatermelonLib/App' => ['${PODS_CONFIGURATION_BUILD_DIR}/WatermelonLib/WatermelonLibExampleAppResources.bundle'],
          }
        end

        it 'returns the correct resource paths for use_libraries' do
          @watermelon_pod_target.stubs(:build_as_framework?).returns(false)
          @watermelon_pod_target.resource_paths.should == {
            'WatermelonLib' => [],
            'WatermelonLib/Tests' => ['${PODS_ROOT}/../../spec/fixtures/watermelon-lib/App/resource.txt',
                                      '${PODS_CONFIGURATION_BUILD_DIR}/WatermelonLibTestResources.bundle'],
            'WatermelonLib/UITests' => [],
            'WatermelonLib/SnapshotTests' => [],
            'WatermelonLib/App' => ['${PODS_CONFIGURATION_BUILD_DIR}/WatermelonLib/WatermelonLibExampleAppResources.bundle'],
          }
        end

        it 'returns the correct framework paths' do
          @watermelon_pod_target.framework_paths.should == {
            'WatermelonLib' => [
              Xcode::FrameworkPaths.new('${BUILT_PRODUCTS_DIR}/WatermelonLib/WatermelonLib.framework'),
            ],
            'WatermelonLib/Tests' => [],
            'WatermelonLib/UITests' => [],
            'WatermelonLib/SnapshotTests' => [],
            'WatermelonLib/App' => [],
          }
        end

        it 'returns correct vendored framework paths' do
          @monkey_pod_target.framework_paths.should == {
            'monkey' => [
              Xcode::FrameworkPaths.new('${PODS_ROOT}/../../spec/fixtures/monkey/dynamic-monkey.framework', nil, []),
            ],
          }
        end
      end

      describe 'test spec support' do
        before do
          @watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
          @test_spec_target_definition = fixture_target_definition('Pods')
          @test_pod_target = fixture_pod_target_with_specs([@watermelon_spec, *@watermelon_spec.recursive_subspecs],
                                                           true, {}, [], Platform.new(:ios, '6.0'),
                                                           [@test_spec_target_definition])
        end

        it 'returns that it has test specifications' do
          @test_pod_target.contains_test_specifications?.should == true
        end

        it 'returns test label based on test type' do
          @test_pod_target.test_target_label(@test_pod_target.test_specs.first).should == 'WatermelonLib-Unit-Tests'
          @test_pod_target.test_target_label(@test_pod_target.test_specs[1]).should == 'WatermelonLib-UI-UITests'
        end

        it 'returns the correct product type for unit test type' do
          @test_pod_target.product_type_for_test_type(:unit).should == :unit_test_bundle
        end

        it 'returns the correct product type for ui test type' do
          @test_pod_target.product_type_for_test_type(:ui).should == :ui_test_bundle
        end

        it 'raises for unknown test type' do
          exception = lambda { @test_pod_target.product_type_for_test_type(:weird_test_type) }.should.raise ArgumentError
          exception.message.should.include 'Unknown test type `weird_test_type`.'
        end

        it 'returns correct copy resources script path for test unit test type' do
          @test_pod_target.copy_resources_script_path_for_spec(@test_pod_target.test_specs.first).to_s.should.include 'Pods/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-resources.sh'
        end

        it 'returns correct embed frameworks script path for test unit test type' do
          @test_pod_target.embed_frameworks_script_path_for_spec(@test_pod_target.test_specs.first).to_s.should.include 'Pods/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-frameworks.sh'
        end

        it 'returns correct prefix header path for test unit test type' do
          @test_pod_target.prefix_header_path_for_spec(@test_pod_target.test_specs.first).to_s.should.include 'Pods/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-prefix.pch'
        end

        it 'returns correct path for info plist for unit test type' do
          @test_pod_target.info_plist_path_for_spec(@test_pod_target.test_specs.first).to_s.should.include 'Pods/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-Info.plist'
        end

        it 'returns correct whether a test spec uses Swift or not' do
          @test_pod_target.uses_swift_for_spec?(@test_pod_target.test_specs.find { |t| t.base_name == 'Tests' }).should.be.true
          @test_pod_target.uses_swift_for_spec?(@test_pod_target.test_specs.find { |t| t.base_name == 'UITests' }).should.be.false
          @test_pod_target.uses_swift_for_spec?(@test_pod_target.test_specs.find { |t| t.base_name == 'SnapshotTests' }).should.be.false
        end

        it 'returns the app host dependent targets of a unit test type test spec that specifies an app host' do
          pineapple_spec = fixture_spec('pineapple-lib/PineappleLib.podspec')
          target_definition = fixture_target_definition('Pods')
          pineapple_pod_target = fixture_pod_target_with_specs([pineapple_spec, *pineapple_spec.recursive_subspecs],
                                                               true, {}, [], Platform.new(:ios, '6.0'),
                                                               [target_definition])
          app_host_spec = pineapple_pod_target.app_specs.find { |t| t.base_name == 'App' }
          test_spec = pineapple_pod_target.test_specs.find { |t| t.base_name == 'Tests' }
          pineapple_pod_target.test_app_hosts_by_spec = { pineapple_spec.subspec_by_name('PineappleLib/Tests', true, true) => [app_host_spec, pineapple_pod_target] }
          pineapple_pod_target.app_host_dependent_targets_for_spec(test_spec).map(&:name).should == ['PineappleLib']
        end

        it 'returns empty app host dependent targets for ui test types' do
          pineapple_spec = fixture_spec('pineapple-lib/PineappleLib.podspec')
          target_definition = fixture_target_definition('Pods')
          pineapple_pod_target = fixture_pod_target_with_specs([pineapple_spec, *pineapple_spec.recursive_subspecs],
                                                               true, {}, [], Platform.new(:ios, '6.0'),
                                                               [target_definition])
          app_host_spec = pineapple_pod_target.app_specs.find { |t| t.base_name == 'App' }
          test_spec = pineapple_pod_target.test_specs.find { |t| t.base_name == 'UI' }
          pineapple_pod_target.test_app_hosts_by_spec = { pineapple_spec.subspec_by_name('PineappleLib/UI', true, true) => [app_host_spec, pineapple_pod_target] }
          pineapple_pod_target.app_host_dependent_targets_for_spec(test_spec).map(&:name).should == []
        end

        it 'return empty app host dependent targets for non unit test specs' do
          pineapple_spec = fixture_spec('pineapple-lib/PineappleLib.podspec')
          target_definition = fixture_target_definition('Pods')
          pineapple_pod_target = fixture_pod_target_with_specs([pineapple_spec, *pineapple_spec.recursive_subspecs],
                                                               true, {}, [], Platform.new(:ios, '6.0'),
                                                               [target_definition])
          app_host_spec = pineapple_pod_target.app_specs.find { |t| t.base_name == 'App' }
          pineapple_pod_target.app_host_dependent_targets_for_spec(app_host_spec).map(&:name).should == []
        end
      end
    end

    describe 'script phases' do
      before do
        @watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
        @watermelon_test_spec = @watermelon_spec.test_specs.first
        @test_spec_target_definition = fixture_target_definition('Pods')
        @test_pod_target = fixture_pod_target_with_specs([@watermelon_spec, *@watermelon_spec.recursive_subspecs],
                                                         true, {}, [], Platform.new(:ios, '6.0'),
                                                         [@test_spec_target_definition])
      end
      describe 'embed frameworks for test & app specs' do
        it 'returns the relative path to the script' do
          path = @test_pod_target.embed_frameworks_script_path_for_spec(@watermelon_test_spec)
          path.should == @test_pod_target.support_files_dir + 'WatermelonLib-Unit-Tests-frameworks.sh'
        end

        it 'returns the correct input files file list path' do
          path = @test_pod_target.embed_frameworks_script_input_files_path_for_spec(@watermelon_test_spec)
          path.should == @test_pod_target.support_files_dir + 'WatermelonLib-Unit-Tests-frameworks-input-files.xcfilelist'
        end

        it 'returns the correct output files file list path' do
          path = @test_pod_target.embed_frameworks_script_output_files_path_for_spec(@watermelon_test_spec)
          path.should == @test_pod_target.support_files_dir + 'WatermelonLib-Unit-Tests-frameworks-output-files.xcfilelist'
        end
      end

      describe 'copy xframeworks' do
        it 'returns the relative path to the script' do
          path = @pod_target.copy_xcframeworks_script_path
          path.should == @pod_target.support_files_dir + 'BananaLib-xcframeworks.sh'
        end

        it 'returns the correct input files file list path' do
          path = @pod_target.copy_xcframeworks_script_input_files_path
          path.should == @pod_target.support_files_dir + 'BananaLib-xcframeworks-input-files.xcfilelist'
        end

        it 'returns the correct output files file list path' do
          path = @pod_target.copy_xcframeworks_script_output_files_path
          path.should == @pod_target.support_files_dir + 'BananaLib-xcframeworks-output-files.xcfilelist'
        end
      end

      describe 'copy dSYMs' do
        it 'returns the relative path to the script' do
          path = @pod_target.copy_dsyms_script_path
          path.should == @pod_target.support_files_dir + 'BananaLib-copy-dsyms.sh'
        end

        it 'returns the correct input files file list path' do
          path = @pod_target.copy_dsyms_script_input_files_path
          path.should == @pod_target.support_files_dir + 'BananaLib-copy-dsyms-input-files.xcfilelist'
        end

        it 'returns the correct output files file list path' do
          path = @pod_target.copy_dsyms_script_output_files_path
          path.should == @pod_target.support_files_dir + 'BananaLib-copy-dsyms-output-files.xcfilelist'
        end
      end
    end
  end
end
