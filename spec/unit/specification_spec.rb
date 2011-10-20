require File.expand_path('../../spec_helper', __FILE__)

describe "A Pod::Specification loaded from a podspec" do
  before do
    @spec = Pod::Specification.from_file(fixture('banana-lib/BananaLib.podspec'))
  end

  it "returns that it's not loaded from a podfile" do
    @spec.should.not.be.podfile
  end

  it "returns the path to the podspec" do
    @spec.defined_in_file.should == fixture('banana-lib/BananaLib.podspec')
  end

  it "returns the directory where the pod should be checked out to" do
    @spec.pod_destroot.should == config.project_pods_root + 'BananaLib'
  end

  it "returns the pod's name" do
    @spec.name.should == 'BananaLib'
  end

  it "returns the pod's version" do
    @spec.version.should == Pod::Version.new('1.0')
  end

  it "returns a list of authors and their email addresses" do
    @spec.authors.should == {
      'Banana Corp' => nil,
      'Monkey Boy' => 'monkey@banana-corp.local'
    }
  end

  it "returns the pod's homepage" do
    @spec.homepage.should == 'http://banana-corp.local/banana-lib.html'
  end

  it "returns the pod's summary" do
    @spec.summary.should == 'Chunky bananas!'
  end

  it "returns the pod's description" do
    @spec.description.should == 'Full of chunky bananas.'
  end

  it "returns the pod's source" do
    @spec.source.should == {
      :git => 'http://banana-corp.local/banana-lib.git',
      :tag => 'v1.0'
    }
  end

  it "returns the pod's source files" do
    @spec.source_files.should == ['Classes/*.{h,m}', 'Vendor']
  end

  it "returns the pod's dependencies" do
    expected = Pod::Dependency.new('monkey', '~> 1.0.1', '< 1.0.9')
    @spec.dependencies.should == [expected]
    @spec.dependency_by_name('monkey').should == expected
  end

  it "returns the pod's xcconfig settings" do
    @spec.xcconfig.to_hash.should == {
      'OTHER_LDFLAGS' => '-framework SystemConfiguration'
    }
  end

  it "has a shortcut to add frameworks to the xcconfig" do
    @spec.frameworks = 'CFNetwork', 'CoreText'
    @spec.xcconfig.to_hash.should == {
      'OTHER_LDFLAGS' => '-framework SystemConfiguration ' \
                         '-framework CFNetwork ' \
                         '-framework CoreText'
    }
  end

  it "has a shortcut to add libraries to the xcconfig" do
    @spec.libraries = 'z', 'xml2'
    @spec.xcconfig.to_hash.should == {
      'OTHER_LDFLAGS' => '-framework SystemConfiguration -lz -lxml2'
    }
  end

  it "returns that it's equal to another specification if the name and version are equal" do
    @spec.should == Pod::Spec.new { |s| s.name = 'BananaLib'; s.version = '1.0' }
    @spec.should.not == Pod::Spec.new { |s| s.name = 'OrangeLib'; s.version = '1.0' }
    @spec.should.not == Pod::Spec.new { |s| s.name = 'BananaLib'; s.version = '1.1' }
    @spec.should.not == Pod::Spec.new
  end

  it "never equals when it's from a Podfile" do
    Pod::Spec.new.should.not == Pod::Spec.new
  end

  it "adds compiler flags if ARC is required" do
    @spec.requires_arc = true
    @spec.compiler_flags.should == " -fobj-arc"

    @spec.compiler_flags = "-Wunused-value"
    @spec.compiler_flags.should == "-Wunused-value -fobj-arc"
  end

end

describe "A Pod::Specification that's part of another pod's source" do
  before do
    @spec = Pod::Specification.new
  end

  it "adds a dependency on the other pod's source, but not the library" do
    @spec.part_of = 'monkey', '>= 1'
    @spec.should.be.part_of_other_pod
    dep = Pod::Dependency.new('monkey', '>= 1')
    @spec.dependencies.should.not == [dep]
    dep.only_part_of_other_pod = true
    @spec.dependencies.should == [dep]
  end

  it "adds a dependency on the other pod's source *and* the library" do
    @spec.part_of_dependency = 'monkey', '>= 1'
    @spec.should.be.part_of_other_pod
    @spec.dependencies.should == [Pod::Dependency.new('monkey', '>= 1')]
  end

  # TODO
  #it "returns the specification of the pod that it's part of" do
  #  @spec.part_of_specification
  #end
  #
  #it "returns the destroot of the pod that it's part of" do
  #  @spec.pod_destroot
  #end
end


