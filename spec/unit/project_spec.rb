require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Project do

    before do
      @project = Project.new(config.sandbox, nil)
    end

    #-------------------------------------------------------------------------#

    describe "In general" do

      it "creates the support file group on initialization" do
        @project.support_files_group.name.should == 'Targets Support Files'
      end

      it "can return the relative path of a given absolute path" do
        path = temporary_directory + 'Pods/BananaLib/file'
        @project.relativize(path).should == Pathname.new('BananaLib/file')
      end

      it "can return the relative path of a given absolute path outside its root" do
        path = temporary_directory + 'file'
        @project.relativize(path).should == Pathname.new('../file')
      end

      it "can return the relative path of a given absolute path with another root directory" do
        path = Pathname('/tmp/Lint')
        expected = Pathname.new('../../../tmp/Lint')
        @project.instance_variable_set(:@root, Pathname.new('/Users/sandbox'))
        @project.relativize(path).should == expected
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

      it "returns the `Resources` group" do
        @project.resources.name.should == 'Resources'
      end

    end

    #-------------------------------------------------------------------------#

    describe "File references" do

      it "adds the file references for the given source files" do
        source_files = [ config.sandbox.root + "A_POD/some_file.m" ]
        @project.add_file_references(source_files, 'BananaLib', @project.pods)
        group = @project['Pods/BananaLib/Source Files']
        group.should.not.be.nil
        group.children.map(&:path).should == [ "A_POD/some_file.m" ]
      end

      it "adds the only one file reference for a given absolute path" do
        source_files = [ config.sandbox.root + "A_POD/some_file.m" ]
        @project.add_file_references(source_files, 'BananaLib', @project.pods)
        @project.add_file_references(source_files, 'BananaLib', @project.pods)
        group = @project['Pods/BananaLib/Source Files']
        group.children.count.should == 1
        group.children.first.path.should == "A_POD/some_file.m"
      end

      it "returns the file reference for a given source file" do
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
          @project.add_file_references([file], 'BananaLib', @project.pods)
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



