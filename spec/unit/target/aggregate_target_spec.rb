require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe AggregateTarget do
    describe 'In general' do
      before do
        @target_definition = Podfile::TargetDefinition.new('Pods', nil)
        @target_definition.abstract = false
        @target = AggregateTarget.new(@target_definition, config.sandbox)
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
        project_path = SpecHelper.fixture('SampleProject/SampleProject.xcodeproj')
        @target.user_project = Xcodeproj::Project.open(project_path)
        @target.user_target_uuids = ['A346496C14F9BE9A0080D870']
        targets = @target.user_targets
        targets.count.should == 1
        targets.first.class.should == Xcodeproj::Project::PBXNativeTarget
      end
    end

    describe 'Support files' do
      before do
        @target_definition = Podfile::TargetDefinition.new('Pods', nil)
        @target_definition.abstract = false
        @target = AggregateTarget.new(@target_definition, config.sandbox)
        @target.client_root = config.sandbox.root.dirname
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

      it 'returns the absolute path of the prefix header file' do
        @target.prefix_header_path.to_s.should.include?('Pods/Target Support Files/Pods/Pods-prefix.pch')
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
    end

    describe 'Pod targets' do
      before do
        @spec = fixture_spec('banana-lib/BananaLib.podspec')
        @target_definition = Podfile::TargetDefinition.new('Pods', nil)
        @target_definition.abstract = false
        @pod_target = PodTarget.new([@spec], [@target_definition], config.sandbox)
        @target = AggregateTarget.new(@target_definition, config.sandbox)
        @target.stubs(:platform).returns(:ios)
        @target.pod_targets = [@pod_target]
      end

      describe 'with configuration dependent pod targets' do
        before do
          @pod_target_release = PodTarget.new([@spec], [@target_definition], config.sandbox)
          @pod_target_release.expects(:include_in_build_config?).with(@target_definition, 'Debug').returns(false)
          @pod_target_release.expects(:include_in_build_config?).with(@target_definition, 'Release').returns(true)
          @target.pod_targets = [@pod_target, @pod_target_release]
          @target.user_build_configurations = {
            'Debug' => :debug,
            'Release' => :release,
          }
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
          @target = AggregateTarget.new(@pod_target.target_definitions.first, config.sandbox)
          @target.pod_targets = [@pod_target]
        end

        it 'returns that it does not use swift' do
          @target.uses_swift?.should == false
        end

        describe 'Host requires frameworks' do
          before do
            @target.host_requires_frameworks = true
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
            @target = AggregateTarget.new(target_definition, config.sandbox)
            project_path = SpecHelper.fixture('SampleProject/SampleProject.xcodeproj')
            @target.user_project = Xcodeproj::Project.open(project_path)
            @target.user_target_uuids = ['A346496C14F9BE9A0080D870']
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

          it 'does not require a host target for watch 2 extension targets' do
            @target.user_targets.first.stubs(:symbol_type).returns(:watch2_extension)
            @target.requires_host_target?.should == false
          end

          it 'does not require a host target for application targets' do
            @target.user_targets.first.stubs(:symbol_type).returns(:application)
            @target.requires_host_target?.should == false
          end

          it 'does not require a host target, if there is no user project (manual integration)' do
            @target.user_project = nil
            @target.user_target_uuids = []
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

      describe 'With frameworks' do
        before do
          @pod_target = fixture_pod_target('orange-framework/OrangeFramework.podspec', [fixture_target_definition('iOS Example')])
          @target = AggregateTarget.new(@pod_target.target_definitions.first, config.sandbox)
          @target.stubs(:requires_frameworks?).returns(true)
          @target.pod_targets = [@pod_target]
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
