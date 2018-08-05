require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        describe TargetInstaller do
          before do
            @project = Project.new(config.sandbox.project_path)
            config.sandbox.project = @project
            user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }
            archs = ['$(ARCHS_STANDARD_64_BIT)']
            @target = Target.new(config.sandbox, false, user_build_configurations, archs, Platform.ios)
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
            @target.stubs(:requires_frameworks?).returns(true)
            @target.stubs(:static_framework?).returns(true)
            @installer.send(:add_target).resolved_build_setting('MACH_O_TYPE').should == {
              'Release' => 'staticlib',
              'Debug' => 'staticlib',
              'Test' => 'staticlib',
              'AppStore' => 'staticlib',
            }
          end
        end
      end
    end
  end
end
