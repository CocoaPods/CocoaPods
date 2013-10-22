require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Project do

    before do
      @project = Project.new(environment.sandbox.project_path)
    end

    #-------------------------------------------------------------------------#

    describe "In general" do

      it "creates the support files group on initialization" do
        @project.support_files_group.name.should == 'Targets Support Files'
      end

      it "creates the Pods group on initialization" do
        @project.pods.name.should == 'Pods'
      end

      it "creates the development Pods group on initialization" do
        @project.development_pods.name.should == 'Development Pods'
      end

    end

    #-------------------------------------------------------------------------#

    describe "Pod Groups" do

      describe "#add_pod_group" do

        before do
          @path = environment.sandbox.pod_dir('BananaLib')
        end

        it "adds the group for a Pod" do
          group = @project.add_pod_group('BananaLib', @path)
          group.parent.should == @project.pods
          group.name.should == 'BananaLib'
        end

        it "adds the group for a development Pod" do
          group = @project.add_pod_group('BananaLib', @path, true)
          group.parent.should == @project.development_pods
          group.name.should == 'BananaLib'
        end

        it "configures the path of a new Pod group" do
          group = @project.add_pod_group('BananaLib', @path)
          group.source_tree.should == '<group>'
          group.path.should == 'BananaLib'
          Pathname.new(group.path).should.be.relative
        end

        it "configures the path of a new Pod group as absolute if requested" do
          group = @project.add_pod_group('BananaLib', @path, false, true)
          group.source_tree.should == '<absolute>'
          group.path.should == @path.to_s
          Pathname.new(group.path).should.be.absolute
        end

      end

      #----------------------------------------#

      describe "#pod_groups" do

        before do
          @project.add_pod_group('BananaLib', environment.sandbox.pod_dir('BananaLib'))
          @project.add_pod_group('OrangeLib', environment.sandbox.pod_dir('OrangeLib'), true)
        end

        it "returns the pod groups" do
          @project.pod_groups.map(&:name).sort.should == ["BananaLib", "OrangeLib"]
        end

        it "doesn't alters the original groups" do
          @project.pods.children.map(&:name).sort.should == ["BananaLib"]
          @project.development_pods.children.map(&:name).sort.should == ["OrangeLib"]
        end

      end

      #----------------------------------------#

      it "returns the group of a Pod with a given name" do
        @project.add_pod_group('BananaLib', environment.sandbox.pod_dir('BananaLib'))
        @project.pod_group('BananaLib').name.should == 'BananaLib'
      end

      #----------------------------------------#

      describe "#group_for_spec" do

        before do
          @project.add_pod_group('BananaLib', environment.sandbox.pod_dir('BananaLib'))
        end

        it "returns the group for the spec with the given name" do
          group = @project.group_for_spec('BananaLib/Tree')
          group.hierarchy_path.should == '/Pods/BananaLib/Tree'
        end

        it "doesn't duplicate the groups" do
          group_1 = @project.group_for_spec('BananaLib/Tree')
          group_2 = @project.group_for_spec('BananaLib/Tree')
          group_1.uuid.should == group_2.uuid
        end

        it "returns the subgroup with the given key" do
          group = @project.group_for_spec('BananaLib/Tree', :resources)
          group.hierarchy_path.should == '/Pods/BananaLib/Tree/Resources'
        end

        it "doesn't duplicates subgroups" do
          group_1 = @project.group_for_spec('BananaLib/Tree', :resources)
          group_2 = @project.group_for_spec('BananaLib/Tree', :resources)
          group_1.uuid.should == group_2.uuid
        end

        it "raises if the subgroup key is unrecognized" do
          should.raise ArgumentError do
            @project.group_for_spec('BananaLib/Tree', :bananaland)
          end.message.should.match /Unrecognized.*key/
        end
      end

      #----------------------------------------#

      describe "#pod_support_files_group" do

        before do
          @project.add_pod_group('BananaLib', @path, false, true)
        end

        it "creates a support file group relative to the project" do
          group = @project.pod_support_files_group('BananaLib')
          group.source_tree.should == 'SOURCE_ROOT'
          group.path.should.be.nil
        end

        it "doesn't duplicate the groups" do
          group_1 = @project.pod_support_files_group('BananaLib')
          group_2 = @project.pod_support_files_group('BananaLib')
          group_1.uuid.should == group_2.uuid
        end

      end
    end

    #-------------------------------------------------------------------------#

    describe "File references" do

      describe "#reference_for_path" do

        before do
          @project.add_pod_group('BananaLib', environment.sandbox.pod_dir('BananaLib'), false)
          @file = environment.sandbox.pod_dir('BananaLib') + "file.m"
          @group = @project.group_for_spec('BananaLib')
        end

        it "adds a file references to the given file" do
          ref = @project.add_file_reference(@file, @group)
          ref.hierarchy_path.should == '/Pods/BananaLib/file.m'
        end

        it "it doesn't duplicate file references for a single path" do
          ref_1 = @project.add_file_reference(@file, @group)
          ref_2 = @project.add_file_reference(@file, @group)
          ref_1.uuid.should == ref_2.uuid
          @group.children.count.should == 1
        end

        it "raises if the given path is not absolute" do
          should.raise ArgumentError do
            @project.add_file_reference('relative/path/to/file.m', @group)
          end.message.should.match /Paths must be absolute/
        end

      end

      #----------------------------------------#

      describe "#reference_for_path" do

        before do
          @project.add_pod_group('BananaLib', environment.sandbox.pod_dir('BananaLib'), false)
          @file = environment.sandbox.pod_dir('BananaLib') + "file.m"
          @group = @project.group_for_spec('BananaLib')
          @project.add_file_reference(@file, @group)
        end

        it "returns the reference for the given path" do
          ref = @project.reference_for_path(@file)
          ref.hierarchy_path.should == '/Pods/BananaLib/file.m'
        end

        it "returns nil if no reference for the given path is available" do
          another_file = environment.sandbox.pod_dir('BananaLib') + "another_file.m"
          ref = @project.reference_for_path(another_file)
          ref.should.be.nil
        end

        it "raises if the given path is not absolute" do
          should.raise ArgumentError do
            @project.reference_for_path('relative/path/to/file.m')
          end.message.should.match /Paths must be absolute/
        end
      end

      #----------------------------------------#

      it "adds the Podfile configured as a Ruby file" do
        @project.add_podfile(environment.sandbox.root + '../Podfile')
        f = @project['Podfile']
        f.source_tree.should == 'SOURCE_ROOT'
        f.xc_language_specification_identifier.should == 'xcode.lang.ruby'
        f.path.should == '../Podfile'
      end

    end

    #-------------------------------------------------------------------------#

  end
end

