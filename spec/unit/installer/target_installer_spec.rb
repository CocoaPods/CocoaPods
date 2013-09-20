require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::TargetInstaller do

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

      @installer = Installer::TargetInstaller.new(config.sandbox, @pod_target)
    end

  end
end
