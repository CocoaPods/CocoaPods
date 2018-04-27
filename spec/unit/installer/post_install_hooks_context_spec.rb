require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::PostInstallHooksContext do
    it 'offers a convenience method to be generated' do
      pods_project = Project.new('/path/Pods.xcodeproj')
      sandbox = stub(:root => '/path', :project => pods_project)

      spec = fixture_spec('banana-lib/BananaLib.podspec')
      user_project = Xcodeproj::Project.open(SpecHelper.create_sample_app_copy_from_fixture('SampleProject'))
      user_target = user_project.native_targets.find { |np| np.name == 'SampleProject' }
      target_definition = fixture_target_definition
      pod_target = PodTarget.new(sandbox, false, {}, [], Platform.ios, [spec], [target_definition], nil)
      umbrella = AggregateTarget.new(sandbox, false, {}, [], Platform.ios, target_definition, config.sandbox.root.dirname, user_project, [user_target.uuid], 'Release' => [pod_target])
      umbrella.stubs(:platform).returns(Platform.new(:ios, '8.0'))

      result = Installer::PostInstallHooksContext.generate(sandbox, [umbrella])
      result.class.should == Installer::PostInstallHooksContext
      result.sandbox_root.should == '/path'
      result.pods_project.should == pods_project
      result.sandbox.should == sandbox
      result.umbrella_targets.count.should == 1
      umbrella_target = result.umbrella_targets.first
      umbrella_target.user_targets.should == [user_target]
      umbrella_target.user_target_uuids.should == [user_target.uuid]
      umbrella_target.user_project.should == user_project
      umbrella_target.specs.should == [spec]
      umbrella_target.platform_name.should == :ios
      umbrella_target.platform_deployment_target.should == '8.0'
      umbrella_target.cocoapods_target_label.should == 'Pods'
    end
  end
end
