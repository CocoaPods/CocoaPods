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
        @target.xcconfig_path.to_s.should.include?('Pods/Generated/Pods.xcconfig')
      end

      it "returns the absolute path of the resources script" do
        @target.copy_resources_script_path.to_s.should.include?('Pods/Generated/Pods-resources.sh')
      end

      it "returns the absolute path of the target header file" do
        @target.target_environment_header_path.to_s.should.include?('Pods/Generated/Pods-environment.h')
      end

      it "returns the absolute path of the prefix header file" do
        @target.prefix_header_path.to_s.should.include?('Pods/Generated/Pods-prefix.pch')
      end

      it "returns the absolute path of the bridge support file" do
        @target.bridge_support_path.to_s.should.include?('Pods/Generated/Pods.bridgesupport')
      end

      it "returns the absolute path of the acknowledgements files without extension" do
        @target.acknowledgements_basepath.to_s.should.include?('Pods/Generated/Pods-acknowledgements')
      end

      #--------------------------------------#

      it "returns the path of the resources script relative to the user project" do
        @target.copy_resources_script_relative_path.should == '${SRCROOT}/Pods/Generated/Pods-resources.sh'
      end

      it "returns the path of the xcconfig file relative to the user project" do
        @target.xcconfig_relative_path.should == 'Pods/Generated/Pods.xcconfig'
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

      it "returns the spec consumers for the pod targets" do
        @target.spec_consumers.should.not == nil
      end
    end

  end
end
