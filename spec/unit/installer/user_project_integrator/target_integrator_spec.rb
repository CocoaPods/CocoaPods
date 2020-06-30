require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe TargetIntegrator = Installer::UserProjectIntegrator::TargetIntegrator do
    describe 'In general' do
      # The project contains a `PBXReferenceProxy` in the build files of the
      # frameworks build phase which implicitly checks for the robustness of
      # the detection of the target.
      #
      before do
        project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
        @project = Xcodeproj::Project.open(project_path)
        Project.new(config.sandbox.project_path).save
        @target = @project.targets.first
        target_definition = Podfile::TargetDefinition.new('Pods', nil)
        target_definition.abstract = false
        user_build_configurations = { 'Release' => :release, 'Debug' => :debug }
        @pod_bundle = AggregateTarget.new(config.sandbox, BuildType.static_library, user_build_configurations, [],
                                          Platform.ios, target_definition, project_path.dirname, @project,
                                          [@target.uuid], {})
        @pod_bundle.stubs(:resource_paths_by_config).returns('Release' => %w(${PODS_ROOT}/Lib/Resources/image.png))
        @pod_bundle.stubs(:framework_paths_by_config).returns('Release' => [Xcode::FrameworkPaths.new('${PODS_BUILD_DIR}/Lib/Lib.framework')])
        configuration = Xcodeproj::Config.new(
          'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) COCOAPODS=1',
        )
        @pod_bundle.xcconfigs['Debug'] = configuration
        @pod_bundle.xcconfigs['Release'] = configuration

        @target_integrator = TargetIntegrator.new(@pod_bundle)

        @phase_prefix = TargetIntegrator::BUILD_PHASE_PREFIX
        @user_phase_prefix = TargetIntegrator::USER_BUILD_PHASE_PREFIX
        @embed_framework_phase_name = @phase_prefix + TargetIntegrator::EMBED_FRAMEWORK_PHASE_NAME
        @copy_pods_resources_phase_name = @phase_prefix + TargetIntegrator::COPY_PODS_RESOURCES_PHASE_NAME
        @check_manifest_phase_name = @phase_prefix + TargetIntegrator::CHECK_MANIFEST_PHASE_NAME
        @user_script_phase_name = @user_phase_prefix + 'Custom Script'
      end

      describe '#integrate!' do
        it 'set the CocoaPods xcconfigs' do
          TargetIntegrator::XCConfigIntegrator.expects(:integrate).with(@pod_bundle, [@target])
          @target_integrator.integrate!
        end

        it 'allows the xcconfig integrator to edit already integrated targets if needed' do
          TargetIntegrator::XCConfigIntegrator.expects(:integrate).with(@pod_bundle, [@target])
          @target_integrator.integrate!
        end

        it 'adds references to the Pods static libraries to the Frameworks group' do
          @target_integrator.integrate!
          @target_integrator.send(:user_project)['Frameworks/libPods.a'].should.not.be.nil
        end

        it 'adds the libPods static library to the "Link binary with libraries" build phase of each target' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.frameworks_build_phase
          build_file = phase.files.find { |f| f.file_ref.path == 'libPods.a' }
          build_file.should.not.be.nil
        end

        it 'deletes old product type references if the product type has changed' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.frameworks_build_phase
          phase.files.find { |f| f.file_ref.path == 'libPods.a' }.should.not.be.nil
          phase.files.find { |f| f.file_ref.path == 'Pods.framework' }.should.be.nil
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          phase.files.find { |f| f.file_ref.path == 'libPods.a' }.should.be.nil
          phase.files.find { |f| f.file_ref.path == 'Pods.framework' }.should.not.be.nil
        end

        it 'cleans up linked libraries and frameworks from the frameworks build phase' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.frameworks_build_phase
          phase.files.find { |f| f.file_ref.path == 'Pods.framework' }.should.not.be.nil
          phase.files.find { |f| f.file_ref.path == 'Pods-Something.framework' }.should.be.nil
          @pod_bundle.stubs(:product_name => 'Pods-Something.framework')
          @pod_bundle.stubs(:product_basename => 'Pods-Something')
          @target_integrator.integrate!
          phase.files.find { |f| f.file_ref.path == 'Pods.framework' }.should.be.nil
          phase.files.find { |f| f.file_ref.path == 'Pods-Something.framework' }.should.not.be.nil
        end

        it 'adds references to the Pods static framework to the Frameworks group' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          @target_integrator.send(:user_project)['Frameworks/Pods.framework'].should.not.be.nil
        end

        it 'adds the Pods static framework to the "Link binary with libraries" build phase of each target' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.frameworks_build_phase
          build_file = phase.files.find { |f| f.file_ref.path == 'Pods.framework' }
          build_file.should.not.be.nil
        end

        it 'adds a Copy Pods Resources build phase to each target' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase_name = @copy_pods_resources_phase_name
          phase = target.shell_script_build_phases.find { |bp| bp.name == phase_name }
          phase.shell_script.strip.should == '"${PODS_ROOT}/Target Support Files/Pods/Pods-resources.sh"'
        end

        it 'adds a Check Manifest.lock build phase to each target' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase_name = @check_manifest_phase_name
          phase = target.shell_script_build_phases.find { |bp| bp.name == phase_name }
          phase.shell_script.should == <<-EOS.strip_heredoc
          diff "${PODS_PODFILE_DIR_PATH}/Podfile.lock" "${PODS_ROOT}/Manifest.lock" > /dev/null
          if [ $? != 0 ] ; then
              # print error to STDERR
              echo "error: The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation." >&2
              exit 1
          fi
          # This output is used by Xcode 'outputs' to avoid re-running this script phase.
          echo "SUCCESS" > "${SCRIPT_OUTPUT_FILE_0}"
          EOS
        end

        it 'adds the Check Manifest.lock build phase as the first build phase' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          target.build_phases.first
          phase_name = @check_manifest_phase_name
          phase = target.build_phases.find { |bp| bp.name == phase_name }
          target.build_phases.first.should.equal? phase
        end

        it 'does not perform the integration if there are no targets to integrate' do
          Installer::UserProjectIntegrator::TargetIntegrator::XCConfigIntegrator.
            integrate(@pod_bundle, @target_integrator.send(:native_targets))
          @target_integrator.stubs(:native_targets).returns([])
          frameworks = @target_integrator.send(:user_project).frameworks_group.children
          @target_integrator.integrate!
          @target_integrator.send(:user_project).frameworks_group.children.should == frameworks
        end

        it 'adds an embed frameworks build phase if frameworks are used' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'adds an embed frameworks build phase by default' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'adds an embed frameworks build phase if the target to integrate is a messages application' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:messages_application)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'adds an embed frameworks build phase if the target to integrate is an app clip' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:application_on_demand_install_capable)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'does not add an embed frameworks build phase if the target to integrate is a framework' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:framework)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'does not add an embed frameworks build phase if the target to integrate is an app extension' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:app_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'does not add an embed frameworks build phase if the target to integrate is a watch extension' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:watch_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'adds an embed frameworks build phase if the target to integrate is a watchOS 2 extension' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:watch2_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'does not add an embed frameworks build phase if the target to integrate is a messages extension' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:messages_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'adds an embed frameworks build phase if the target to integrate is a UI Test bundle' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          target = @target_integrator.send(:native_targets).first
          target.stubs(:symbol_type).returns(:ui_test_bundle)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'does not remove existing embed frameworks build phases from integrated framework targets' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          @pod_bundle.stubs(:requires_frameworks? => false)
          target = @target_integrator.send(:native_targets).first
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.should.not.be.nil
        end

        it 'does not remove existing embed frameworks build phases if frameworks are not used anymore' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          @pod_bundle.stubs(:requires_frameworks? => false)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'removes embed frameworks build phases from app extension targets' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
          target.stubs(:symbol_type).returns(:app_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'removes embed frameworks build phases from watch extension targets' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
          target.stubs(:symbol_type).returns(:watch_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'removes embed frameworks build phases from messages extension targets that are used in an iOS app' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
          target.stubs(:symbol_type).returns(:messages_extension)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'does not remove embed frameworks build phases from messages extension targets that are used in a messages app' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
          target.stubs(:symbol_type).returns(:messages_extension)
          @pod_bundle.stubs(:requires_host_target? => false) # Messages extensions for messages applications do not require a host target
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
        end

        it 'removes embed frameworks build phases from framework targets' do
          @pod_bundle.stubs(:build_type => BuildType.dynamic_framework)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == false
          target.stubs(:symbol_type).returns(:framework)
          @target_integrator.integrate!
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.nil?.should == true
        end

        it 'does not add copy pods resources script phase with no resources' do
          @pod_bundle.stubs(:resource_paths_by_config => { 'Debug' => [], 'Release' => [] })
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @copy_pods_resources_phase_name }
          phase.should.be.nil
        end

        it 'removes copy resources phase if it becomes empty' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @copy_pods_resources_phase_name }
          phase.input_paths.sort.should == %w(
            ${PODS_ROOT}/Lib/Resources/image.png
            ${PODS_ROOT}/Target\ Support\ Files/Pods/Pods-resources.sh
          )
          # Now pretend the same target has no more framework paths, it should update the targets input/output paths
          @pod_bundle.stubs(:resource_paths_by_config => {})
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @copy_pods_resources_phase_name }
          phase.should.be.nil
        end

        it 'clears input and output paths from script phase if it exceeds limit' do
          # The paths represented here will be 501 for input paths and 501 for output paths which will exceed the limit.
          paths = (0..500).map do |i|
            "${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugLibPng#{i}.png"
          end
          resource_paths_by_config = {
            'Debug' => paths,
            'Release' => paths,
          }
          @pod_bundle.stubs(:resource_paths_by_config => resource_paths_by_config)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @copy_pods_resources_phase_name }
          phase.input_paths.should == []
          phase.output_paths.should == []
        end

        it 'adds copy pods resources input and output paths' do
          resource_paths_by_config = {
            'Debug' => [
              '${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugAssets.xcassets',
              '${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugDataModel.xcdatamodeld',
              '${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugDataModel.xcdatamodel',
              '${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugMappingModel.xcmappingmodel',
              '${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugLib.bundle',
            ],
            'Release' => [
              '${PODS_CONFIGURATION_BUILD_DIR}/ReleaseLib/ReleaseLib.bundle',
              '${PODS_CONFIGURATION_BUILD_DIR}/ReleaseLib/ReleaseLib.storyboard',
              '${PODS_CONFIGURATION_BUILD_DIR}/ReleaseLib/ReleaseLibXIB.xib',
            ],
          }
          @pod_bundle.stubs(:resource_paths_by_config => resource_paths_by_config)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @copy_pods_resources_phase_name }
          phase.input_paths.sort.should == %w(
            ${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugAssets.xcassets
            ${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugDataModel.xcdatamodel
            ${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugDataModel.xcdatamodeld
            ${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugLib.bundle
            ${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugMappingModel.xcmappingmodel
            ${PODS_CONFIGURATION_BUILD_DIR}/ReleaseLib/ReleaseLib.bundle
            ${PODS_CONFIGURATION_BUILD_DIR}/ReleaseLib/ReleaseLib.storyboard
            ${PODS_CONFIGURATION_BUILD_DIR}/ReleaseLib/ReleaseLibXIB.xib
            ${PODS_ROOT}/Target\ Support\ Files/Pods/Pods-resources.sh
          )
          phase.output_paths.sort.should == %w(
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/Assets.car
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/DebugDataModel.mom
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/DebugDataModel.momd
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/DebugLib.bundle
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/DebugMappingModel.cdm
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ReleaseLib.bundle
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ReleaseLib.storyboardc
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ReleaseLibXIB.nib
          )
        end

        it 'adds copy pods resources input and output paths without duplicates' do
          resource_paths_by_config = {
            'Debug' => [
              '${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/SomeBundle.bundle',
            ],
            'Release' => [
              '${PODS_CONFIGURATION_BUILD_DIR}/ReleaseLib/SomeBundle.bundle',
            ],
          }
          @pod_bundle.stubs(:resource_paths_by_config => resource_paths_by_config)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @copy_pods_resources_phase_name }
          phase.input_paths.sort.should == %w(
            ${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/SomeBundle.bundle
            ${PODS_CONFIGURATION_BUILD_DIR}/ReleaseLib/SomeBundle.bundle
            ${PODS_ROOT}/Target\ Support\ Files/Pods/Pods-resources.sh
          )
          phase.output_paths.sort.should == %w(
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/SomeBundle.bundle
          )
        end

        it 'does not add embed frameworks build phase with no frameworks' do
          @pod_bundle.stubs(:framework_paths_by_config => { 'Debug' => {}, 'Release' => {} })
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.should.be.nil
        end

        it 'removes embed frameworks phase if it becomes empty' do
          debug_non_vendored_framework = Xcode::FrameworkPaths.new('${BUILT_PRODUCTS_DIR}/DebugCompiledFramework/DebugCompiledFramework.framework')
          framework_paths_by_config = {
            'Debug' => [debug_non_vendored_framework],
          }
          @pod_bundle.stubs(:framework_paths_by_config => framework_paths_by_config)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.input_paths.sort.should == %w(
            ${BUILT_PRODUCTS_DIR}/DebugCompiledFramework/DebugCompiledFramework.framework
            ${PODS_ROOT}/Target\ Support\ Files/Pods/Pods-frameworks.sh
          )
          # Now pretend the same target has no more framework paths, it should remove the script phase
          @pod_bundle.stubs(:framework_paths_by_config => {})
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.should.be.nil
        end

        it 'adds embed frameworks build phase input and output paths for vendored and non vendored frameworks' do
          debug_vendored_framework = Xcode::FrameworkPaths.new('${PODS_ROOT}/DebugVendoredFramework/ios/DebugVendoredFramework.framework',
                                                               '${PODS_ROOT}/DebugVendoredFramework/ios/DebugVendoredFramework.framework.dSYM',
                                                               ['${PODS_ROOT}/DebugVendoredFramework/ios/A6621399-62A0-3DC3-A6E3-B6B51BD287AD.bcsymbolmap'])

          debug_non_vendored_framework = Xcode::FrameworkPaths.new('${BUILT_PRODUCTS_DIR}/DebugCompiledFramework/DebugCompiledFramework.framework')

          release_vendored_framework = Xcode::FrameworkPaths.new('${PODS_ROOT}/ReleaseVendoredFramework/ios/ReleaseVendoredFramework.framework',
                                                                 '${PODS_ROOT}/ReleaseVendoredFramework/ios/ReleaseVendoredFramework.framework.dSYM')
          framework_paths_by_config = {
            'Debug' => [debug_vendored_framework, debug_non_vendored_framework],
            'Release' => [release_vendored_framework],
          }
          @pod_bundle.stubs(:framework_paths_by_config => framework_paths_by_config)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          # dSYM and bcsymbolmaps are intentionally excluded as they are handled by a different script phase within
          # the pod target.
          phase.input_paths.sort.should == %w(
            ${BUILT_PRODUCTS_DIR}/DebugCompiledFramework/DebugCompiledFramework.framework
            ${PODS_ROOT}/DebugVendoredFramework/ios/DebugVendoredFramework.framework
            ${PODS_ROOT}/ReleaseVendoredFramework/ios/ReleaseVendoredFramework.framework
            ${PODS_ROOT}/Target\ Support\ Files/Pods/Pods-frameworks.sh
          )
          phase.output_paths.sort.should == %w(
            ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/DebugCompiledFramework.framework
            ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/DebugVendoredFramework.framework
            ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/ReleaseVendoredFramework.framework
          )
        end

        it 'adds embed frameworks build phase input and output paths for vendored and non vendored frameworks without duplicate' do
          debug_vendored_framework = Xcode::FrameworkPaths.new('${PODS_ROOT}/DebugVendoredFramework/ios/SomeFramework.framework',
                                                               '${PODS_ROOT}/DebugVendoredFramework/ios/SomeFramework.framework.dSYM')

          debug_non_vendored_framework = Xcode::FrameworkPaths.new('${BUILT_PRODUCTS_DIR}/DebugCompiledFramework/CompiledFramework.framework')

          release_vendored_framework = Xcode::FrameworkPaths.new('${PODS_ROOT}/ReleaseVendoredFramework/ios/SomeFramework.framework',
                                                                 '${PODS_ROOT}/ReleaseVendoredFramework/ios/SomeFramework.framework.dSYM')

          release_non_vendored_framework = Xcode::FrameworkPaths.new('${BUILT_PRODUCTS_DIR}/ReleaseCompiledFramework/CompiledFramework.framework')

          framework_paths_by_config = {
            'Debug' => [debug_vendored_framework, debug_non_vendored_framework],
            'Release' => [release_vendored_framework, release_non_vendored_framework],
          }
          @pod_bundle.stubs(:framework_paths_by_config => framework_paths_by_config)
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @embed_framework_phase_name }
          phase.input_paths.sort.should == %w(
            ${BUILT_PRODUCTS_DIR}/DebugCompiledFramework/CompiledFramework.framework
            ${BUILT_PRODUCTS_DIR}/ReleaseCompiledFramework/CompiledFramework.framework
            ${PODS_ROOT}/DebugVendoredFramework/ios/SomeFramework.framework
            ${PODS_ROOT}/ReleaseVendoredFramework/ios/SomeFramework.framework
            ${PODS_ROOT}/Target\ Support\ Files/Pods/Pods-frameworks.sh
          )
          phase.output_paths.sort.should == %w(
            ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/CompiledFramework.framework
            ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/SomeFramework.framework
          )
        end

        it 'removes script phases that have been removed from CocoaPods' do
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          TargetIntegrator::REMOVED_SCRIPT_PHASE_NAMES.each do |name|
            phase = target.shell_script_build_phases.find { |bp| bp.name.end_with?(name) }
            phase.should.be.nil?

            phase = target.new_shell_script_build_phase("#{TargetIntegrator::BUILD_PHASE_PREFIX}#{name}")
            phase.should.not.be.nil?
          end

          # Re-integrate and ensure the phases are now removed
          target.new_shell_script_build_phase('[CP] Prepare Artifacts')
          @target_integrator.integrate!
          TargetIntegrator::REMOVED_SCRIPT_PHASE_NAMES.each do |name|
            phase = target.shell_script_build_phases.find { |bp| bp.name.end_with?(name) }
            phase.should.be.nil?
          end
        end

        it 'adds a custom shell script phase' do
          @pod_bundle.target_definition.stubs(:script_phases).returns([:name => 'Custom Script', :script => 'echo "Hello World"'])
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @user_script_phase_name }
          phase.name.should == '[CP-User] Custom Script'
          phase.shell_script.should == 'echo "Hello World"'
          phase.shell_path.should == '/bin/sh'
          phase.input_paths.should.be.nil
          phase.output_paths.should.be.nil
          phase.input_file_list_paths.should.be.nil
          phase.output_file_list_paths.should.be.nil
          phase.show_env_vars_in_log.should.be.nil
          phase.dependency_file.should.be.nil
        end

        it 'adds a custom shell script phase with input/output paths' do
          @pod_bundle.target_definition.stubs(:script_phases).returns([:name => 'Custom Script',
                                                                       :script => 'echo "Hello World"',
                                                                       :input_files => ['/path/to/input_file.txt'],
                                                                       :output_files => ['/path/to/output_file.txt'],
                                                                       :input_file_lists => ['/path/to/input_file.xcfilelist'],
                                                                       :output_file_lists => ['/path/to/output_file.xcfilelist']])
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @user_script_phase_name }
          phase.name.should == '[CP-User] Custom Script'
          phase.shell_script.should == 'echo "Hello World"'
          phase.shell_path.should == '/bin/sh'
          phase.input_paths.should == ['/path/to/input_file.txt']
          phase.output_paths.should == ['/path/to/output_file.txt']
          phase.input_file_list_paths == ['/path/to/input_file.xcfilelist']
          phase.output_file_list_paths.should == ['/path/to/output_file.xcfilelist']
          phase.show_env_vars_in_log.should.be.nil
          phase.dependency_file.should.be.nil
        end

        it 'adds a custom shell script phase with dependency file' do
          @pod_bundle.target_definition.stubs(:script_phases).returns([:name => 'Custom Script',
                                                                       :script => 'echo "Hello World"',
                                                                       :dependency_file => '/path/to/depfile.d'])
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @user_script_phase_name }
          phase.should.not.be.nil?
          phase.name.should == '[CP-User] Custom Script'
          phase.shell_script.should == 'echo "Hello World"'
          phase.shell_path.should == '/bin/sh'
          phase.input_paths.should.be.nil
          phase.output_paths.should.be.nil
          phase.input_file_list_paths.should.be.nil
          phase.output_file_list_paths.should.be.nil
          phase.show_env_vars_in_log.should.be.nil
          phase.dependency_file.should == '/path/to/depfile.d'
        end

        it 'sets the show_env_vars_in_log value to 0 if its explicitly set' do
          @pod_bundle.target_definition.stubs(:script_phases).returns([:name => 'Custom Script',
                                                                       :script => 'echo "Hello World"',
                                                                       :show_env_vars_in_log => '0'])
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @user_script_phase_name }
          phase.should.not.be.nil?
          phase.show_env_vars_in_log.should == '0'
        end

        it 'does not set the show_env_vars_in_log value to 1 even if its set' do
          # Since Xcode 10 this value never gets transcribed into the `.pbxproj` file which causes Xcode 10 to _remove_
          # it if it's been added and causing a dirty file in git repos.
          @pod_bundle.target_definition.stubs(:script_phases).returns([:name => 'Custom Script',
                                                                       :script => 'echo "Hello World"',
                                                                       :show_env_vars_in_log => '1'])
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          phase = target.shell_script_build_phases.find { |bp| bp.name == @user_script_phase_name }
          # Even though the user has set this to '1' we expect this to be `nil`.
          phase.show_env_vars_in_log.should.be.nil
        end

        it 'removes outdated custom shell script phases' do
          @pod_bundle.target_definition.stubs(:script_phases).returns([:name => 'Custom Script', :script => 'echo "Hello World"'])
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          target.shell_script_build_phases.find { |bp| bp.name == @user_script_phase_name }.should.not.be.nil
          @pod_bundle.target_definition.stubs(:script_phases).returns([])
          @target_integrator.integrate!
          target.shell_script_build_phases.find { |bp| bp.name == @user_script_phase_name }.should.be.nil
        end

        it 'moves custom shell scripts according to their execution position' do
          shell_script_one = { :name => 'Custom Script', :script => 'echo "Hello World"', :execution_position => :before_compile }
          shell_script_two = { :name => 'Custom Script 2', :script => 'echo "Hello Aliens"' }
          @pod_bundle.target_definition.stubs(:script_phases).returns([shell_script_one, shell_script_two])
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          target.build_phases.map(&:display_name).should == [
            '[CP] Check Pods Manifest.lock',
            '[CP-User] Custom Script',
            'Sources',
            'Frameworks',
            'Resources',
            '[CP] Embed Pods Frameworks',
            '[CP] Copy Pods Resources',
            '[CP-User] Custom Script 2',
          ]
          shell_script_one = { :name => 'Custom Script', :script => 'echo "Hello World"', :execution_position => :after_compile }
          shell_script_two = { :name => 'Custom Script 2', :script => 'echo "Hello Aliens"', :execution_position => :before_compile }
          @pod_bundle.target_definition.stubs(:script_phases).returns([shell_script_one, shell_script_two])
          @target_integrator.integrate!
          target.build_phases.map(&:display_name).should == [
            '[CP] Check Pods Manifest.lock',
            '[CP-User] Custom Script 2',
            'Sources',
            '[CP-User] Custom Script',
            'Frameworks',
            'Resources',
            '[CP] Embed Pods Frameworks',
            '[CP] Copy Pods Resources',
          ]
          shell_script_one = { :name => 'Custom Script', :script => 'echo "Hello World"' }
          shell_script_two = { :name => 'Custom Script 2', :script => 'echo "Hello Aliens"' }
          @pod_bundle.target_definition.stubs(:script_phases).returns([shell_script_one, shell_script_two])
          @target_integrator.integrate!
          target.build_phases.map(&:display_name).should == [
            '[CP] Check Pods Manifest.lock',
            '[CP-User] Custom Script 2',
            'Sources',
            '[CP-User] Custom Script',
            'Frameworks',
            'Resources',
            '[CP] Embed Pods Frameworks',
            '[CP] Copy Pods Resources',
          ]
        end

        it 'adds, removes and moves custom shell script phases' do
          shell_script_one = { :name => 'Custom Script', :script => 'echo "Hello World"' }
          shell_script_two = { :name => 'Custom Script 2', :script => 'echo "Hello Aliens"' }
          shell_script_three = { :name => 'Custom Script 3', :script => 'echo "Hello Universe"' }
          shell_script_four = { :name => 'Custom Script 4', :script => 'echo "Ran out of Hellos"' }
          @pod_bundle.target_definition.stubs(:script_phases).returns([shell_script_one, shell_script_two, shell_script_three])
          @target_integrator.integrate!
          target = @target_integrator.send(:native_targets).first
          target.build_phases.map(&:display_name).should == [
            '[CP] Check Pods Manifest.lock',
            'Sources',
            'Frameworks',
            'Resources',
            '[CP] Embed Pods Frameworks',
            '[CP] Copy Pods Resources',
            '[CP-User] Custom Script',
            '[CP-User] Custom Script 2',
            '[CP-User] Custom Script 3',
          ]
          @pod_bundle.target_definition.stubs(:script_phases).returns([shell_script_two, shell_script_four])
          @target_integrator.integrate!
          target.build_phases.map(&:display_name).should == [
            '[CP] Check Pods Manifest.lock',
            'Sources',
            'Frameworks',
            'Resources',
            '[CP] Embed Pods Frameworks',
            '[CP] Copy Pods Resources',
            '[CP-User] Custom Script 2',
            '[CP-User] Custom Script 4',
          ]
        end

        it 'does not touch non cocoapods shell script phases' do
          @pod_bundle.target_definition.stubs(:script_phases).returns([:name => 'Custom Script', :script => 'echo "Hello World"'])
          target = @target_integrator.send(:native_targets).first
          target.new_shell_script_build_phase('User Script Phase 1')
          target.new_shell_script_build_phase('User Script Phase 2')
          @target_integrator.integrate!
          target.build_phases.map(&:display_name).should == [
            '[CP] Check Pods Manifest.lock',
            'Sources',
            'Frameworks',
            'Resources',
            'User Script Phase 1',
            'User Script Phase 2',
            '[CP] Embed Pods Frameworks',
            '[CP] Copy Pods Resources',
            '[CP-User] Custom Script',
          ]
          @pod_bundle.target_definition.stubs(:script_phases).returns([])
          @target_integrator.integrate!
          target.build_phases.map(&:display_name).should == [
            '[CP] Check Pods Manifest.lock',
            'Sources',
            'Frameworks',
            'Resources',
            'User Script Phase 1',
            'User Script Phase 2',
            '[CP] Embed Pods Frameworks',
            '[CP] Copy Pods Resources',
          ]
        end
      end

      describe 'Script paths' do
        it 'calculates the output paths of the embed frameworks script' do
          paths = [
            Xcode::FrameworkPaths.new('${PODS_ROOT}/DebugVendoredFramework/ios/SomeFramework.framework',
                                      '${PODS_ROOT}/DebugVendoredFramework/ios/SomeFramework.framework.dSYM'),
            Xcode::FrameworkPaths.new('${BUILT_PRODUCTS_DIR}/DebugCompiledFramework/CompiledFramework.framework'),
            Xcode::FrameworkPaths.new('${PODS_ROOT}/ReleaseVendoredFramework/ios/SomeFramework.framework',
                                      '${PODS_ROOT}/ReleaseVendoredFramework/ios/SomeFramework.framework.dSYM'),
            Xcode::FrameworkPaths.new('${BUILT_PRODUCTS_DIR}/ReleaseCompiledFramework/CompiledFramework.framework'),
          ]
          xcframeworks = [
            Xcode::XCFramework.new(fixture('CoconutLib.xcframework')),
          ]
          xcframeworks[0].stubs(:build_type).returns(BuildType.dynamic_framework)
          TargetIntegrator.embed_frameworks_output_paths(paths, xcframeworks).sort.should == %w(
            ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/CoconutLib.framework
            ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/CompiledFramework.framework
            ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/SomeFramework.framework
          )
        end

        it 'does not include static xcframeworks in the embed frameworks output paths' do
          xcframeworks = [
            Xcode::XCFramework.new(fixture('CoconutLib.xcframework')),
          ]
          xcframeworks[0].stubs(:build_type).returns(BuildType.static_framework)
          TargetIntegrator.embed_frameworks_output_paths([], xcframeworks).should == []
        end

        it 'calculates the output paths of the copy resources script' do
          resource_paths = %w(
            ${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugAssets.xcassets
            ${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugDataModel.xcdatamodeld
            ${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugDataModel.xcdatamodel
            ${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugMappingModel.xcmappingmodel
            ${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugLib.bundle
            ${PODS_CONFIGURATION_BUILD_DIR}/ReleaseLib/ReleaseLib.bundle
            ${PODS_CONFIGURATION_BUILD_DIR}/ReleaseLib/ReleaseLibXIB.xib
            ${PODS_CONFIGURATION_BUILD_DIR}/ReleaseLib/ReleaseLib.storyboard
          )
          TargetIntegrator.resource_output_paths(resource_paths).sort.should == %w(
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/Assets.car
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/DebugDataModel.mom
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/DebugDataModel.momd
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/DebugLib.bundle
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/DebugMappingModel.cdm
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ReleaseLib.bundle
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ReleaseLib.storyboardc
            ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/ReleaseLibXIB.nib
          )
        end
      end

      describe 'Private helpers' do
        it 'returns the native targets associated with the Pod bundle' do
          @target_integrator.send(:native_targets).map(&:name).should == %w( SampleProject          )
        end

        it 'is robust against other types of references in the build files of the frameworks build phase' do
          build_file = @project.new(Xcodeproj::Project::PBXBuildFile)
          build_file.file_ref = @project.new(Xcodeproj::Project::PBXVariantGroup)
          @target_integrator.stubs(:user_project).returns(@project)
          @target.frameworks_build_phase.files << build_file
          @target_integrator.send(:native_targets).map(&:name).should == %w( SampleProject          )
        end

        it 'is robust against build files with missing file references' do
          build_file = @project.new(Xcodeproj::Project::PBXBuildFile)
          build_file.file_ref = nil
          @target_integrator.stubs(:user_project).returns(@project)
          @target.frameworks_build_phase.files << build_file
          @target_integrator.send(:native_targets).map(&:name).should == %w( SampleProject          )
        end
      end
    end
  end
end
