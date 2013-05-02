require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::FileReferencesInstaller do

    before do
      @file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
      @library = Library.new(nil)
      @library.file_accessors = [@file_accessor]
      @project = Project.new(config.sandbox.project_path)
      @installer = Installer::FileReferencesInstaller.new(config.sandbox, [@library], @project)
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
        public_header =  headers_root + 'BananaLib/Banana.h'
        private_header = headers_root + 'BananaLib/BananaPrivate.h'
        public_header.should.exist
        private_header.should.not.exist
      end

    end

    #-------------------------------------------------------------------------#

    describe "Private Helpers" do

      it "returns the file accessors" do
        library_1 = Library.new(nil)
        library_1.file_accessors = [fixture_file_accessor('banana-lib/BananaLib.podspec')]
        library_2 = Library.new(nil)
        library_2.file_accessors = [fixture_file_accessor('banana-lib/BananaLib.podspec')]
        installer = Installer::FileReferencesInstaller.new(config.sandbox, [library_1, library_2], @project)
        roots = installer.send(:file_accessors).map { |fa| fa.path_list.root }
        roots.should == [fixture('banana-lib'), fixture('banana-lib')]
      end

      it "handles libraries empty libraries without file accessors" do
        library_1 = Library.new(nil)
        library_1.file_accessors = []
        installer = Installer::FileReferencesInstaller.new(config.sandbox, [library_1], @project)
        roots = installer.send(:file_accessors).should == []
      end

      it "returns the header mappings" do
        headers_sandbox = Pathname.new('BananaLib')
        headers = [Pathname.new('BananaLib/Banana.h')]
        mappings = @installer.send(:header_mappings, headers_sandbox, @file_accessor, headers)
        mappings.should == {
          headers_sandbox => [Pathname.new('BananaLib/Banana.h')]
        }
      end

      it "takes into account the header dir specified in the spec" do
        headers_sandbox = Pathname.new('BananaLib')
        headers = [Pathname.new('BananaLib/Banana.h')]
        @file_accessor.spec_consumer.stubs(:header_dir).returns('Sub_dir')
        mappings = @installer.send(:header_mappings, headers_sandbox, @file_accessor, headers)
        mappings.should == {
          (headers_sandbox + 'Sub_dir') => [Pathname.new('BananaLib/Banana.h')]
        }
      end

     it "takes into account the header mappings dir specified in the spec" do
        headers_sandbox = Pathname.new('BananaLib')
        header_1 = @file_accessor.root + 'BananaLib/sub_dir/dir_1/banana_1.h'
        header_2 = @file_accessor.root + 'BananaLib/sub_dir/dir_2/banana_2.h'
        headers = [ header_1, header_2 ]
        @file_accessor.spec_consumer.stubs(:header_mappings_dir).returns('BananaLib/sub_dir')
        mappings = @installer.send(:header_mappings, headers_sandbox, @file_accessor, headers)
        mappings.should == {
          (headers_sandbox + 'dir_1') => [header_1],
          (headers_sandbox + 'dir_2') => [header_2],
        }
      end

    end

    #-------------------------------------------------------------------------#

  end
end


