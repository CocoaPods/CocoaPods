require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Project do

    before do
      @project = Project.new(config.sandbox)
    end

    #-------------------------------------------------------------------------#

    describe "In general" do

      it "creates the support file group on initialization" do
        @project.support_files_group.name.should == 'Targets Support Files'
      end

    end

    #-------------------------------------------------------------------------#

    describe "Groups" do

      it "returns the `Pods` group" do
        @project.pods.name.should == 'Pods'
      end

      it "returns the `Local Pods` group" do
        @project.local_pods.name.should == 'Local Pods'
      end

    end

    #-------------------------------------------------------------------------#

    describe "File references" do

      it "adds a file references to the given file" do
        source_file = config.sandbox.root + "A_POD/some_file.m"
        group = @project.group_for_spec('BananaLib', :source_files)
        @project.add_file_reference(source_file, group)
        group.children.map(&:path).should == [ "A_POD/some_file.m" ]
      end

      xit "adds the only one file reference for a given absolute path" do
        source_files = [ config.sandbox.root + "A_POD/some_file.m" ]
        @project.add_file_references(source_files, 'BananaLib', @project.pods)
        @project.add_file_references(source_files, 'BananaLib', @project.pods)
        group = @project['Pods/BananaLib/Source Files']
        group.children.count.should == 1
        group.children.first.path.should == "A_POD/some_file.m"
      end

      xit "returns the file reference for a given source file" do
        file = config.sandbox.root + "A_POD/some_file.m"
        @project.add_file_references([file], 'BananaLib', @project.pods)
        file_reference = @project.file_reference(file)
        file_reference.path.should == "A_POD/some_file.m"
      end

      it "adds the Podfile configured as a Ruby file" do
        @project.add_podfile(config.sandbox.root + '../Podfile')
        f = @project['Podfile']
        f.source_tree.should == '<group>'
        f.xc_language_specification_identifier.should == 'xcode.lang.ruby'
        f.path.should == '../Podfile'
      end

    end

    #-------------------------------------------------------------------------#

    describe "Private helpers" do

      describe "#refs_by_absolute_path" do
        it "stores the references by absolute path" do
          file = config.sandbox.root + "A_POD/some_file.m"
          group = @project.group_for_spec('BananaLib', :source_files)
          @project.add_file_reference(file, group)
          refs_by_absolute_path = @project.send(:refs_by_absolute_path)
          refs_by_absolute_path.should == {
            file => @project.file_reference(file)
          }
        end
      end

      describe "#add_spec_group" do
        it "adds a group for a specification" do
          group = @project.send(:add_spec_group, 'JSONKit', @project.pods)
          @project.pods.children.should.include?(group)
          g = @project['Pods/JSONKit']
          g.name.should == 'JSONKit'
          g.children.should.be.empty?
        end

        it "namespaces subspecs in groups" do
          group = @project.send(:add_spec_group, 'JSONKit/Subspec', @project.pods)
          @project.pods.groups.find { |g| g.name == 'JSONKit' }.children.should.include?(group)
          g = @project['Pods/JSONKit/Subspec']
          g.name.should == 'Subspec'
          g.children.should.be.empty?
        end
      end

    end

    #-------------------------------------------------------------------------#

  end
end



