require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe AggregateTarget do
    describe "In general" do
      before do
        @target_definition = Podfile::TargetDefinition.new('Pods', nil)
        @target_definition.link_with_first_target = true
        @target = AggregateTarget.new(@target_definition, config.sandbox)
      end

      it "returns the target_definition that generated it" do
        @target.target_definition.should == @target_definition
      end

      it "returns the label of the target definition" do
        @target.label.should == 'Pods'
      end

      it "returns its name" do
        @target.name.should == 'Pods'
      end

      it "returns the name of its product" do
        @target.product_name.should == 'libPods.a'
      end
    end

    describe "Support files" do
      before do
        @target_definition = Podfile::TargetDefinition.new('Pods', nil)
        @target_definition.link_with_first_target = true
        @target = AggregateTarget.new(@target_definition, config.sandbox)
        @target.client_root = config.sandbox.root.dirname
      end

      it "returns the absolute path of the xcconfig file" do
        @target.xcconfig_path.to_s.should.include?('Pods/Pods.xcconfig')
      end

      it "returns the absolute path of the resources script" do
        @target.copy_resources_script_path.to_s.should.include?('Pods/Pods-resources.sh')
      end

      it "returns the absolute path of the target header file" do
        @target.target_environment_header_path.to_s.should.include?('Pods/Pods-environment.h')
      end

      it "returns the absolute path of the prefix header file" do
        @target.prefix_header_path.to_s.should.include?('Pods/Pods-prefix.pch')
      end

      it "returns the absolute path of the bridge support file" do
        @target.bridge_support_path.to_s.should.include?('Pods/Pods.bridgesupport')
      end

      it "returns the absolute path of the acknowledgements files without extension" do
        @target.acknowledgements_basepath.to_s.should.include?('Pods/Pods-acknowledgements')
      end

      #--------------------------------------#

      it "returns the path of the resources script relative to the user project" do
        @target.copy_resources_script_relative_path.should == '${SRCROOT}/Pods/Pods-resources.sh'
      end

      it "returns the path of the xcconfig file relative to the user project" do
        @target.xcconfig_relative_path.should == 'Pods/Pods.xcconfig'
      end
    end

    describe "Pod targets" do
      before do
        spec = fixture_spec('banana-lib/BananaLib.podspec')
        target_definition = Podfile::TargetDefinition.new('Pods', nil)
        pod_target = PodTarget.new([spec], target_definition, config.sandbox)
        @target = AggregateTarget.new(target_definition, config.sandbox)
        @target.stubs(:platform).returns(:ios)
        @target.pod_targets = [pod_target]
      end

      it "returns the specs of the Pods used by this aggregate target" do
        @target.specs.map(&:name).should == ["BananaLib"]
      end

      it "returns the spec consumers for the pod targets" do
        consumer_reps = @target.spec_consumers.map { |consumer| [consumer.spec.name, consumer.platform_name ] }
        consumer_reps.should == [["BananaLib", :ios]]
      end
    end

    #-------------------------------------------------------------------------#

    describe "Transitional Methods" do

      before do
        @target_definition = Podfile::TargetDefinition.new('Pods', nil)
        @target_definition.stubs(:platform).returns(Platform.new(:ios, '7.0'))
        @sut = AggregateTarget.new(@target_definition, config.sandbox)
        @sut.user_project_path = 'SampleProject/SampleProject'
        @sut.user_target_uuids = ["A346496C14F9BE9A0080D870"]
        @spec = fixture_spec('banana-lib/BananaLib.podspec')
        @sut.stubs(:specs).returns([@spec])
      end

      it "returns the description of the user targets" do
        expected = [{
          :uuid=>"A346496C14F9BE9A0080D870",
          :user_project_path=>"SampleProject/SampleProject",
          :specs=>[@spec],
          :platform_name=>:ios,
          :platform_deployment_target=>"7.0"
        }]
        @sut.user_target_descriptions.should == expected
      end
    end

    #-------------------------------------------------------------------------#

  end
end
