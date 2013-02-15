require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Sandbox do

    before do
      @sandbox = Pod::Sandbox.new(temporary_directory + 'Sandbox')
    end

    it "automatically creates its root if it doesn't exist" do
      File.directory?(temporary_directory + 'Sandbox').should.be.true
    end

    it "returns the manifest" do
      @sandbox.manifest.should == nil
    end

    it "returns the project" do
      @sandbox.project.should == nil
    end

    it "returns the public headers store" do
      @sandbox.public_headers.root.should == temporary_directory + 'Sandbox/Headers'
    end

    it "returns the build headers store" do
      @sandbox.build_headers.root.should == temporary_directory + 'Sandbox/BuildHeaders'
    end

    it "deletes the entire root directory on implode" do
      @sandbox.implode
      File.directory?(temporary_directory + 'Sandbox').should.be.false
    end

    it "can return the relative path of a given absolute path" do
      path = temporary_directory + 'Sandbox/file'
      @sandbox.relativize(path).should == Pathname.new('file')
    end

    it "can return the relative path of a given absolute path outside the sandbox root" do
      path = temporary_directory + 'file'
      @sandbox.relativize(path).should == Pathname.new('../file')
    end

    it "can return the relative path of a given absolute path with another root directory" do
      path = Pathname('/tmp/Lint')
      expected = Pathname.new('../../../tmp/Lint')
      @sandbox.instance_variable_set(:@root, Pathname.new('/Users/sandbox'))
      @sandbox.relativize(path).should == expected
    end

    it "converts a list of paths to the relative paths respect to the sandbox" do
      paths = [temporary_directory + 'Sandbox/file_1', temporary_directory + 'Sandbox/file_2' ]
      @sandbox.relativize_paths(paths).should == [Pathname.new('file_1'), Pathname.new('file_2')]
    end

    #-------------------------------------------------------------------------#

    it "returns the path of the manifest" do
      @sandbox.manifest_path.should == temporary_directory + 'Sandbox/Manifest.lock'
    end

    it "returns the path of the Pods project" do
      @sandbox.project_path.should == temporary_directory + 'Sandbox/Pods.xcodeproj'
    end

    it "returns the path for a Pod" do
      @sandbox.pod_dir('JSONKit').should == temporary_directory + 'Sandbox/JSONKit'
    end

    it "returns the directory for the support files of a library" do
      @sandbox.library_support_files_dir('Pods').should == temporary_directory + 'Sandbox'
    end

    it "returns the directory where to store the specifications" do
      @sandbox.specifications_dir.should == temporary_directory + 'Sandbox/Local Podspecs'
    end

    it "returns the path to a spec file in the 'Local Podspecs' dir" do
      (@sandbox.root + 'Local Podspecs').mkdir
      FileUtils.cp(fixture('banana-lib/BananaLib.podspec'), @sandbox.root + 'Local Podspecs')
      @sandbox.specification_path('BananaLib').should == @sandbox.root + 'Local Podspecs/BananaLib.podspec'
    end

    #-------------------------------------------------------------------------#

    it "loads the stored specification with the given name" do
      (@sandbox.root + 'Local Podspecs').mkdir
      FileUtils.cp(fixture('banana-lib/BananaLib.podspec'), @sandbox.root + 'Local Podspecs')
      @sandbox.specification('BananaLib').name.should == 'BananaLib'
    end

    it "stores the list of the names of the pre-downloaded pods" do
      @sandbox.predownloaded_pods << 'JSONKit'
      @sandbox.predownloaded_pods.should == ['JSONKit']
    end

    #-------------------------------------------------------------------------#

  end
end
