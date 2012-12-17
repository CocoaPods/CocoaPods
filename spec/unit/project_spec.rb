require File.expand_path('../../spec_helper', __FILE__)

describe Pod::Project do
  describe "In general" do
    before do
      @project = Pod::Project.new(nil)
    end

    it "creates the support file group on initialization" do
      @project.support_files_group.name.should == 'Targets Support Files'
    end

    it "returns the `Pods` group" do
      @project.pods.name.should == 'Pods'
    end

    it "returns the `Local Pods` group" do
      @project.local_pods.name.should == 'Local Pods'
    end

    it "adds a group for a specification" do
      group = @project.add_spec_group('JSONKit', @project.pods)
      @project.pods.children.should.include?(group)
      g = @project['Pods/JSONKit']
      g.name.should == 'JSONKit'
      g.children.should.be.empty?
    end

    it "namespaces subspecs in groups" do
      group = @project.add_spec_group('JSONKit/Subspec', @project.pods)
      @project.pods.groups.find { |g| g.name == 'JSONKit' }.children.should.include?(group)
      g = @project['Pods/JSONKit/Subspec']
      g.name.should == 'Subspec'
      g.children.should.be.empty?
    end

    it "adds the Podfile configured as a Ruby file" do
      @project.add_podfile('../Podfile')
      f = @project['Podfile']
      f.name.should == 'Podfile'
      f.source_tree.should == 'SOURCE_ROOT'
      f.xc_language_specification_identifier.should == 'xcode.lang.ruby'
      f.path.should == '../Podfile'
    end
  end
end



