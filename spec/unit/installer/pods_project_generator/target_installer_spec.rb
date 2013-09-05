require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodsProjectGenerator::TargetInstaller do

    before do
      @podfile = Podfile.new do
        platform :ios
        xcodeproj 'dummy'
      end
      @target_definition = @podfile.target_definitions['Pods']
      @project = Project.new(config.sandbox.project_path)

      config.sandbox.project = @project
      path_list = Sandbox::PathList.new(fixture('banana-lib'))
      @spec = fixture_spec('banana-lib/BananaLib.podspec')
      file_accessor = Sandbox::FileAccessor.new(path_list, @spec.consumer(:ios))
      @project.add_pod_group('BananaLib', fixture('banana-lib'))
      group = @project.group_for_spec('BananaLib', :source_files)
      file_accessor.source_files.each do |file|
        @project.add_file_reference(file, group)
      end

      @pod_target = PodTarget.new([@spec], @target_definition, config.sandbox)
      @pod_target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
      @pod_target.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }
      @pod_target.file_accessors = [file_accessor]

      @installer = Installer::PodsProjectGenerator::TargetInstaller.new(config.sandbox, @pod_target)
    end

    it "sets the ARCHS" do
      @installer.send(:add_target)
      target = @project.targets.first
      target.build_settings('Debug')["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
      target.build_settings('AppStore')["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
      target.build_settings('Debug')["ONLY_ACTIVE_ARCH"].should.be.nil
      target.build_settings('AppStore')["ONLY_ACTIVE_ARCH"].should.be.nil
    end

    it "sets ARCHS to 'armv6 armv7' for both configurations if the deployment target is less than 4.3 for iOS targets" do
      @pod_target.stubs(:platform).returns(Platform.new(:ios, '4.0'))
      @installer.send(:add_target)
      target = @project.targets.first
      target.build_settings('Debug')["ARCHS"].should == "armv6 armv7"
      target.build_settings('Release')["ARCHS"].should == "armv6 armv7"
    end

  end
end
