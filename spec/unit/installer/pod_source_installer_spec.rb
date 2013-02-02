require File.expand_path('../../../spec_helper', __FILE__)

# module BaconFocusedMode; end

module Pod
  describe Installer::PodSourceInstaller do

    describe "In General" do

      # TODO: describe defaults

    end

    #-------------------------------------------------------------------------#

    describe "Installation" do

      before do
        @spec = fixture_spec('banana-lib/BananaLib.podspec')
        @spec.source = { :git => SpecHelper.fixture('banana-lib') }
        specs_by_platform = { :ios => [@spec] }
        @installer = Installer::PodSourceInstaller.new(config.sandbox, specs_by_platform)
      end

      describe "Download" do
        it "downloads the source" do
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :tag => 'v1.0' }
          @installer.install!
          @installer.specific_source.should.be.nil
          pod_folder = config.sandbox.root + 'BananaLib'
          pod_folder.should.exist
        end

        it "downloads the head source if specified source" do
          @spec.version.head = true
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :tag => 'v1.0' }
          @installer.install!
          @installer.specific_source[:commit].should == "0b8b4084a43c38cfe308efa076fdeb3a64d9d2bc"
          pod_folder = config.sandbox.root + 'BananaLib'
          pod_folder.should.exist
        end

        it "returns the checkout options of the downloader if any" do
          @spec.source = { :git => SpecHelper.fixture('banana-lib'), :branch => 'topicbranch' }
        @installer.install!
          @installer.specific_source[:commit].should == "446b22414597f1bb4062a62c4eed7af9627a3f1b"
          pod_folder = config.sandbox.root + 'BananaLib'
          pod_folder.should.exist
        end

      end

      #--------------------------------------#

      describe "Documentation" do

        it "generates the documentation if needed" do
          @installer.generate_docs = true
          @installer.documentation_generator.expects(:generate)
          @installer.install!
        end

        it "doesn't generates the documentation if it is already installed" do
          @installer.generate_docs = true
          @installer.documentation_generator.stubs(:already_installed?).returns(true)
          @installer.documentation_generator.expects(:generate).never
          @installer.install!
        end

        it "doesn't generates the documentation if disabled in the config" do
          @installer.generate_docs = false
          @installer.documentation_generator.expects(:generate).never
          @installer.install!
        end

      end

      #--------------------------------------#

      describe "Cleaning" do

        it "cleans the paths non used by the installation" do
          @installer.clean = true
          @installer.install!
          unused_file = config.sandbox.root + 'BananaLib/sub-dir/sub-dir-2/somefile.txt'
          unused_file.should.not.exist
        end

        it "preserves important files like the LICENSE and the README" do
          @installer.clean = true
          @installer.install!
          readme_file = config.sandbox.root + 'BananaLib/README'
          readme_file.should.exist
        end

        it "doesn't performs any cleaning if instructed to do so" do
          @installer.clean = false
          @installer.install!
          unused_file = config.sandbox.root + 'BananaLib/sub-dir/sub-dir-2/somefile.txt'
          unused_file.should.exist
        end

      end

      #--------------------------------------#

      describe "Headers" do

        it "links the headers used to build the Pod library" do
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

    end

    #-------------------------------------------------------------------------#

    describe "Private Helpers" do

      #--------------------------------------#

      describe "#clean_paths" do

      end

      #--------------------------------------#

      describe "#used_files" do

      end

      #--------------------------------------#

      describe "#header_mappings" do

        xit "can handle the mappings headers of subspecs" do

        end

      end

      #--------------------------------------#

    end

    #-------------------------------------------------------------------------#

  end
end
