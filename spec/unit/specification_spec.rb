require File.expand_path('../../spec_helper', __FILE__)

describe "A Pod::Specification loaded from a Podfile" do
  before do
    @spec = Pod::Specification.from_podfile(fixture('Podfile'))
  end

  it "lists the project's dependencies" do
    @spec.dependencies.should == [
      Pod::Dependency.new('SSZipArchive',      '>= 1'),
      Pod::Dependency.new('ASIHTTPRequest',    '~> 1.8.0'),
      Pod::Dependency.new('Reachability',      '>= 0'),
      Pod::Dependency.new('ASIWebPageRequest', ' < 1.8.2')
    ]
  end

  it "returns the path to the Podfile" do
    @spec.defined_in_file.should == fixture('Podfile')
  end

  it "returns that it's loaded from a Podfile" do
    @spec.should.be.from_podfile
  end

  it "does not have a destroot" do
    @spec.pod_destroot.should == nil
  end
end

describe "A Pod::Specification loaded from a podspec" do
  before do
    @spec = Pod::Specification.from_podspec(fixture('banana-lib/BananaLib.podspec'))
  end

  it "returns that it's not loaded from a podfile" do
    @spec.should.not.be.from_podfile
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
    @spec.source_files.should == [
      Pathname.new('Classes/*.{h,m}'),
      Pathname.new('Vendor')
    ]
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
      'OTHER_LDFLAGS' => '-framework SystemConfiguration -l z -l xml2'
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
    @spec     = Pod::Specification.from_podspec(podspec)
    @destroot = fixture('integration/SSZipArchive')
 end

  after do
    config.project_pods_root = nil
  end

  it "returns the list of files that the source_files pattern expands to" do
    files = @destroot.glob('**/*.{h,c,m}')
    files = files.map { |file| file.relative_path_from(@destroot) }
    @spec.expanded_source_files.sort.should == files.sort
  end

  it "returns the list of headers" do
    files = @destroot.glob('**/*.h')
    files = files.map { |file| file.relative_path_from(@destroot) }
    @spec.header_files.sort.should == files.sort
  end

  it "returns the list of implementation files" do
    files = @destroot.glob('**/*.{c,m}')
    files = files.map { |file| file.relative_path_from(@destroot) }
    @spec.implementation_files.sort.should == files.sort
  end

  it "returns a hash of mappings from the pod's destroot to its header dirs, which by default is just the pod's header dir" do
    @spec.copy_header_mappings.size.should == 1
    @spec.copy_header_mappings['.'].sort.should == %w{
      SSZipArchive.h
      minizip/crypt.h
      minizip/ioapi.h
      minizip/mztools.h
      minizip/unzip.h
      minizip/zip.h
    }.map { |f| Pathname.new(f) }.sort
  end

  it "allows for customization of header mappings by overriding copy_header_mapping" do
    def @spec.copy_header_mapping(from)
      Pathname.new('ns') + from.basename
    end
    @spec.copy_header_mappings.size.should == 1
    @spec.copy_header_mappings['ns'].sort.should == %w{
      SSZipArchive.h
      minizip/crypt.h
      minizip/ioapi.h
      minizip/mztools.h
      minizip/unzip.h
      minizip/zip.h
    }.map { |f| Pathname.new(f) }.sort
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
end

describe "A Pod::Specification, in general," do
  it "raises if the specification does not contain the minimum required attributes" do
    exception = lambda {
      Pod::Spec.new.validate!
    }.should.raise Pod::Informative
    exception.message =~ /name.+?version.+?summary.+?homepage.+?authors.+?(source|part_of).+?source_files/
  end
end
