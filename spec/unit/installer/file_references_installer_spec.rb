require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::PodSourceInstaller do

    before do
      file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
      @library = Library.new(nil)
      @library.file_accessors = [file_accessor]
      @project = Project.new(config.sandbox.project_path)
      @installer = Installer::FileReferencesInstaller.new(config.sandbox, [@library], @project)
    end

    #-------------------------------------------------------------------------#

    describe "Installation" do

      it "adds the files references of the source files the Pods project" do
        @installer.install!
        group_ref = @installer.pods_project['Pods/BananaLib']
        group_ref.should.be.not.nil
        file_ref = @installer.pods_project['Pods/BananaLib/Banana.m']
        file_ref.should.be.not.nil
        file_ref.path.should == "../../spec/fixtures/banana-lib/Classes/Banana.m"
      end

      it "adds the files references of the local Pods in a dedicated group" do
        config.sandbox.store_local_path('BananaLib', 'Some Path')
        @installer.install!
        group_ref = @installer.pods_project['Local Pods/BananaLib']
        group_ref.should.be.not.nil
        file_ref = @installer.pods_project['Local Pods/BananaLib/Banana.m']
        file_ref.should.be.not.nil
      end

      it "adds the files references of the resources the Pods project" do
        @installer.install!
        group_ref = @installer.pods_project['Resources/BananaLib']
        group_ref.should.be.not.nil
        file_ref = @installer.pods_project['Resources/BananaLib/logo-sidebar.png']
        file_ref.should.be.not.nil
        file_ref.path.should == "../../spec/fixtures/banana-lib/Resources/logo-sidebar.png"
      end

      it "links the build headers" do
        @installer.install!
        headers_root = config.sandbox.build_headers.root
        public_header =  headers_root+ 'BananaLib/Banana.h'
        private_header = headers_root + 'BananaLib/BananaPrivate.h'
        public_header.should.exist
        private_header.should.exist
      end

      it "links the public headers" do
        @installer.install!
        headers_root = config.sandbox.public_headers.root
        public_header =  headers_root+ 'BananaLib/Banana.h'
        private_header = headers_root + 'BananaLib/BananaPrivate.h'
        public_header.should.exist
        private_header.should.not.exist
      end

    end

    #-------------------------------------------------------------------------#

    describe "Private Helpers" do

      xit "returns the unique file accessors" do
        library_1 = Library.new(nil)
        library_1.file_accessors = [fixture_file_accessor('banana-lib/BananaLib.podspec')]
        library_2 = Library.new(nil)
        library_2.file_accessors = [fixture_file_accessor('banana-lib/BananaLib.podspec')]
        installer = Installer::FileReferencesInstaller.new(config.sandbox, [library_1, library_2], @project)
        installer.send(:file_accessors).count.should == 1
      end

      xit "handles libraries without pods and hence without file accessors" do

      end

    end

    #-------------------------------------------------------------------------#

  end
end


