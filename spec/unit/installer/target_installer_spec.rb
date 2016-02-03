require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::TargetInstaller do
    before do
      @podfile = Podfile.new do
        platform :ios
        project 'SampleProject/SampleProject'
        target 'SampleProject'
      end
      @target_definition = @podfile.target_definitions['SampleProject']
      @project = Project.new(config.sandbox.project_path)

      config.sandbox.project = @project
      path_list = Sandbox::PathList.new(fixture('banana-lib'))
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      file_accessor = Sandbox::FileAccessor.new(path_list, @spec.consumer(:ios))
      @project.add_pod_group('BananaLib', fixture('banana-lib'))
      group = @project.group_for_spec('BananaLib')
      file_accessor.source_files.each do |file|
        @project.add_file_reference(file, group)
      end

      @pod_target = PodTarget.new([@spec], [@target_definition], config.sandbox)
      @pod_target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
      @pod_target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }
      @pod_target.file_accessors = [file_accessor]

      @installer = Installer::TargetInstaller.new(config.sandbox, @pod_target)
    end

    it 'adds the architectures to the custom build configurations of the user target' do
      @pod_target.archs = '$(ARCHS_STANDARD_64_BIT)'
      @installer.send(:add_target)
      @installer.send(:native_target).resolved_build_setting('ARCHS').should == {
        'Release' => '$(ARCHS_STANDARD_64_BIT)',
        'Debug' => '$(ARCHS_STANDARD_64_BIT)',
        'AppStore' => '$(ARCHS_STANDARD_64_BIT)',
        'Test' => '$(ARCHS_STANDARD_64_BIT)',
      }
    end

    it 'always clears the OTHER_LDFLAGS and OTHER_LIBTOOLFLAGS, because these lib targets do not ever need any' do
      @installer.send(:add_target)
      @installer.send(:native_target).resolved_build_setting('OTHER_LDFLAGS').values.uniq.should == ['']
      @installer.send(:native_target).resolved_build_setting('OTHER_LIBTOOLFLAGS').values.uniq.should == ['']
    end

    it 'adds Swift-specific build settings to the build settings' do
      @pod_target.stubs(:requires_frameworks?).returns(true)
      @pod_target.stubs(:uses_swift?).returns(true)
      @installer.send(:add_target)
      @installer.send(:native_target).resolved_build_setting('SWIFT_OPTIMIZATION_LEVEL').should == {
        'Release' => nil,
        'Debug' => '-Onone',
        'Test' => nil,
        'AppStore' => nil,
      }
    end
  end
end