describe "A Pod::Specification, with installed source," do
  before do
    config.project_pods_root = fixture('integration')
    podspec   = fixture('spec-repos/master/SSZipArchive/0.1.0/SSZipArchive.podspec')
    @spec     = Pod::Specification.from_file(podspec)
    @destroot = fixture('integration/SSZipArchive')
 end

  after do
    config.project_pods_root = nil
  end

  it "returns the list of files that the source_files pattern expand to" do
    files = @destroot.glob('**/*.{h,c,m}')
    files = files.map { |file| file.relative_path_from(config.project_pods_root) }
    @spec.expanded_source_files.sort.should == files.sort
  end

  it "returns the list of headers" do
    files = @destroot.glob('**/*.h')
    files = files.map { |file| file.relative_path_from(config.project_pods_root) }
    @spec.header_files.sort.should == files.sort
  end

  it "returns the list of implementation files" do
    files = @destroot.glob('**/*.{c,m}')
    files = files.map { |file| file.relative_path_from(config.project_pods_root) }
    @spec.implementation_files.sort.should == files.sort
  end

  it "returns a hash of mappings from the pod's destroot to its header dirs, which by default is just the pod's header dir" do
    @spec.copy_header_mappings.size.should == 1
    @spec.copy_header_mappings[Pathname.new('SSZipArchive')].sort.should == %w{
      SSZipArchive.h
      minizip/crypt.h
      minizip/ioapi.h
      minizip/mztools.h
      minizip/unzip.h
      minizip/zip.h
    }.map { |f| Pathname.new("SSZipArchive/#{f}") }.sort
  end

  it "allows for customization of header mappings by overriding copy_header_mapping" do
    def @spec.copy_header_mapping(from)
      Pathname.new('ns') + from.basename
    end
    @spec.copy_header_mappings.size.should == 1
    @spec.copy_header_mappings[Pathname.new('SSZipArchive/ns')].sort.should == %w{
      SSZipArchive.h
      minizip/crypt.h
      minizip/ioapi.h
      minizip/mztools.h
      minizip/unzip.h
      minizip/zip.h
    }.map { |f| Pathname.new("SSZipArchive/#{f}") }.sort
  end

  it "returns a hash of mappings with a custom header dir prefix" do
    @spec.header_dir = 'AnotherRoot'
    @spec.copy_header_mappings[Pathname.new('AnotherRoot')].sort.should == %w{
      SSZipArchive.h
      minizip/crypt.h
      minizip/ioapi.h
      minizip/mztools.h
      minizip/unzip.h
      minizip/zip.h
    }.map { |f| Pathname.new("SSZipArchive/#{f}") }.sort
  end

  it "returns the user header search paths" do
    def @spec.copy_header_mapping(from)
      Pathname.new('ns') + from.basename
    end
    @spec.user_header_search_paths.should == %w{
      "$(BUILT_PRODUCTS_DIR)/Pods/SSZipArchive"
      "$(BUILT_PRODUCTS_DIR)/Pods/SSZipArchive/ns"
    }
  end

  it "returns the user header search paths with a custom header dir prefix" do
    @spec.header_dir = 'AnotherRoot'
    def @spec.copy_header_mapping(from)
      Pathname.new('ns') + from.basename
    end
    @spec.user_header_search_paths.should == %w{
      "$(BUILT_PRODUCTS_DIR)/Pods/AnotherRoot"
      "$(BUILT_PRODUCTS_DIR)/Pods/AnotherRoot/ns"
    }
  end

  it "returns the list of files that the resources pattern expand to" do
    @spec.expanded_resources.should == []
    @spec.resource = 'LICEN*'
    @spec.expanded_resources.map(&:to_s).should == %w{ SSZipArchive/LICENSE }
    @spec.resources = 'LICEN*', 'Readme.*'
    @spec.expanded_resources.map(&:to_s).should == %w{ SSZipArchive/LICENSE SSZipArchive/Readme.markdown }
  end
end

describe "A Pod::Specification, in general," do
  before do
    @spec = Pod::Spec.new
  end

  def validate(&block)
    Proc.new(&block).should.raise(Pod::Informative)
  end

  it "raises if the specification does not contain the minimum required attributes" do
    exception = validate { @spec.validate! }
    exception.message =~ /name.+?version.+?summary.+?homepage.+?authors.+?(source|part_of).+?source_files/
  end

  it "raises if the platform is unrecognized" do
    validate { @spec.validate! }.message.should.not.include 'platform'
    @spec.platform = :ios
    validate { @spec.validate! }.message.should.not.include 'platform'
    @spec.platform = :osx
    validate { @spec.validate! }.message.should.not.include 'platform'
    @spec.platform = :windows
    validate { @spec.validate! }.message.should.include 'platform'
 end

  it "returns the platform that the static library should be build for" do
    @spec.platform = :ios
    @spec.platform.should == :ios
  end
end
