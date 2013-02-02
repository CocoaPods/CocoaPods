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

    it "converts a list of paths to the relative paths respec to the sandbox" do
      paths = [temporary_directory + 'Sandbox/file_1', temporary_directory + 'Sandbox/file_2' ]
      @sandbox.relativize_paths(paths).should == [Pathname.new('file_1'), Pathname.new('file_2')]
    end

    #--------------------------------------#

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

    #--------------------------------------#

    it "loads the stored specification with the given name" do
      (@sandbox.root + 'Local Podspecs').mkdir
      FileUtils.cp(fixture('banana-lib/BananaLib.podspec'), @sandbox.root + 'Local Podspecs')
      @sandbox.specification('BananaLib').name.should == 'BananaLib'
    end

    it "stores the list of the names of the pre-downloaded pods" do
      @sandbox.predownloaded_pods << 'JSONKit'
      @sandbox.predownloaded_pods.should == ['JSONKit']
    end
  end

  #---------------------------------------------------------------------------#

  describe Sandbox::HeadersStore do


    before do
      @sandbox = Pod::Sandbox.new(temporary_directory + 'Sandbox')
      @header_dir = Sandbox::HeadersStore.new(@sandbox, 'Headers')
    end

    it "returns it's headers root" do
      @header_dir.root.should == temporary_directory + 'Sandbox/Headers'
    end

    it "can add namespaced headers to it's header path using symlinks and return the relative path" do
      FileUtils.mkdir_p(@sandbox.root + "ExampleLib/")
      namespace_path = Pathname.new("ExampleLib")
      relative_header_paths = [
        Pathname.new("ExampleLib/MyHeader.h"),
        Pathname.new("ExampleLib/MyOtherHeader.h")
      ]
      relative_header_paths.each do |path|
        File.open(@sandbox.root + path, "w") { |file| file.write('hello') }
      end
      symlink_paths = @header_dir.add_files(namespace_path, relative_header_paths)
      symlink_paths.each do |path|
        path.should.be.symlink
        File.read(path).should == "hello"
      end
    end

    it 'keeps a list of unique header search paths when headers are added' do
      FileUtils.mkdir_p(@sandbox.root + "ExampleLib/Dir")
      namespace_path = Pathname.new("ExampleLib")
      relative_header_paths = [
        Pathname.new("ExampleLib/Dir/MyHeader.h"),
        Pathname.new("ExampleLib/Dir/MyOtherHeader.h")
      ]
      relative_header_paths.each do |path|
        File.open(@sandbox.root + path, "w") { |file| file.write('hello') }
      end
      @header_dir.add_files(namespace_path, relative_header_paths)
      @header_dir.search_paths.should.include("${PODS_ROOT}/Headers/ExampleLib")
    end

    it 'always adds the Headers root to the header search paths' do
      @header_dir.search_paths.should.include("${PODS_ROOT}/Headers")
    end
  end

  #--------------------------------------#

end
