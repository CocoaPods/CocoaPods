require File.expand_path('../../spec_helper', __FILE__)

describe Pod::LocalPod do

  # a LocalPod represents a local copy of the dependency, inside the pod root, built from a spec

  before do
    @sandbox = temporary_sandbox
    @pod = Pod::LocalPod.new(fixture_spec('banana-lib/BananaLib.podspec'), @sandbox, Pod::Platform.new(:ios))
    copy_fixture_to_pod('banana-lib', @pod)
  end

  it 'returns the Pod root directory path' do
    @pod.root.should == @sandbox.root + 'BananaLib'
  end

  it "creates it's own root directory if it doesn't exist" do
    @pod.create
    File.directory?(@pod.root).should.be.true
  end

  it "can execute a block within the context of it's root" do
    @pod.chdir { FileUtils.touch("foo") }
    Pathname(@pod.root + "foo").should.exist
  end

  it 'can delete itself' do
    @pod.create
    @pod.implode
    @pod.root.should.not.exist
  end

  it 'returns an expanded list of source files, relative to the sandbox root' do
    @pod.source_files.sort.should == [
      Pathname.new("BananaLib/Classes/Banana.m"),
      Pathname.new("BananaLib/Classes/Banana.h")
    ].sort
  end

  xit 'returns an expanded list of absolute clean paths' do
    @pod.clean_paths.should == [@sandbox.root + "BananaLib/sub-dir"]
  end

  it 'returns an expanded list of resources, relative to the sandbox root' do
    @pod.resources.should == [Pathname.new("BananaLib/Resources/logo-sidebar.png")]
  end

  it 'returns a list of header files' do
    @pod.header_files.should == [Pathname.new("BananaLib/Classes/Banana.h")]
  end

  xit 'can clean up after itself' do
    @pod.clean_paths.tap do |paths|
      @pod.clean

      paths.each do |path|
        path.should.not.exist
      end
    end
  end

  it "can link it's headers into the sandbox" do
    @pod.link_headers
    expected_header_path = @sandbox.headers_root + "BananaLib/Banana.h"
    expected_header_path.should.be.symlink
    File.read(expected_header_path).should == (@sandbox.root + @pod.header_files[0]).read
  end

  it "can add it's source files to an Xcode project target" do
    target = mock('target')
    target.expects(:add_source_file).with(Pathname.new("BananaLib/Classes/Banana.m"), anything, anything)
    @pod.add_to_target(target)
  end

  it "can add it's source files to a target with any specially configured compiler flags" do
    @pod.top_specification.compiler_flags = '-d some_flag'
    target = mock('target')
    target.expects(:add_source_file).with(anything, anything, "-d some_flag")
    @pod.add_to_target(target)
  end
end

describe "A Pod::LocalPod, with installed source," do
  #before do
    #config.project_pods_root = fixture('integration')
    #podspec   = fixture('spec-repos/master/SSZipArchive/0.1.0/SSZipArchive.podspec')
    #@spec     = Pod::Specification.from_file(podspec)
    #@destroot = fixture('integration/SSZipArchive')
 #end

  #after do
    #config.project_pods_root = nil
  #end

  xit "returns the list of files that the source_files pattern expand to" do
    files = @destroot.glob('**/*.{h,c,m}')
    files = files.map { |file| file.relative_path_from(config.project_pods_root) }
    @spec.expanded_source_files[:ios].sort.should == files.sort
  end

  xit "returns the list of headers" do
    files = @destroot.glob('**/*.h')
    files = files.map { |file| file.relative_path_from(config.project_pods_root) }
    @spec.header_files[:ios].sort.should == files.sort
  end

  xit "returns a hash of mappings from the pod's destroot to its header dirs, which by default is just the pod's header dir" do
    @spec.copy_header_mappings[:ios].size.should == 1
    @spec.copy_header_mappings[:ios][Pathname.new('SSZipArchive')].sort.should == %w{
      SSZipArchive.h
      minizip/crypt.h
      minizip/ioapi.h
      minizip/mztools.h
      minizip/unzip.h
      minizip/zip.h
    }.map { |f| Pathname.new("SSZipArchive/#{f}") }.sort
  end

  xit "allows for customization of header mappings by overriding copy_header_mapping" do
    def @spec.copy_header_mapping(from)
      Pathname.new('ns') + from.basename
    end
    @spec.copy_header_mappings[:ios].size.should == 1
    @spec.copy_header_mappings[:ios][Pathname.new('SSZipArchive/ns')].sort.should == %w{
      SSZipArchive.h
      minizip/crypt.h
      minizip/ioapi.h
      minizip/mztools.h
      minizip/unzip.h
      minizip/zip.h
    }.map { |f| Pathname.new("SSZipArchive/#{f}") }.sort
  end

  xit "returns a hash of mappings with a custom header dir prefix" do
    @spec.header_dir = 'AnotherRoot'
    @spec.copy_header_mappings[:ios][Pathname.new('AnotherRoot')].sort.should == %w{
      SSZipArchive.h
      minizip/crypt.h
      minizip/ioapi.h
      minizip/mztools.h
      minizip/unzip.h
      minizip/zip.h
    }.map { |f| Pathname.new("SSZipArchive/#{f}") }.sort
  end

  xit "returns the user header search paths" do
    def @spec.copy_header_mapping(from)
      Pathname.new('ns') + from.basename
    end
    @spec.header_search_paths.should == %w{
      "$(PODS_ROOT)/Headers/SSZipArchive"
      "$(PODS_ROOT)/Headers/SSZipArchive/ns"
    }
  end

  xit "returns the user header search paths with a custom header dir prefix" do
    @spec.header_dir = 'AnotherRoot'
    def @spec.copy_header_mapping(from)
      Pathname.new('ns') + from.basename
    end
    @spec.header_search_paths.should == %w{
      "$(PODS_ROOT)/Headers/AnotherRoot"
      "$(PODS_ROOT)/Headers/AnotherRoot/ns"
    }
  end

  xit "returns the list of files that the resources pattern expand to" do
    @spec.expanded_resources.should == {}
    @spec.resource = 'LICEN*'
    @spec.expanded_resources[:ios].map(&:to_s).should == %w{ SSZipArchive/LICENSE }
    @spec.expanded_resources[:osx].map(&:to_s).should == %w{ SSZipArchive/LICENSE }
    @spec.resources = 'LICEN*', 'Readme.*'
    @spec.expanded_resources[:ios].map(&:to_s).should == %w{ SSZipArchive/LICENSE SSZipArchive/Readme.markdown }
    @spec.expanded_resources[:osx].map(&:to_s).should == %w{ SSZipArchive/LICENSE SSZipArchive/Readme.markdown }
  end
end
