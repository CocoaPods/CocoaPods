require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Hooks::LibraryRepresentation do

    before do
      @target_definition = Podfile::TargetDefinition.new('MyApp', nil)
      @spec = Spec.new
      @spec.name = 'RestKit'
      @lib = AggregateTarget.new(@target_definition, config.sandbox)
      @rep = Hooks::LibraryRepresentation.new(config.sandbox, @lib)
    end

    #-------------------------------------------------------------------------#

    describe "Public Hooks API" do

      it "returns the name" do
        @rep.name.should == 'Pods-MyApp'
      end

      it "returns the dependencies" do
        @target_definition.store_pod('AFNetworking')
        @rep.dependencies.should == [Dependency.new('AFNetworking')]
      end

      it "returns the sandbox dir" do
        @rep.sandbox_dir.should == temporary_directory + 'Pods'
      end

      it "returns the path of the prefix header" do
        @rep.prefix_header_path.should == temporary_directory + 'Pods/Pods-MyApp-prefix.pch'
      end

      it "returns the path of the copy resources script" do
        @rep.copy_resources_script_path.should == temporary_directory + 'Pods/Pods-MyApp-resources.sh'
      end

      it "returns the pods project" do
        project = stub()
        config.sandbox.project = project
        @rep.project.should == project
      end

      it "returns the target definition" do
        @rep.target_definition.should == @target_definition
      end

    end

    #-------------------------------------------------------------------------#

    describe "Unsafe Hooks API" do

      it "returns the sandbox" do
        @rep.sandbox.should == config.sandbox
      end

      it "returns the library" do
        @rep.library.should == @lib
      end

      it "returns the native target" do
        target = stub()
        @lib.target = target
        @rep.target.should == target
      end

    end

    #-------------------------------------------------------------------------#

  end
end
