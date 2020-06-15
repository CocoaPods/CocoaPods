require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        class PodTargetIntegrator
          describe 'In general' do
            before do
              @project = Pod::Project.new(config.sandbox.project_path)
              @project.save
              @target_definition = fixture_target_definition

              @watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
              @watermelon_pod_target = fixture_pod_target_with_specs([@watermelon_spec,
                                                                      *@watermelon_spec.recursive_subspecs],
                                                                     BuildType.dynamic_framework, {}, [], Platform.ios,
                                                                     [@target_definition])

              @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
              @coconut_pod_target = fixture_pod_target_with_specs([@coconut_spec, *@coconut_spec.recursive_subspecs],
                                                                  BuildType.dynamic_framework, {}, [], Platform.ios,
                                                                  [@target_definition])

              @native_target = stub('NativeTarget', :shell_script_build_phases => [], :build_phases => [],
                                                    :project => @project)
              @test_native_target = stub('TestNativeTarget', :symbol_type => :unit_test_bundle, :build_phases => [],
                                                             :shell_script_build_phases => [], :project => @project,
                                                             :name => 'CoconutLib-Unit-Tests')

              @coconut_target_installation_result = TargetInstallationResult.new(@coconut_pod_target, @native_target,
                                                                                 [], [@test_native_target])
            end

            describe '#integrate!' do
              it 'integrates test native targets with framework script phase' do
                PodTargetIntegrator.new(@coconut_target_installation_result).integrate!
                @test_native_target.build_phases.count.should == 1
                @test_native_target.build_phases.map(&:display_name).should == [
                  '[CP] Embed Pods Frameworks',
                ]
                @test_native_target.build_phases[0].shell_script.should == "\"${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-frameworks.sh\"\n"
              end

              it 'clears input and output paths from script phase if it exceeds limit' do
                # The paths represented here will be 501 for input paths and 501 for output paths
                # which will exceed the limit.
                resource_paths = (0..500).map do |i|
                  "${PODS_CONFIGURATION_BUILD_DIR}/DebugLib/DebugLibPng#{i}.png"
                end
                @coconut_pod_target.stubs(:resource_paths).returns('CoconutLib' => resource_paths)
                PodTargetIntegrator.new(@coconut_target_installation_result).integrate!
                @test_native_target.build_phases.map(&:display_name).should == [
                  '[CP] Embed Pods Frameworks',
                  '[CP] Copy Pods Resources',
                ]
                @test_native_target.build_phases[1].input_paths.should == []
                @test_native_target.build_phases[1].output_paths.should == []
              end

              it 'integrates test native targets with frameworks and resources script phase input and output paths' do
                framework_paths = [Pod::Xcode::FrameworkPaths.new('${PODS_ROOT}/Vendored/Vendored.framework')]
                resource_paths = ['${PODS_CONFIGURATION_BUILD_DIR}/TestResourceBundle.bundle']
                @coconut_pod_target.stubs(:framework_paths).returns('CoconutLib' => framework_paths)
                @coconut_pod_target.stubs(:resource_paths).returns('CoconutLib' => resource_paths)
                PodTargetIntegrator.new(@coconut_target_installation_result, :use_input_output_paths => true).integrate!
                @test_native_target.build_phases.count.should == 2
                @test_native_target.build_phases.map(&:display_name).should == [
                  '[CP] Embed Pods Frameworks',
                  '[CP] Copy Pods Resources',
                ]
                @test_native_target.build_phases[0].input_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-frameworks.sh',
                  '${PODS_ROOT}/Vendored/Vendored.framework',
                ]
                @test_native_target.build_phases[0].output_paths.should == [
                  '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/Vendored.framework',
                ]
                @test_native_target.build_phases[1].input_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-resources.sh',
                  '${PODS_CONFIGURATION_BUILD_DIR}/TestResourceBundle.bundle',
                ]
                @test_native_target.build_phases[1].output_paths.should == [
                  '${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/TestResourceBundle.bundle',
                ]
              end

              it 'integrates test native targets with frameworks and resource script phase input and output file lists' do
                @project.root_object.stubs(:compatibility_version).returns('Xcode 9.10')
                framework_paths = [Pod::Xcode::FrameworkPaths.new('${PODS_ROOT}/Vendored/Vendored.framework')]
                resource_paths = ['${PODS_CONFIGURATION_BUILD_DIR}/TestResourceBundle.bundle']
                @coconut_pod_target.stubs(:framework_paths).returns('CoconutLib' => framework_paths)
                @coconut_pod_target.stubs(:resource_paths).returns('CoconutLib' => resource_paths)
                PodTargetIntegrator.new(@coconut_target_installation_result, :use_input_output_paths => true).integrate!
                @test_native_target.build_phases.count.should == 2
                @test_native_target.build_phases.map(&:display_name).should == [
                  '[CP] Embed Pods Frameworks',
                  '[CP] Copy Pods Resources',
                ]
                @test_native_target.build_phases[0].input_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-frameworks-input-files.xcfilelist',
                ]
                @test_native_target.build_phases[0].output_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-frameworks-output-files.xcfilelist',
                ]
                @test_native_target.build_phases[1].input_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-resources-input-files.xcfilelist',
                ]
                @test_native_target.build_phases[1].output_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-resources-output-files.xcfilelist',
                ]
              end

              it 'integrates input and output file lists using objectVersion when compatibility version not parsed' do
                @project.root_object.stubs(:compatibility_version).returns('Xcode unexpected value')
                @project.stubs(:object_version).returns('50')
                framework_paths = [Pod::Xcode::FrameworkPaths.new('${PODS_ROOT}/Vendored/Vendored.framework')]
                resource_paths = ['${PODS_CONFIGURATION_BUILD_DIR}/TestResourceBundle.bundle']
                @coconut_pod_target.stubs(:framework_paths).returns('CoconutLib' => framework_paths)
                @coconut_pod_target.stubs(:resource_paths).returns('CoconutLib' => resource_paths)
                PodTargetIntegrator.new(@coconut_target_installation_result, :use_input_output_paths => true).integrate!
                @test_native_target.build_phases.count.should == 2
                @test_native_target.build_phases.map(&:display_name).should == [
                  '[CP] Embed Pods Frameworks',
                  '[CP] Copy Pods Resources',
                ]
                @test_native_target.build_phases[0].input_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-frameworks-input-files.xcfilelist',
                ]
                @test_native_target.build_phases[0].output_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-frameworks-output-files.xcfilelist',
                ]
                @test_native_target.build_phases[1].input_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-resources-input-files.xcfilelist',
                ]
                @test_native_target.build_phases[1].output_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/CoconutLib/CoconutLib-Unit-Tests-resources-output-files.xcfilelist',
                ]
              end

              it 'integrates test native targets with frameworks, xcframeworks, and resource script phase input and output file lists' do
                @project.root_object.stubs(:compatibility_version).returns('Xcode 9.3')
                framework_paths = [Pod::Xcode::FrameworkPaths.new('${PODS_ROOT}/Vendored/Vendored.framework')]
                resource_paths = ['${PODS_CONFIGURATION_BUILD_DIR}/TestResourceBundle.bundle']
                @watermelon_pod_target.stubs(:framework_paths).returns('WatermelonLib' => framework_paths)
                @watermelon_pod_target.stubs(:resource_paths).returns('WatermelonLib' => resource_paths)
                @watermelon_pod_target.stubs(:xcframeworks).returns('WatermelonLib' => [Pod::Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))])
                test_native_target = stub('TestNativeTarget', :symbol_type => :unit_test_bundle, :build_phases => [],
                                                              :shell_script_build_phases => [], :project => @project,
                                                              :name => 'WatermelonLib-Unit-Tests')
                installation_result = TargetInstallationResult.new(@watermelon_pod_target, @native_target,
                                                                   [], [test_native_target])
                PodTargetIntegrator.new(installation_result, :use_input_output_paths => true).integrate!
                test_native_target.build_phases.map(&:display_name).should == [
                  '[CP] Embed Pods Frameworks',
                  '[CP] Copy Pods Resources',
                ]
                test_native_target.build_phases[0].input_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-frameworks-input-files.xcfilelist',
                ]
                test_native_target.build_phases[0].output_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-frameworks-output-files.xcfilelist',
                ]
                test_native_target.build_phases[1].input_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-resources-input-files.xcfilelist',
                ]
                test_native_target.build_phases[1].output_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-resources-output-files.xcfilelist',
                ]
              end

              it 'integrates frameworks, xcframeworks, with input and output file lists when compatibilityVersion nil' do
                @project.root_object.stubs(:compatibility_version).returns(nil)
                @project.stubs(:object_version).returns('50')
                framework_paths = [Pod::Xcode::FrameworkPaths.new('${PODS_ROOT}/Vendored/Vendored.framework')]
                resource_paths = ['${PODS_CONFIGURATION_BUILD_DIR}/TestResourceBundle.bundle']
                @watermelon_pod_target.stubs(:framework_paths).returns('WatermelonLib' => framework_paths)
                @watermelon_pod_target.stubs(:resource_paths).returns('WatermelonLib' => resource_paths)
                @watermelon_pod_target.stubs(:xcframeworks).returns('WatermelonLib' => [Pod::Xcode::XCFramework.new(fixture('CoconutLib.xcframework'))])
                test_native_target = stub('TestNativeTarget', :symbol_type => :unit_test_bundle, :build_phases => [],
                                                              :shell_script_build_phases => [], :project => @project,
                                                              :name => 'WatermelonLib-Unit-Tests')
                installation_result = TargetInstallationResult.new(@watermelon_pod_target, @native_target,
                                                                   [], [test_native_target])
                PodTargetIntegrator.new(installation_result, :use_input_output_paths => true).integrate!
                test_native_target.build_phases.map(&:display_name).should == [
                  '[CP] Embed Pods Frameworks',
                  '[CP] Copy Pods Resources',
                ]
                test_native_target.build_phases[0].input_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-frameworks-input-files.xcfilelist',
                ]
                test_native_target.build_phases[0].output_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-frameworks-output-files.xcfilelist',
                ]
                test_native_target.build_phases[1].input_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-resources-input-files.xcfilelist',
                ]
                test_native_target.build_phases[1].output_file_list_paths.should == [
                  '${PODS_ROOT}/Target Support Files/WatermelonLib/WatermelonLib-Unit-Tests-resources-output-files.xcfilelist',
                ]
              end

              it 'does not include input output paths when use_input_output_paths is false' do
                framework_paths = [Pod::Xcode::FrameworkPaths.new('${PODS_ROOT}/Vendored/Vendored.framework')]
                resource_paths = ['${PODS_CONFIGURATION_BUILD_DIR}/TestResourceBundle.bundle']
                @coconut_pod_target.stubs(:framework_paths).returns('CoconutLib' => framework_paths)
                @coconut_pod_target.stubs(:resource_paths).returns('CoconutLib' => resource_paths)
                PodTargetIntegrator.new(@coconut_target_installation_result, :use_input_output_paths => false).integrate!
                PodTargetIntegrator.new(@coconut_target_installation_result, :use_input_output_paths => false).integrate!
                @test_native_target.build_phases.count.should == 2
                @test_native_target.build_phases.map(&:display_name).should == [
                  '[CP] Embed Pods Frameworks',
                  '[CP] Copy Pods Resources',
                ]
                @test_native_target.build_phases[0].input_paths.should.be.empty
                @test_native_target.build_phases[0].output_paths.should.be.empty
                @test_native_target.build_phases[1].input_paths.should.be.empty
                @test_native_target.build_phases[1].output_paths.should.be.empty
              end

              it 'excludes test framework and resource paths from dependent targets when using static libraries' do
                @watermelon_pod_target.stubs(:build_type).returns(BuildType.static_library)
                @coconut_pod_target.stubs(:build_type).returns(BuildType.static_library)
                @coconut_pod_target.stubs(:dependent_targets).returns([@watermelon_pod_target])
                PodTargetIntegrator.new(@coconut_target_installation_result).integrate!
                @test_native_target.build_phases.count.should == 0
              end

              it 'integrates test native target with shell script phases' do
                @coconut_spec.test_specs.first.script_phase = { :name => 'Hello World',
                                                                :script => 'echo "Hello World"' }
                PodTargetIntegrator.new(@coconut_target_installation_result).integrate!
                @test_native_target.build_phases.count.should == 2
                @test_native_target.build_phases[1].display_name.should == '[CP-User] Hello World'
                @test_native_target.build_phases[1].shell_script.should == 'echo "Hello World"'
              end

              it 'integrates native target with shell script phases' do
                @coconut_spec.script_phase = { :name => 'Hello World', :script => 'echo "Hello World"' }
                PodTargetIntegrator.new(@coconut_target_installation_result).integrate!
                @native_target.build_phases.count.should == 1
                @native_target.build_phases[0].display_name.should == '[CP-User] Hello World'
                @native_target.build_phases[0].shell_script.should == 'echo "Hello World"'
              end

              describe 'integrating paths with custom app host' do
                before do
                  @pineapple_spec = fixture_spec('pineapple-lib/PineappleLib.podspec')
                  @pineapple_pod_target = fixture_pod_target_with_specs([@pineapple_spec,
                                                                         *@pineapple_spec.recursive_subspecs],
                                                                        BuildType.dynamic_framework, {}, [],
                                                                        Platform.ios, [@target_definition])

                  @native_target = stub('NativeTarget', :shell_script_build_phases => [], :build_phases => [],
                                                        :project => @project)

                  @test_native_target = stub('TestNativeTarget', :symbol_type => :unit_test_bundle, :build_phases => [],
                                                                 :shell_script_build_phases => [], :project => @project,
                                                                 :name => 'PineappleLib-Unit-Tests')

                  @ui_test_native_target = stub('UITestNativeTarget', :symbol_type => :unit_test_bundle,
                                                                      :build_phases => [], :shell_script_build_phases => [],
                                                                      :project => @project, :name => 'PineappleLib-UI-UI')

                  @target_installation_result = TargetInstallationResult.new(@pineapple_pod_target, @native_target, [],
                                                                             [@test_native_target, @ui_test_native_target])

                  @app_host_spec = @pineapple_pod_target.app_specs.find { |t| t.base_name == 'App' }

                  @pineapple_pod_target.test_app_hosts_by_spec = {
                    @pineapple_spec.subspec_by_name('PineappleLib/Tests', true, true) => [@app_host_spec, @pineapple_pod_target],
                    @pineapple_spec.subspec_by_name('PineappleLib/UI', true, true) => [@app_host_spec, @pineapple_pod_target],
                  }
                end

                it 'excludes framework paths for unit type test specs' do
                  PodTargetIntegrator.new(@target_installation_result).integrate!
                  @test_native_target.build_phases.count.should == 0
                end

                it 'includes framework paths for ui type test specs' do
                  PodTargetIntegrator.new(@target_installation_result).integrate!
                  @ui_test_native_target.build_phases.count.should == 1
                  @ui_test_native_target.build_phases.map(&:display_name).should == [
                    '[CP] Embed Pods Frameworks',
                  ]
                  @ui_test_native_target.build_phases[0].input_paths.should == [
                    '${PODS_ROOT}/Target Support Files/PineappleLib/PineappleLib-UI-UI-frameworks.sh',
                    '${BUILT_PRODUCTS_DIR}/PineappleLib/PineappleLib.framework',
                  ]
                  @ui_test_native_target.build_phases[0].output_paths.should == [
                    '${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/PineappleLib.framework',
                  ]
                end

                it 'integrates native target with copy dSYM script phase' do
                  framework_paths = [Pod::Xcode::FrameworkPaths.new('${PODS_ROOT}/Vendored/Vendored.framework',
                                                                    '${PODS_ROOT}/Vendored/Vendored.framework.dSYM',
                                                                    ['${PODS_ROOT}/Vendored/7724D6B4-C7DD-31F0-80C6-EE818ED30B07.bcsymbolmap'])]
                  @watermelon_pod_target.stubs(:framework_paths).returns('WatermelonLib' => framework_paths)
                  installation_result = TargetInstallationResult.new(@watermelon_pod_target, @native_target, [], [])
                  PodTargetIntegrator.new(installation_result, :use_input_output_paths => true).integrate!
                  @native_target.build_phases.count.should == 1
                  @native_target.build_phases.map(&:display_name).should == [
                    '[CP] Copy dSYMs',
                  ]
                  @native_target.build_phases[0].input_paths.should == [
                    '${PODS_ROOT}/Vendored/Vendored.framework.dSYM',
                    '${PODS_ROOT}/Vendored/7724D6B4-C7DD-31F0-80C6-EE818ED30B07.bcsymbolmap',
                  ]
                  @native_target.build_phases[0].output_paths.should == [
                    '${DWARF_DSYM_FOLDER_PATH}/Vendored.framework.dSYM',
                    '${DWARF_DSYM_FOLDER_PATH}/7724D6B4-C7DD-31F0-80C6-EE818ED30B07.bcsymbolmap',
                  ]
                end

                it 'integrates native target with copy dSYM script phase and xcfilelists' do
                  @project.root_object.stubs(:compatibility_version).returns('Xcode 10.0')
                  framework_paths = [Pod::Xcode::FrameworkPaths.new('${PODS_ROOT}/Vendored/Vendored.framework',
                                                                    '${PODS_ROOT}/Vendored/Vendored.framework.dSYM',
                                                                    ['${PODS_ROOT}/Vendored/7724D6B4-C7DD-31F0-80C6-EE818ED30B07.bcsymbolmap'])]
                  @watermelon_pod_target.stubs(:framework_paths).returns('WatermelonLib' => framework_paths)
                  installation_result = TargetInstallationResult.new(@watermelon_pod_target, @native_target, [], [])
                  PodTargetIntegrator.new(installation_result, :use_input_output_paths => true).integrate!
                  @native_target.build_phases.count.should == 1
                  @native_target.build_phases.map(&:display_name).should == [
                    '[CP] Copy dSYMs',
                  ]
                  @native_target.build_phases[0].input_file_list_paths.should == [
                    '${PODS_ROOT}/Target Support Files/WatermelonLib/WatermelonLib-copy-dsyms-input-files.xcfilelist',
                  ]
                  @native_target.build_phases[0].output_file_list_paths.should == [
                    '${PODS_ROOT}/Target Support Files/WatermelonLib/WatermelonLib-copy-dsyms-output-files.xcfilelist',
                  ]
                end
              end
            end
          end
        end
      end
    end
  end
end
