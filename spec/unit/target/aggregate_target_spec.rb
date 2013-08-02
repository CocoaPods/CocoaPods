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

  end
end
