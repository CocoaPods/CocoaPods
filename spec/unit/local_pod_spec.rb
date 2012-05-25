require File.expand_path('../../spec_helper', __FILE__)

describe Pod::LocalPod do

  # a LocalPod represents a local copy of the dependency, inside the pod root, built from a spec
  describe "in general" do
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

    it 'returns an expanded list the files to clean' do
      clean_files = @pod.clean_files.map { |p| p.to_s }
      clean_files.should.include "#{@sandbox.root}/BananaLib/.git/config"
      clean_files.reject { |p| p.to_s.include?('/.git/') }.should == ["#{@sandbox.root}/BananaLib/sub-dir/sub-dir-2/somefile.txt"]
    end

    it 'returns an expanded list of resources, relative to the sandbox root' do
      @pod.resources.should == [Pathname.new("BananaLib/Resources/logo-sidebar.png")]
    end

    it 'returns a list of header files' do
      @pod.header_files.should == [Pathname.new("BananaLib/Classes/Banana.h")]
    end

    it "can link it's headers into the sandbox" do
      @pod.link_headers
      expected_header_path = @sandbox.headers_root + "BananaLib/Banana.h"
      expected_header_path.should.be.symlink
      File.read(expected_header_path).should == (@sandbox.root + @pod.header_files[0]).read
    end

    it "can add it's source files to an Xcode project target" do
      target = mock('target')
      target.expects(:add_source_file).with(Pathname.new("BananaLib/Classes/Banana.h"), anything, anything)
      target.expects(:add_source_file).with(Pathname.new("BananaLib/Classes/Banana.m"), anything, anything)
      @pod.add_to_target(target)
    end

    it "can add it's source files to a target with any specially configured compiler flags" do
      @pod.top_specification.compiler_flags = '-d some_flag'
      target = mock('target')
      target.expects(:add_source_file).twice.with(anything, anything, "-d some_flag")
      @pod.add_to_target(target)
    end

    it "returns the platform" do
      @pod.platform.should == :ios
    end

    it "raises if the files are accessed before creating the pod dir" do
      @pod.implode
      lambda { @pod.source_files }.should.raise Pod::Informative
    end
  end

  describe "with installed source," do
    #before do
    #config.project_pods_root = fixture('integration')
    #podspec   = fixture('spec-repos/master/SSZipArchive/0.1.0/SSZipArchive.podspec')
    #@spec     = Pod::Specification.from_file(podspec)
    #@destroot = fixture('integration/SSZipArchive')
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

  describe "regarding multiple subspecs" do

    before do
      # specification with only some subspecs activated
      # to check that only the needed files are being activated
      # A fixture is needed.
      #
      # specification = Pod::Spec.new do |s|
      # ...
      # s.xcconfig = ...
      # s.compiler_flags = ...
      # s.subspec 's1' do |s1|
      #   s1.xcconfig = ...
      #   s1.compiler_flags = ...
      #   s1.ns.source_files = 's1.{h,m}'
      # end
      #
      # s.subspec 's2' do |s2|
      #   s2.ns.source_files = 's2.{h,m}'
      # end
      #
      # Add only s1 to the localPod
      # s1 = specification.subspec_by_name(s1)
      # @pod = Pod::LocalPod.new(s1, @sandbox, Pod::Platform.new(:ios))
      # @pod.add_specification(specification)
    end

    xit "returns the subspecs" do
      @pod.subspecs.map{ |s| name }.should == %w[ s1 ]
    end

    xit "resolve the source files" do
      @pod.source_files.should == %w[ s1.h s1.m ]
    end

    xit "resolve the resources" do
    end

    xit "resolve the clean paths" do
      @pod.clean_paths.should == %w[ s2.h s2.m ]
    end

    xit "resolves the used files" do
      @pod.used_files.should == %w[ s1.h s1.m README.md ]
    end

    xit "resolved the header files" do
      @pod.header_files.should == %w[ s1.h ]
    end

    xit "resolves the header files of every subspec" do
      @pod.all_specs_public_header_files.should == %w[ s1.h s2.h ]
    end

    xit "merges the xcconfigs" do
    end

    xit "adds each file to a target with the compiler flags of its specification" do
      # @pod.add_to_target(target)
    end

    xit "can provide the source files of all the subspecs" do
      sources = @pod.all_specs_source_files.map { |p| p.relative_path_from(@sandbox.root).to_s }
      sources.should == %w[ s1.h s1.m s2.h s2.m ]
    end

    xit 'can clean the unused files' do
      # copy fixture to another folder
      @pod.clean
      @pod.clean_paths.tap do |paths|
        paths.each do |path|
          path.should.not.exist
        end
      end
    end

  end
end
