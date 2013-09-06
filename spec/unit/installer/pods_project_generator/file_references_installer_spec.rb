require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodsProjectGenerator::FileReferencesInstaller do

    before do
      @file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
      @pod_target = PodTarget.new([], nil, config.sandbox)
      @pod_target.file_accessors = [@file_accessor]
      @project = Project.new(config.sandbox.project_path)
      @project.add_pod_group('BananaLib', fixture('banana-lib'))
      @installer = Installer::PodsProjectGenerator::FileReferencesInstaller.new(config.sandbox, [@pod_target], @project)
    end

    #-------------------------------------------------------------------------#

    describe "Installation" do

      it "adds the files references of the source files the Pods project" do
        @file_accessor.path_list.read_file_system
        @file_accessor.path_list.expects(:read_file_system)
        @installer.install!
      end

      it "adds the files references of the source files the Pods project" do
        @installer.install!
        file_ref = @installer.pods_project['Pods/BananaLib/Source Files/Banana.m']
        file_ref.should.be.not.nil
        file_ref.path.should == "Classes/Banana.m"
      end

      xit "adds the file references of the frameworks of the projet" do

      end

      xit "adds the file references of the libraries of the project" do

      end

      it "adds the files references of the resources the Pods project" do
        @installer.install!
        file_ref = @installer.pods_project['Pods/BananaLib/Resources/logo-sidebar.png']
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
          installer = Installer::PodsProjectGenerator::FileReferencesInstaller.new(config.sandbox, [pod_target_1, pod_target_2], @project)
          roots = installer.send(:file_accessors).map { |fa| fa.path_list.root }
          roots.should == [fixture('banana-lib'), fixture('banana-lib')]
        end

        it "handles libraries empty libraries without file accessors" do
          pod_target_1 = PodTarget.new([], nil, config.sandbox)
          pod_target_1.file_accessors = []
          installer = Installer::PodsProjectGenerator::FileReferencesInstaller.new(config.sandbox, [pod_target_1], @project)
          roots = installer.send(:file_accessors).should == []
        end
      end

      describe "#add_file_accessors_paths_to_pods_group" do 
        xit "adds the paths of the paths of the file accessor corresponding to the given key to the Pods project" do

        end
      end
    end

    #-------------------------------------------------------------------------#

  end
end


