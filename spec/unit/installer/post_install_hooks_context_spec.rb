require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::PostInstallHooksContext do
    it 'offers a convenience method to be generated' do
      pods_project = Project.new('/path/Pods.xcodeproj')
      sandbox = stub(:root => '/path', :project => pods_project)

      spec = fixture_spec('banana-lib/BananaLib.podspec')
      user_project = Xcodeproj::Project.open(SpecHelper.create_sample_app_copy_from_fixture('SampleProject'))
      target_definition = Podfile::TargetDefinition.new('Pods', nil)
      pod_target = PodTarget.new([spec], [target_definition], config.sandbox)
      umbrella = AggregateTarget.new(target_definition, config.sandbox)
      umbrella.user_project = user_project
      umbrella.user_target_uuids = ['UUID']
      umbrella.stubs(:platform).returns(Platform.new(:ios, '8.0'))
      umbrella.pod_targets = [pod_target]

      result = Installer::PostInstallHooksContext.generate(sandbox, [umbrella])
      result.class.should == Installer::PostInstallHooksContext
      result.sandbox_root.should == '/path'
      result.pods_project.should == pods_project
      result.umbrella_targets.count.should == 1
      umbrella_target = result.umbrella_targets.first
      umbrella_target.user_target_uuids.should == ['UUID']
      umbrella_target.user_project.should == user_project
      umbrella_target.specs.should == [spec]
      umbrella_target.platform_name.should == :ios
      umbrella_target.platform_deployment_target.should == '8.0'
      umbrella_target.cocoapods_target_label.should == 'Pods'
    end
  end
end
