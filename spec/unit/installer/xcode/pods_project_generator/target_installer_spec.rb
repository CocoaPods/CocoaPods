require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        describe TargetInstaller do
          before do
            @project = Project.new(config.sandbox.project_path)
            user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }
            archs = ['$(ARCHS_STANDARD_64_BIT)']
            @target = Target.new(config.sandbox, BuildType.static_library, user_build_configurations, archs, Platform.ios)
            @installer = TargetInstaller.new(config.sandbox, @project, @target)
          end

          it 'adds the architectures to the custom build configurations of the user target' do
            @installer.send(:add_target).resolved_build_setting('ARCHS').should == {
              'Release' => ['$(ARCHS_STANDARD_64_BIT)'],
              'Debug' => ['$(ARCHS_STANDARD_64_BIT)'],
              'AppStore' => ['$(ARCHS_STANDARD_64_BIT)'],
              'Test' => ['$(ARCHS_STANDARD_64_BIT)'],
            }
          end

          it 'always clears the OTHER_LDFLAGS and OTHER_LIBTOOLFLAGS, because these lib targets do not ever need any' do
            native_target = @installer.send(:add_target)
            native_target.resolved_build_setting('OTHER_LDFLAGS').values.uniq.should == ['']
            native_target.resolved_build_setting('OTHER_LIBTOOLFLAGS').values.uniq.should == ['']
          end

          it 'adds Swift-specific build settings to the build settings' do
            @target.stubs(:requires_frameworks?).returns(true)
            @target.stubs(:uses_swift?).returns(true)
            @installer.send(:add_target).resolved_build_setting('SWIFT_OPTIMIZATION_LEVEL').should == {
              'Release' => '-O',
              'Debug' => '-Onone',
              'Test' => nil,
              'AppStore' => nil,
            }
            @installer.send(:add_target).resolved_build_setting('SWIFT_COMPILATION_MODE').should == {
              'Release' => 'wholemodule',
              'Debug' => nil,
              'Test' => nil,
              'AppStore' => nil,
            }
            @installer.send(:add_target).resolved_build_setting('SWIFT_ACTIVE_COMPILATION_CONDITIONS').should == {
              'Release' => nil,
              'Debug' => 'DEBUG',
              'Test' => nil,
              'AppStore' => nil,
            }
          end

          it 'verify static framework is building a static library' do
            @target.stubs(:build_type => BuildType.static_framework)
            @installer.send(:add_target).resolved_build_setting('MACH_O_TYPE').should == {
              'Release' => 'staticlib',
              'Debug' => 'staticlib',
              'Test' => 'staticlib',
              'AppStore' => 'staticlib',
            }
          end

          describe '#create_module_map' do
            it 'uses relative paths when linking umbrella headers' do
              @installer.stubs(:update_changed_file)
              @installer.stubs(:add_file_to_support_group)
              write_path = Pathname.new('/Pods/Target Support Files/MyPod/MyPod.modulemap')
              target_module_path = Pathname.new('/Pods/Headers/Public/MyPod/MyPod.modulemap')
              relative_path = Pathname.new('../../../Target Support Files/MyPod/MyPod.modulemap')

              @target.stubs(:module_map_path_to_write).returns(write_path)
              @target.stubs(:module_map_path).returns(target_module_path)
              Pathname.any_instance.stubs(:mkpath)

              FileUtils.expects(:ln_sf).with(relative_path, target_module_path)
              native_target = mock(:build_configurations => [])
              @installer.send(:create_module_map, native_target)
            end
          end

          describe '#create_umbrella_header' do
            it 'uses relative paths when linking umbrella headers' do
              @installer.stubs(:update_changed_file)
              @installer.stubs(:add_file_to_support_group)
              write_path = Pathname.new('/Pods/Target Support Files/MyPod/MyPod-Umbrella.h')
              target_header_path = Pathname.new('/Pods/Headers/Public/MyPod/MyPod-Umbrella.h')
              relative_path = Pathname.new('../../../Target Support Files/MyPod/MyPod-Umbrella.h')

              @target.stubs(:umbrella_header_path_to_write).returns(write_path)
              @target.stubs(:umbrella_header_path).returns(target_header_path)
              Pathname.any_instance.stubs(:mkpath)

              mock_build_file = Struct.new(:settings).new
              mock_build_phase = mock
              mock_build_phase.stubs(:add_file_reference).returns(mock_build_file)

              native_target = mock
              native_target.stubs(:headers_build_phase).returns(mock_build_phase)

              FileUtils.expects(:ln_sf).with(relative_path, target_header_path)

              @installer.send(:create_umbrella_header, native_target)
            end
          end
        end
      end
    end
  end
end
