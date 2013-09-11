require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Target do
    before do
      @target_definition = Podfile::TargetDefinition.new('Pods', nil)
      @target_definition.link_with_first_target = true
      @lib = AggregateTarget.new(@target_definition, config.sandbox)
    end

    it "returns the target_definition that generated it" do
      @lib.target_definition.should == @target_definition
    end

    it "returns the label of the target definition" do
      @lib.label.should == 'Pods'
    end

    it "returns its name" do
      @lib.name.should == 'Pods'
    end

    it "returns the name of its product" do
      @lib.product_name.should == 'libPods.a'
    end
  end
end
