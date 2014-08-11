
require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::HooksContext do
    it "offers a convenience method to be generated" do
      sandbox = stub(:root => '/path')

      spec = fixture_spec('banana-lib/BananaLib.podspec')
      target_definition = Podfile::TargetDefinition.new('Pods', nil)
      pod_target = PodTarget.new([spec], target_definition, config.sandbox)
      umbrella = AggregateTarget.new(target_definition, config.sandbox)
      umbrella.user_project_path = '/path/project.xcodeproj'
      umbrella.user_target_uuids = ['UUID']
      umbrella.stubs(:platform).returns(Platform.new(:ios, '8.0'))
      umbrella.pod_targets = [pod_target]

      result = Installer::HooksContext.generate(sandbox, [umbrella])
      result.class.should == Installer::HooksContext
      result.sandbox_root.should == '/path'
      result.umbrella_targets.count.should == 1
      umbrella_target = result.umbrella_targets.first
      umbrella_target.user_target_uuids.should == ['UUID']
      umbrella_target.user_project_path.should == '/path/project.xcodeproj'
      umbrella_target.specs.should == [spec]
      umbrella_target.platform_name.should == :ios
      umbrella_target.platform_deployment_target.should == '8.0'
      umbrella_target.cocoapods_target_label.should == 'Pods'
    end
  end
end
