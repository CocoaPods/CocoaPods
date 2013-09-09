require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Project do

    before do
      @sut = Project.new(config.sandbox.project_path)
    end

    #-------------------------------------------------------------------------#

    describe "In general" do

      it "returns the support files group" do
        @sut.support_files_group.name.should == 'Target Files'
      end

      it "returns the pods group" do
        @sut.pods.name.should == 'Pods'
      end

      it "returns development Pods group" do
        @sut.development_pods.name.should == 'Development Pods'
      end

      describe "#prepare_for_serialization" do

        it "deletes the Pod and the Development Pods groups if empty" do
          @sut.prepare_for_serialization
          @sut[Project::ROOT_GROUPS[:pods]].should.be.nil
          @sut[Project::ROOT_GROUPS[:development_pods]].should.be.nil
        end

        it "sorts the groups recursively" do
          @sut.pods.new_group('group_2')
          @sut.pods.new_group('group_1')
          @sut.prepare_for_serialization
          @sut.pods.children.map(&:name).should == ["group_1", "group_2"]
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe "Pod Groups" do

      describe "#add_pod_group" do

        before do
          @path = config.sandbox.pod_dir('BananaLib')
        end

        it "adds the group for a Pod" do
          group = @sut.add_pod_group('BananaLib', @path)
          group.parent.should == @sut.pods
          group.name.should == 'BananaLib'
        end

        it "adds the group for a development Pod" do
          path = config.sandbox.pod_dir('BananaLib')
          group = @sut.add_pod_group('BananaLib', @path, true)
          group.parent.should == @sut.development_pods
          group.name.should == 'BananaLib'
        end

        it "configures the path of a new Pod group" do
          path = config.sandbox.pod_dir('BananaLib')
          group = @sut.add_pod_group('BananaLib', @path)
          group.source_tree.should == '<group>'
          group.path.should == 'BananaLib'
          Pathname.new(group.path).should.be.relative
        end

        it "configures the path of a new Pod group as absolute if requested" do
          path = config.sandbox.pod_dir('BananaLib')
          group = @sut.add_pod_group('BananaLib', @path, false, true)
          group.source_tree.should == '<absolute>'
          group.path.should == @path.to_s
          Pathname.new(group.path).should.be.absolute
        end

      end

      #----------------------------------------#

      describe "#pod_groups" do

        before do
          @sut.add_pod_group('BananaLib', config.sandbox.pod_dir('BananaLib'))
          @sut.add_pod_group('OrangeLib', config.sandbox.pod_dir('OrangeLib'), true)
        end

        it "returns the pod groups" do
          @sut.pod_groups.map(&:name).sort.should == ["BananaLib", "OrangeLib"]
        end

        it "doesn't alters the original groups" do
          @sut.pods.children.map(&:name).sort.should == ["BananaLib"]
          @sut.development_pods.children.map(&:name).sort.should == ["OrangeLib"]
        end

      end

      #----------------------------------------#

      it "returns the group of a Pod with a given name" do
        @sut.add_pod_group('BananaLib', config.sandbox.pod_dir('BananaLib'))
        @sut.pod_group('BananaLib').name.should == 'BananaLib'
      end

      #----------------------------------------#

      describe "#group_for_spec" do

        before do
          @sut.add_pod_group('BananaLib', config.sandbox.pod_dir('BananaLib'))
        end

        it "returns the group for the spec with the given name" do
          group = @sut.group_for_spec('BananaLib/Tree')
          group.hierarchy_path.should == '/Pods/BananaLib/Subspecs/Tree'
        end

        it "returns the requested subgroup" do
          group = @sut.group_for_spec('BananaLib/Tree', :source_files)
          group.hierarchy_path.should == '/Pods/BananaLib/Subspecs/Tree'
        end

        it "raises if unable to recognize the subgroup key" do
          should.raise ArgumentError do
            @sut.group_for_spec('BananaLib/Tree', :unknown)
          end.message.should.match /Unrecognized subgroup/
        end

        it "doesn't duplicate the groups" do
          group_1 = @sut.group_for_spec('BananaLib/Tree', :source_files)
          group_2 = @sut.group_for_spec('BananaLib/Tree', :source_files)
          group_1.uuid.should == group_2.uuid
        end
      end

      it "adds the group for the given aggregate target" do
        group = @sut.add_aggregate_group('Pods', config.sandbox.root + 'Aggregate/Pods')
        group.parent.should == @sut.support_files_group
        group.name.should == 'Pods'
        group.path.should == 'Aggregate/Pods'
      end

      it "returns the group for the aggregate target with the given name" do
        group = @sut.add_aggregate_group('Pods', config.sandbox.root + 'Aggregate/Pods')
        @sut.aggregate_group('Pods').should == group
      end

      it "returns the list of the aggregate groups" do
        group = @sut.add_aggregate_group('Pods', config.sandbox.root + 'Aggregate/Pods')
        group = @sut.add_aggregate_group('Tests', config.sandbox.root + 'Aggregate/Tests')
        @sut.aggregate_groups.map(&:name).should == ["Pods", "Tests"]
      end

      it "adds the group for the given aggregate target" do
        parent = @sut.add_aggregate_group('Pods', config.sandbox.root + 'Aggregate/Pods')
        group = @sut.add_aggregate_pod_group('Pods', 'BananaLib', config.sandbox.root + 'Aggregate/Pods/BananaLib')
        group.parent.should == parent
        group.name.should == 'BananaLib'
        group.path.should == 'BananaLib'
      end

      it "returns the group for the aggregate target with the given name" do
        @sut.add_aggregate_group('Pods', config.sandbox.root + 'Aggregate/Pods')
        group = @sut.add_aggregate_pod_group('Pods', 'BananaLib', config.sandbox.root + 'Aggregate/Pods/BananaLib')
        @sut.aggregate_pod_group('Pods', 'BananaLib').should == group
      end
    end

    #-------------------------------------------------------------------------#

    describe "File references" do

      describe "#reference_for_path" do

        before do
          @sut.add_pod_group('BananaLib', config.sandbox.pod_dir('BananaLib'), false)
          @file = config.sandbox.pod_dir('BananaLib') + "file.m"
          @group = @sut.group_for_spec('BananaLib', :source_files)
        end

        it "adds a file references to the given file" do
          ref = @sut.add_file_reference(@file, @group)
          ref.hierarchy_path.should == '/Pods/BananaLib/file.m'
        end

        it "it doesn't duplicate file references for a single path" do
          ref_1 = @sut.add_file_reference(@file, @group)
          ref_2 = @sut.add_file_reference(@file, @group)
          ref_1.uuid.should == ref_2.uuid
          @group.children.count.should == 1
        end

        it "raises if the given path is not absolute" do
          should.raise ArgumentError do
            @sut.add_file_reference('relative/path/to/file.m', @group)
          end.message.should.match /Paths must be absolute/
        end

      end

      #----------------------------------------#

      describe "#reference_for_path" do

        before do
          @sut.add_pod_group('BananaLib', config.sandbox.pod_dir('BananaLib'), false)
          @file = config.sandbox.pod_dir('BananaLib') + "file.m"
          @group = @sut.group_for_spec('BananaLib', :source_files)
          @sut.add_file_reference(@file, @group)
        end

        it "returns the reference for the given path" do
          ref = @sut.reference_for_path(@file)
          ref.hierarchy_path.should == '/Pods/BananaLib/file.m'
        end

        it "returns nil if no reference for the given path is available" do
          another_file = config.sandbox.pod_dir('BananaLib') + "another_file.m"
          ref = @sut.reference_for_path(another_file)
          ref.should.be.nil
        end

        it "raises if the given path is not absolute" do
          should.raise ArgumentError do
            @sut.reference_for_path('relative/path/to/file.m')
          end.message.should.match /Paths must be absolute/
        end

      end

      #----------------------------------------#

      describe "#set_podfile" do

        it "adds the Podfile configured as a Ruby file" do
          @sut.set_podfile(config.sandbox.root + '../Podfile')
          f = @sut['Podfile']
          f.source_tree.should == 'SOURCE_ROOT'
          f.xc_language_specification_identifier.should == 'xcode.lang.ruby'
          f.path.should == '../Podfile'
        end

        it "updates the Podfile if it already exists" do
          ref = @sut.set_podfile(config.sandbox.root + '../Podfile')
          @sut.set_podfile(config.sandbox.root + '../Dir/Podfile')
          ref.path.should == '../Dir/Podfile'
        end
      end

      #----------------------------------------#

      it "returns the file reference of the Podfile" do
        ref = @sut.set_podfile(config.sandbox.root + '../Podfile')
        @sut.podfile.should.equal(ref)
      end

    end

    #-------------------------------------------------------------------------#

    describe "Private helpers" do

      describe "#create_group_if_needed" do

        it "creates a new group" do
          group = @sut.send(:create_group_if_needed, 'Group')
          group.hierarchy_path.should == '/Group'
        end

        it "creates a new group" do
          group = @sut.send(:create_group_if_needed, 'Group', @sut.pods)
          group.hierarchy_path.should == '/Pods/Group'
        end

        it "returns an already existing group" do
          group_1 = @sut.send(:create_group_if_needed, 'Group')
          group_2 = @sut.send(:create_group_if_needed, 'Group')
          group_1.should.be.equal(group_2)
        end

      end

      #----------------------------------------#

      describe "#spec_group" do

        before do
          @sut.add_pod_group('JSONKit', config.sandbox.pod_dir('JSONKit'))
        end

        it "returns the Pod group for root specifications" do
          group = @sut.send(:spec_group, 'JSONKit')
          group.hierarchy_path.should == '/Pods/JSONKit'
        end

        it "returns the group for subspecs" do
          group = @sut.send(:spec_group, 'JSONKit/Parsing')
          group.hierarchy_path.should == '/Pods/JSONKit/Subspecs/Parsing'
        end

      end
    end

    #-------------------------------------------------------------------------#

  end
end



