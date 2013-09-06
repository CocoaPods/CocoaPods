require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodsProjectGenerator::FileReferencesInstaller do

    before do
      @file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
      @pod_target = PodTarget.new([], nil, config.sandbox)
      @pod_target.file_accessors = [@file_accessor]
      config.sandbox.project = Project.new(config.sandbox.project_path)
      config.sandbox.project.add_pod_group('BananaLib', fixture('banana-lib'))
      @sut = Installer::PodsProjectGenerator::FileReferencesInstaller.new(config.sandbox, [@pod_target])
    end

    #-------------------------------------------------------------------------#

    describe "Installation" do

      it "adds the files references of the source files the Pods project" do
        @file_accessor.path_list.read_file_system
        @file_accessor.path_list.expects(:read_file_system)
        @sut.install!
      end

      it "adds the files references of the source files the Pods project" do
        @sut.install!
        file_ref = config.sandbox.project['Pods/BananaLib/Source Files/Banana.m']
        file_ref.should.be.not.nil
        file_ref.path.should == "Classes/Banana.m"
      end

      it "adds the file references of the frameworks of the project" do
        @sut.install!
        group = config.sandbox.project.group_for_spec('BananaLib', :frameworks_and_libraries)
        file_ref = group['Bananalib.framework']
        file_ref.should.be.not.nil
        file_ref.path.should == "Bananalib.framework"
      end

      it "adds the file references of the libraries of the project" do
        @sut.install!
        group = config.sandbox.project.group_for_spec('BananaLib', :frameworks_and_libraries)
        file_ref = group['libBananalib.a']
        file_ref.should.be.not.nil
        file_ref.path.should == "libBananalib.a"
      end

      it "adds the files references of the resources the Pods project" do
        @sut.install!
        file_ref = config.sandbox.project['Pods/BananaLib/Resources/logo-sidebar.png']
        file_ref.should.be.not.nil
        file_ref.path.should == "Resources/logo-sidebar.png"
      end

    end

    #-------------------------------------------------------------------------#

    describe "Private Helpers" do

      describe "#file_accessors" do
        it "returns the file accessors" do
          pod_target_1 = PodTarget.new([], nil, config.sandbox)
          pod_target_1.file_accessors = [fixture_file_accessor('banana-lib/BananaLib.podspec')]
          pod_target_2 = PodTarget.new([], nil, config.sandbox)
          pod_target_2.file_accessors = [fixture_file_accessor('banana-lib/BananaLib.podspec')]
          @sut = Installer::PodsProjectGenerator::FileReferencesInstaller.new(config.sandbox, [pod_target_1, pod_target_2])
          roots = @sut.send(:file_accessors).map { |fa| fa.path_list.root }
          roots.should == [fixture('banana-lib'), fixture('banana-lib')]
        end

        it "handles libraries empty libraries without file accessors" do
          pod_target_1 = PodTarget.new([], nil, config.sandbox)
          pod_target_1.file_accessors = []
          @sut = Installer::PodsProjectGenerator::FileReferencesInstaller.new(config.sandbox, [pod_target_1])
          roots = @sut.send(:file_accessors).should == []
        end
      end

      describe "#add_paths_to_group" do

        it "adds the paths of the paths of the file accessor corresponding to the given key to the Pods project" do
          @sut.send(:add_paths_to_group, :source_files, :source_files)
          group = config.sandbox.project.group_for_spec('BananaLib', :source_files)
          group.children.map(&:name).sort.should == ["Banana.h", "Banana.m", "BananaPrivate.h"]
        end

      end
    end

    #-------------------------------------------------------------------------#

  end
end


