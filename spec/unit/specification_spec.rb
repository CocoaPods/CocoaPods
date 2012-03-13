require File.expand_path('../../spec_helper', __FILE__)

describe "A Pod::Specification loaded from a podspec" do
  before do
    fixture('banana-lib') # ensure the archive is unpacked
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
    @spec.dependency_by_top_level_spec_name('monkey').should == expected
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
    @spec.compiler_flags.should == " -fobjc-arc"

    @spec.compiler_flags = "-Wunused-value"
    @spec.compiler_flags.should == "-Wunused-value -fobjc-arc"
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

# TODO: This is really what a LocalPod now represents
# Which probably means most of this functionality should move there
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
    @spec.header_search_paths.should == %w{
      "$(PODS_ROOT)/Headers/SSZipArchive"
      "$(PODS_ROOT)/Headers/SSZipArchive/ns"
    }
  end

  it "returns the user header search paths with a custom header dir prefix" do
    @spec.header_dir = 'AnotherRoot'
    def @spec.copy_header_mapping(from)
      Pathname.new('ns') + from.basename
    end
    @spec.header_search_paths.should == %w{
      "$(PODS_ROOT)/Headers/AnotherRoot"
      "$(PODS_ROOT)/Headers/AnotherRoot/ns"
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

  it "returns the license of the Pod" do
    @spec.license = {
      :type => 'MIT',
      :file => 'LICENSE',
      :range => 1..15,
      :text => 'Permission is hereby granted ...'
    }
    @spec.license.should == {
      :type => 'MIT',
      :file => 'LICENSE',
      :range => 1..15,
      :text => 'Permission is hereby granted ...'
    }
  end
  
  it "returns the license of the Pod specified in the old format" do
    @spec.license = 'MIT'
    @spec.license.should == {
      :type => 'MIT',
    }
  end

  it "returns the documentation of the Pod" do
    @spec.documentation = {
      :html => 'http://EXAMPLE/#{@name}/documentation',
      :atom => 'http://EXAMPLE/#{@name}/com.company.#{@name}.atom',
      :appledoc => ['--project-name', '#{@name}',
                    '--project-company', '"Company Name"',
                    '--company-id', 'com.company',
                    '--ignore', 'Common',
                    '--ignore', '.m'] 
    }
    @spec.documentation.should == {
      :html => 'http://EXAMPLE/#{@name}/documentation',
      :atom => 'http://EXAMPLE/#{@name}/com.company.#{@name}.atom',
      :appledoc => ['--project-name', '#{@name}',
                    '--project-company', '"Company Name"',
                    '--company-id', 'com.company',
                    '--ignore', 'Common',
                    '--ignore', '.m'] 
    }
  end

  it "takes a list of paths to clean" do
    @spec.clean_paths = 'Demo', 'Doc'
    @spec.clean_paths.should == %w{ Demo Doc }
  end

  it "takes any object for clean_paths as long as it responds to #glob (we provide this for Rake::FileList)" do
    @spec.clean_paths = Pod::FileList['*'].exclude('Rakefile')
    list = ROOT + @spec.clean_paths.first
    list.glob.should == Pod::FileList[(ROOT + '*').to_s].exclude('Rakefile').map { |path| Pathname.new(path) }
  end
end

describe "A Pod::Specification subspec" do
  before do
    @spec = Pod::Spec.new do |s|
      s.name    = 'MainSpec'
      s.version = '1.2.3'
      s.platform = :ios
      s.license = 'MIT'
      s.author = 'Joe the Plumber'
      s.summary = 'A spec with subspecs'
      s.source  = { :git => '/some/url' }
      s.requires_arc = true

      s.subspec 'FirstSubSpec' do |fss|
        fss.source_files = 'some/file'

        fss.subspec 'SecondSubSpec' do |sss|
        end
      end
    end
  end

  it "makes a parent spec a wrapper if it has no source files of its own" do
    @spec.should.be.wrapper
    @spec.subspecs.first.should.not.be.wrapper
  end

  it "returns the top level parent spec" do
    @spec.subspecs.first.top_level_parent.should == @spec
    @spec.subspecs.first.subspecs.first.top_level_parent.should == @spec
  end

  it "is named after the parent spec" do
    @spec.subspecs.first.name.should == 'MainSpec/FirstSubSpec'
    @spec.subspecs.first.subspecs.first.name.should == 'MainSpec/FirstSubSpec/SecondSubSpec'
  end

  it "is a `part_of' the top level parent spec" do
    dependency = Pod::Dependency.new('MainSpec', '1.2.3').tap { |d| d.only_part_of_other_pod = true }
    @spec.subspecs.first.part_of.should == dependency
    @spec.subspecs.first.subspecs.first.part_of.should == dependency
  end

  it "depends on the parent spec, if it is a subspec" do
    dependency = Pod::Dependency.new('MainSpec', '1.2.3').tap { |d| d.only_part_of_other_pod = true }
    @spec.subspecs.first.dependencies.should == [dependency]
    @spec.subspecs.first.subspecs.first.dependencies.should == [dependency, Pod::Dependency.new('MainSpec/FirstSubSpec', '1.2.3')]
  end

  it "automatically forwards undefined attributes to the top level parent" do
    [:version, :summary, :platform, :license, :authors, :requires_arc, :compiler_flags].each do |attr|
      @spec.subspecs.first.send(attr).should == @spec.send(attr)
      @spec.subspecs.first.subspecs.first.send(attr).should == @spec.send(attr)
    end
  end

  it "returns subspecs by name" do
    @spec.subspec_by_name('MainSpec/FirstSubSpec').should == @spec.subspecs.first
    @spec.subspec_by_name('MainSpec/FirstSubSpec/SecondSubSpec').should == @spec.subspecs.first.subspecs.first
  end
end

describe "A Pod::Specification with :local source" do
  before do
    @spec = Pod::Spec.new do |s|
      s.name    = 'MainSpec'
      s.source  = { :local => fixture("integration/JSONKit") }
      s.source_files = "."
    end
  end
  
  it "is marked as local" do
    @spec.should.be.local
  end
  
  it "it returns the expanded local path" do
    @spec.local_path.should == fixture("integration/JSONKit")
  end
  
  it "returns the list of files that the source_files pattern expand to within the local path" do
    files = fixture("integration/JSONKit").glob('**/*.{h,m}')
    files = files.map { |file| file.relative_path_from(config.project_pods_root) }
    @spec.expanded_source_files.sort.should == files.sort
  end
  
  it "returns the list of headers that the source_files pattern expand to within the local path" do
    files = fixture("integration/JSONKit").glob('**/*.{h}')
    files = files.map { |file| file.relative_path_from(config.project_pods_root) }
    @spec.header_files.sort.should == files.sort
  end
end

