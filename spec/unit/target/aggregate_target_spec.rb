require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe AggregateTarget do
    describe 'In general' do
      before do
        @target_definition = Podfile::TargetDefinition.new('Pods', nil)
        @target_definition.abstract = false
        project_path = SpecHelper.fixture('SampleProject/SampleProject.xcodeproj')
        @target = AggregateTarget.new(config.sandbox, false, {}, [], Platform.ios, @target_definition, config.sandbox.root.dirname, Xcodeproj::Project.open(project_path), ['A346496C14F9BE9A0080D870'], {})
      end

      it 'returns the target_definition that generated it' do
        @target.target_definition.should == @target_definition
      end

      it 'is initialized with empty archs' do
        @target.archs.should == []
      end

      it 'returns the label of the target definition' do
        @target.label.should == 'Pods'
      end

      it 'returns its name' do
        @target.name.should == 'Pods'
      end

      it 'returns the name of its product' do
        @target.product_name.should == 'libPods.a'
      end

      it 'returns the user targets' do
        targets = @target.user_targets
        targets.count.should == 1
        targets.first.class.should == Xcodeproj::Project::PBXNativeTarget
      end
    end

    describe 'Support files' do
      before do
        @target_definition = Podfile::TargetDefinition.new('Pods', nil)
        @target_definition.abstract = false
        @target = AggregateTarget.new(config.sandbox, false, {}, [], Platform.ios, @target_definition, config.sandbox.root.dirname, nil, nil, {})
      end

      it 'returns the absolute path of the xcconfig file' do
        @target.xcconfig_path('Release').to_s.should.include?('Pods/Target Support Files/Pods/Pods.release.xcconfig')
      end

      it 'returns the absolute path of the resources script' do
        @target.copy_resources_script_path.to_s.should.include?('Pods/Target Support Files/Pods/Pods-resources.sh')
      end

      it 'returns the absolute path of the frameworks script' do
        @target.embed_frameworks_script_path.to_s.should.include?('Pods/Target Support Files/Pods/Pods-frameworks.sh')
      end

      it 'returns the absolute path of the bridge support file' do
        @target.bridge_support_path.to_s.should.include?('Pods/Target Support Files/Pods/Pods.bridgesupport')
      end

      it 'returns the absolute path of the acknowledgements files without extension' do
        @target.acknowledgements_basepath.to_s.should.include?('Pods/Target Support Files/Pods/Pods-acknowledgements')
      end

      it 'returns the path of the resources script relative to the user project' do
        @target.copy_resources_script_relative_path.should == '${SRCROOT}/Pods/Target Support Files/Pods/Pods-resources.sh'
      end

      it 'returns the path of the frameworks script relative to the user project' do
        @target.embed_frameworks_script_relative_path.should == '${SRCROOT}/Pods/Target Support Files/Pods/Pods-frameworks.sh'
      end

      it 'returns the path of the xcconfig file relative to the user project' do
        @target.xcconfig_relative_path('Release').should == 'Pods/Target Support Files/Pods/Pods.release.xcconfig'
      end

      it 'returns the path of output file for the check pod manifest file  script' do
        @target.check_manifest_lock_script_output_file_path.should == '$(DERIVED_FILE_DIR)/Pods-checkManifestLockResult.txt'
      end
    end

    describe 'Pod targets' do
      before do
        @spec = fixture_spec('banana-lib/BananaLib.podspec')
        @target_definition = Podfile::TargetDefinition.new('Pods', nil)
        @target_definition.abstract = false
        @target_definition.set_platform(:ios, '10.0')
        @pod_target = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [@spec], [@target_definition])
        @target = AggregateTarget.new(config.sandbox, false, {}, [], Platform.ios, @target_definition, config.sandbox.root.dirname, nil, nil, 'Release' => [@pod_target], 'Debug' => [@pod_target])
      end

      describe 'with configuration dependent pod targets' do
        before do
          @pod_target_release = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [@spec], [@target_definition])
          @target.stubs(:pod_targets_for_build_configuration).with('Debug').returns([@pod_target])
          @target.stubs(:pod_targets_for_build_configuration).with('Release').returns([@pod_target, @pod_target_release])
          @target.stubs(:pod_targets).returns([@pod_target, @pod_target_release])
          @target.stubs(:user_build_configurations).returns('Debug' => :debug, 'Release' => :release)
        end

        it 'returns pod targets for given build configuration' do
          @target.pod_targets_for_build_configuration('Debug').should == [@pod_target]
          @target.pod_targets_for_build_configuration('Release').should == [@pod_target, @pod_target_release]
        end

        it 'returns pod target specs by build configuration' do
          @target.specs_by_build_configuration.should == {
            'Debug' => @pod_target.specs,
            'Release' => (@pod_target.specs + @pod_target_release.specs),
          }
        end
      end

      describe 'frameworks by config and input output paths' do
        before do
          @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
          @pod_target_release = PodTarget.new(config.sandbox, false, {}, [], Platform.ios, [@coconut_spec], [@target_definition])
          @target.stubs(:pod_targets).returns([@pod_target])
          @target.stubs(:user_build_configurations).returns('Debug' => :debug, 'Release' => :release)
        end

        it 'returns non vendored framework input and output paths by config' do
          @pod_target.stubs(:should_build?).returns(true)
          @pod_target.stubs(:requires_frameworks?).returns(true)
          @target.framework_paths_by_config['Debug'].should == [
            { :name => 'BananaLib.framework',
              :input_path => '${BUILT_PRODUCTS_DIR}/BananaLib/BananaLib.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/BananaLib.framework' },
          ]
          @target.framework_paths_by_config['Release'].should == [
            { :name => 'BananaLib.framework',
              :input_path => '${BUILT_PRODUCTS_DIR}/BananaLib/BananaLib.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/BananaLib.framework' },
          ]
        end

        it 'checks resource paths are empty for dynamic frameworks' do
          @pod_target.stubs(:should_build?).returns(true)
          @pod_target.stubs(:requires_frameworks?).returns(true)
          @pod_target.stubs(:static_framework?).returns(false)
          @pod_target.stubs(:resource_paths).returns(['MyResources.bundle'])
          @target.stubs(:bridge_support_file).returns(nil)
          resource_paths_by_config = @target.resource_paths_by_config
          resource_paths_by_config['Debug'].should.be.empty
          resource_paths_by_config['Release'].should.be.empty
        end

        it 'checks resource paths are included for static frameworks' do
          @pod_target.stubs(:should_build?).returns(true)
          @pod_target.stubs(:requires_frameworks?).returns(true)
          @pod_target.stubs(:static_framework?).returns(true)
          @pod_target.stubs(:resource_paths).returns(['MyResources.bundle'])
          @target.stubs(:bridge_support_file).returns(nil)
          resource_paths_by_config = @target.resource_paths_by_config
          resource_paths_by_config['Debug'].should == ['MyResources.bundle']
          resource_paths_by_config['Release'].should == ['MyResources.bundle']
        end

        it 'returns non vendored frameworks by config with different release and debug targets' do
          @pod_target_release.stubs(:should_build?).returns(true)
          @pod_target_release.stubs(:requires_frameworks?).returns(true)
          @pod_target.stubs(:should_build?).returns(true)
          @pod_target.stubs(:requires_frameworks?).returns(true)
          @target.stubs(:pod_targets_for_build_configuration).with('Debug').returns([@pod_target])
          @target.stubs(:pod_targets_for_build_configuration).with('Release').returns([@pod_target, @pod_target_release])
          @target.stubs(:pod_targets).returns([@pod_target, @pod_target_release])
          framework_paths_by_config = @target.framework_paths_by_config
          framework_paths_by_config['Debug'].should == [
            { :name => 'BananaLib.framework',
              :input_path => '${BUILT_PRODUCTS_DIR}/BananaLib/BananaLib.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/BananaLib.framework' },
          ]
          framework_paths_by_config['Release'].should == [
            { :name => 'BananaLib.framework',
              :input_path => '${BUILT_PRODUCTS_DIR}/BananaLib/BananaLib.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/BananaLib.framework' },
            { :name => 'CoconutLib.framework',
              :input_path => '${BUILT_PRODUCTS_DIR}/CoconutLib/CoconutLib.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/CoconutLib.framework' },
          ]
        end

        it 'returns vendored frameworks by config' do
          path_list = Sandbox::PathList.new(fixture('banana-lib'))
          file_accessor = Sandbox::FileAccessor.new(path_list, @spec.consumer(:ios))
          @pod_target.stubs(:file_accessors).returns([file_accessor])
          @pod_target.file_accessors.first.stubs(:vendored_dynamic_artifacts).returns(
            [Pathname('/some/absolute/path/to/FrameworkA.framework')],
          )
          @target.framework_paths_by_config['Debug'].should == [
            { :name => 'FrameworkA.framework',
              :input_path => '${PODS_ROOT}/../../../../../../../some/absolute/path/to/FrameworkA.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/FrameworkA.framework' },
          ]
        end

        it 'returns correct input and output paths for non vendored frameworks' do
          @pod_target.stubs(:should_build?).returns(true)
          @pod_target.stubs(:requires_frameworks?).returns(true)
          @target.framework_paths_by_config['Debug'].should == [
            { :name => 'BananaLib.framework',
              :input_path => '${BUILT_PRODUCTS_DIR}/BananaLib/BananaLib.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/BananaLib.framework' },
          ]
          @target.framework_paths_by_config['Release'].should == [
            { :name => 'BananaLib.framework',
              :input_path => '${BUILT_PRODUCTS_DIR}/BananaLib/BananaLib.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/BananaLib.framework' },
          ]
        end

        it 'returns correct input and output paths for vendored frameworks' do
          path_list = Sandbox::PathList.new(fixture('banana-lib'))
          file_accessor = Sandbox::FileAccessor.new(path_list, @spec.consumer(:ios))
          @pod_target.stubs(:file_accessors).returns([file_accessor])
          @pod_target.file_accessors.first.stubs(:vendored_dynamic_artifacts).returns(
            [Pathname('/absolute/path/to/FrameworkA.framework')],
          )
          @target.framework_paths_by_config['Debug'].should == [
            { :name => 'FrameworkA.framework',
              :input_path => '${PODS_ROOT}/../../../../../../../absolute/path/to/FrameworkA.framework',
              :output_path => '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/FrameworkA.framework' },
          ]
        end
      end

      it 'returns the specs of the Pods used by this aggregate target' do
        @target.specs.map(&:name).should == ['BananaLib']
      end

      it 'returns the specs of the Pods used by this aggregate target' do
        @target.specs.map(&:name).should == ['BananaLib']
      end

      it 'returns the spec consumers for the pod targets' do
        consumer_reps = @target.spec_consumers.map { |consumer| [consumer.spec.name, consumer.platform_name] }
        consumer_reps.should == [['BananaLib', :ios]]
      end
    end

    describe 'Product type dependent helpers' do
      describe 'With libraries' do
        before do
          @pod_target = fixture_pod_target('banana-lib/BananaLib.podspec')
          @target = AggregateTarget.new(config.sandbox, false, {}, [], Platform.ios, @pod_target.target_definitions.first, config.sandbox.root.dirname, nil, nil, 'Release' => [@pod_target], 'Debug' => [@pod_target])
        end

        it 'returns that it does not use swift' do
          @target.uses_swift?.should == false
        end

        describe 'Host requires frameworks' do
          before do
            @target.stubs(:host_requires_frameworks?).returns(true)
          end

          it 'returns the product name' do
            @target.product_name.should == 'Pods.framework'
          end

          it 'returns the framework name' do
            @target.framework_name.should == 'Pods.framework'
          end

          it 'returns the library name' do
            @target.static_library_name.should == 'libPods.a'
          end

          it 'returns :framework as product type' do
            @target.product_type.should == :framework
          end

          it 'returns that it requires being built as framework' do
            @target.requires_frameworks?.should == true
          end
        end

        describe 'Host does not requires frameworks' do
          before do
            @target.stubs(:host_requires_frameworks?).returns(false)
          end

          it 'returns the product name' do
            @target.product_name.should == 'libPods.a'
          end

          it 'returns the framework name' do
            @target.framework_name.should == 'Pods.framework'
          end

          it 'returns the library name' do
            @target.static_library_name.should == 'libPods.a'
          end

          it 'returns :static_library as product type' do
            @target.product_type.should == :static_library
          end

          it 'returns that it does not require being built as framework' do
            @target.requires_frameworks?.should == false
          end
        end

        describe 'Target might require a host target' do
          before do
            target_definition = Podfile::TargetDefinition.new('Pods', nil)
            target_definition.abstract = false
            project_path = SpecHelper.fixture('SampleProject/SampleProject.xcodeproj')
            @target = AggregateTarget.new(config.sandbox, true, {}, [], Platform.ios, target_definition, config.sandbox.root.dirname, Xcodeproj::Project.open(project_path), ['A346496C14F9BE9A0080D870'], 'Release' => [@pod_target], 'Debug' => [@pod_target])
          end

          it 'requires a host target for app extension targets' do
            @target.user_targets.first.stubs(:symbol_type).returns(:app_extension)
            @target.requires_host_target?.should == true
          end

          it 'requires a host target for watch extension targets' do
            @target.user_targets.first.stubs(:symbol_type).returns(:watch_extension)
            @target.requires_host_target?.should == true
          end

          it 'requires a host target for framework targets' do
            @target.user_targets.first.stubs(:symbol_type).returns(:framework)
            @target.requires_host_target?.should == true
          end

          it 'requires a host target for messages extension targets' do
            @target.user_targets.first.stubs(:symbol_type).returns(:messages_extension)
            @target.requires_host_target?.should == true
          end

          it 'requires a host target for XPC service targets' do
            @target.user_targets.first.stubs(:symbol_type).returns(:xpc_service)
            @target.requires_host_target?.should == true
          end

          it 'does not require a host target for watch 2 extension targets' do
            @target.user_targets.first.stubs(:symbol_type).returns(:watch2_extension)
            @target.requires_host_target?.should == false
          end

          it 'does not require a host target for application targets' do
            @target.user_targets.first.stubs(:symbol_type).returns(:application)
            @target.requires_host_target?.should == false
          end

          it 'does not require a host target, if there is no user project (manual integration)' do
            @target.stubs(:user_project).returns(nil)
            @target.stubs(:user_target_uuids).returns([])
            @target.requires_host_target?.should == false
          end

          it 'raises an exception if more than one kind of user_target is found' do
            @target.user_target_uuids << '51075D491521D0C100E39B41'
            @target.user_targets.first.stubs(:symbol_type).returns(:app_extension)
            @target.user_targets.last.stubs(:symbol_type).returns(:watch_extension)
            should.raise ArgumentError do
              @target.requires_host_target?
            end.message.should.equal 'Expected single kind of user_target for Pods. Found app_extension, watch_extension.'
          end
        end
      end

      describe 'Target might be a library target' do
        before do
          target_definition = Podfile::TargetDefinition.new('Pods', nil)
          target_definition.abstract = false
          project_path = SpecHelper.fixture('SampleProject/SampleProject.xcodeproj')
          @target = AggregateTarget.new(config.sandbox, true, {}, [], Platform.ios, target_definition, config.sandbox.root.dirname, Xcodeproj::Project.open(project_path), ['A346496C14F9BE9A0080D870'], 'Release' => [@pod_target], 'Debug' => [@pod_target])
        end

        it 'is a library target if the user_target is a framework' do
          @target.user_targets.first.stubs(:symbol_type).returns(:framework)
          @target.library?.should == true
        end

        it 'is a library target if the user_target is a static library' do
          @target.user_targets.first.stubs(:symbol_type).returns(:static_library)
          @target.library?.should == true
        end

        it 'is a library target if the user_target is a dynamic library' do
          @target.user_targets.first.stubs(:symbol_type).returns(:dynamic_library)
          @target.library?.should == true
        end

        it 'is not a library target if the user_target is an application' do
          @target.user_targets.first.stubs(:symbol_type).returns(:application)
          @target.library?.should == false
        end

        it 'is not a library target if the user_target is an app extension' do
          @target.user_targets.first.stubs(:symbol_type).returns(:app_extension)
          @target.library?.should == false
        end
      end

      describe 'With frameworks' do
        before do
          @pod_target = fixture_pod_target('orange-framework/OrangeFramework.podspec', true, {}, [], Platform.ios, [fixture_target_definition('iOS Example')])
          @target = AggregateTarget.new(config.sandbox, true, {}, [], Platform.ios, @pod_target.target_definitions.first, config.sandbox.root.dirname, nil, nil, 'Release' => [@pod_target])
        end

        it 'returns that it uses swift' do
          @target.uses_swift?.should == true
        end

        it 'returns the product module name' do
          @target.product_module_name.should == 'Pods_iOS_Example'
        end

        it 'returns the product name' do
          @target.product_name.should == 'Pods_iOS_Example.framework'
        end

        it 'returns the framework name' do
          @target.framework_name.should == 'Pods_iOS_Example.framework'
        end

        it 'returns the library name' do
          @target.static_library_name.should == 'libPods-iOS Example.a'
        end

        it 'returns :framework as product type' do
          @target.product_type.should == :framework
        end

        it 'returns that it requires being built as framework' do
          @target.requires_frameworks?.should == true
        end
      end
    end
  end
end
