require File.expand_path('../../spec_helper', __FILE__)

describe Pod::Project do
  describe "In general" do
    before do
      @project = Pod::Project.new(config.sandbox.project_path)
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
      @project.add_podfile(config.sandbox.root + '../Podfile')
      f = @project['Podfile']
      f.name.should == 'Podfile'
      f.source_tree.should == 'SOURCE_ROOT'
      f.xc_language_specification_identifier.should == 'xcode.lang.ruby'
      f.path.should == '../Podfile'
    end

    #--------------------------------------------------------------------------------#

    it "adds the file references for the given source files" do
      source_files = [ config.sandbox.root + "A_POD/some_file.m" ]
      @project.add_file_references(source_files, 'BananaLib', @project.pods)
      group = @project['Pods/BananaLib']
      group.should.not.be.nil
      group.children.map(&:path).should == [ "A_POD/some_file.m" ]
    end

    it "returns the file reference for a given source file" do
      file = config.sandbox.root + "A_POD/some_file.m"
      @project.add_file_references([file], 'BananaLib', @project.pods)
      file_reference = @project.file_reference(file)
      file_reference.path.should == "A_POD/some_file.m"
    end
  end
end



