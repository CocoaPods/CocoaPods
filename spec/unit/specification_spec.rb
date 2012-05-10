require File.expand_path('../../spec_helper', __FILE__)

describe "A Pod::Specification loaded from a podspec" do
  before do
    fixture('banana-lib') # ensure the archive is unpacked
    @spec = Pod::Specification.from_file(fixture('banana-lib/BananaLib.podspec'))
  end

  it "has no parent if it is the top level spec" do
    @spec.parent.nil?.should == true
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
    @spec.activate_platform(:ios).source_files.should == ['Classes/*.{h,m}', 'Vendor']
    @spec.activate_platform(:osx).source_files.should == ['Classes/*.{h,m}', 'Vendor']
  end

  it "returns the pod's dependencies" do
    expected = Pod::Dependency.new('monkey', '~> 1.0.1', '< 1.0.9')
    @spec.activate_platform(:ios).dependencies.should == [expected]
    @spec.activate_platform(:osx).dependencies.should == [expected]
  end

  it "returns the pod's xcconfig settings" do
    @spec.activate_platform(:ios).xcconfig.should == { 'OTHER_LDFLAGS' => '-framework SystemConfiguration' }
  end

  it "has a shortcut to add frameworks to the xcconfig" do
    @spec.frameworks = 'CFNetwork', 'CoreText'
    @spec.activate_platform(:ios).xcconfig.should == {
      'OTHER_LDFLAGS' => '-framework SystemConfiguration ' \
                         '-framework CFNetwork ' \
                         '-framework CoreText'
    }
  end

  it "has a shortcut to add libraries to the xcconfig" do
    @spec.libraries = 'z', 'xml2'
    @spec.activate_platform(:ios).xcconfig.should == {
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
    @spec.parent.should == nil
    @spec.requires_arc = true
    @spec.activate_platform(:ios).compiler_flags.should == " -fobjc-arc"
    @spec.activate_platform(:osx).compiler_flags.should == " -fobjc-arc"
    @spec.compiler_flags = "-Wunused-value"
    @spec.activate_platform(:ios).compiler_flags.should == " -fobjc-arc -Wunused-value"
    @spec.activate_platform(:osx).compiler_flags.should == " -fobjc-arc -Wunused-value"
  end
end

describe "A Pod::Specification, in general," do
  before do
    @spec = Pod::Spec.new
  end

  it "returns the platform that the static library should be build for" do
    @spec.platform = :ios
    @spec.platform.should == :ios
  end

  it "returns the platform and the deployment target" do
    @spec.platform = :ios, '4.0'
    @spec.platform.should == :ios
    @spec.platform.deployment_target.should == Pod::Version.new('4.0')
  end

  it "returns the available platforms for which the pod is supported" do
    @spec.platform = :ios, '4.0'
    @spec.available_platforms.count.should == 1
    @spec.available_platforms.first.should == :ios
    @spec.available_platforms.first.deployment_target.should == Pod::Version.new('4.0')
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
      :appledoc => ['--project-name', '#{@name}',
                    '--project-company', '"Company Name"',
                    '--company-id', 'com.company',
                    '--ignore', 'Common',
                    '--ignore', '.m']
    }
    @spec.documentation[:html].should == 'http://EXAMPLE/#{@name}/documentation'
    @spec.documentation[:appledoc].should == ['--project-name', '#{@name}',
                                          '--project-company', '"Company Name"',
                                          '--company-id', 'com.company',
                                          '--ignore', 'Common',
                                          '--ignore', '.m']
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

  it "takes a prefix header path which will be appended to the Pods pch file" do
    @spec.prefix_header_file.should == nil
    @spec.prefix_header_file = 'Classes/Demo.pch'
    @spec.prefix_header_file.should == Pathname.new('Classes/Demo.pch')
  end

  it "takes code that's to be appended to the Pods pch file" do
    @spec.prefix_header_contents.should == nil
    @spec.prefix_header_contents = '#import "BlocksKit.h"'
    @spec.prefix_header_contents.should == '#import "BlocksKit.h"'
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

  it "returns the top level parent spec" do
    @spec.subspecs.first.top_level_parent.should == @spec
    @spec.subspecs.first.subspecs.first.top_level_parent.should == @spec
  end

  it "is named after the parent spec" do
    @spec.subspecs.first.name.should == 'MainSpec/FirstSubSpec'
    @spec.subspecs.first.subspecs.first.name.should == 'MainSpec/FirstSubSpec/SecondSubSpec'
  end

  it "correctly resolves the inheritance chain" do
    @spec.subspecs.first.subspecs.first.parent.should == @spec.subspecs.first
    @spec.subspecs.first.parent.should == @spec
  end

  it "automatically forwards undefined attributes to the top level parent" do
    @spec.activate_platform(:ios)
    [:version, :summary, :platform, :license, :authors, :requires_arc].each do |attr|
      @spec.subspecs.first.send(attr).should == @spec.send(attr)
      @spec.subspecs.first.subspecs.first.send(attr).should == @spec.send(attr)
    end
  end

  it "returns subspecs by name" do
    @spec.subspec_by_name(nil).should == @spec
    @spec.subspec_by_name('MainSpec').should == @spec
    @spec.subspec_by_name('MainSpec/FirstSubSpec').should == @spec.subspecs.first
    @spec.subspec_by_name('MainSpec/FirstSubSpec/SecondSubSpec').should == @spec.subspecs.first.subspecs.first
  end

  xit "can be activated for a platorm"
  xit "raises if not activated"
  xit "returns self on activation for method chainablity"
  xit "does not cache platform attributes and can activate another platform"
  xit "resolves chained attributes"
  xit "resolves not chained attributes"
  xit "has the same active platform accross the chain attributes"
  xit "raises a top level attribute is assigned to a spec with a parent"

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
end

describe "A Pod::Specification, concerning its attributes that support different values per platform," do
  describe "when **no** platform specific values are given" do
    before do
      @spec = Pod::Spec.new do |s|
        s.source_files   = 'file1', 'file2'
        s.resources      = 'file1', 'file2'
        s.xcconfig       =  { 'OTHER_LDFLAGS' => '-lObjC' }
        s.framework      = 'QuartzCore'
        s.library        = 'z'
        s.compiler_flags = '-Wdeprecated-implementations'
        s.requires_arc   = true

        s.dependency 'JSONKit'
        s.dependency 'SSZipArchive'
      end
    end

    it "returns the same list of source files for each platform" do
      @spec.activate_platform(:ios).source_files.should == %w{ file1 file2 }
      @spec.activate_platform(:osx).source_files.should == %w{ file1 file2 }
    end

    it "returns the same list of resources for each platform" do
      @spec.activate_platform(:ios).resources.should == %w{ file1 file2 }
      @spec.activate_platform(:osx).resources.should == %w{ file1 file2 }
    end

    it "returns the same list of xcconfig build settings for each platform" do
      build_settings = { 'OTHER_LDFLAGS' => '-lObjC -lz -framework QuartzCore' }
      @spec.activate_platform(:ios).xcconfig.should == build_settings 
      @spec.activate_platform(:osx).xcconfig.should == build_settings 
    end

    it "returns the same list of compiler flags for each platform" do
      compiler_flags = ' -fobjc-arc -Wdeprecated-implementations'
      @spec.activate_platform(:ios).compiler_flags.should == compiler_flags
      @spec.activate_platform(:osx).compiler_flags.should == compiler_flags
    end

    it "returns the same list of dependencies for each platform" do
      dependencies = %w{ JSONKit SSZipArchive }.map { |name| Pod::Dependency.new(name) }
      @spec.activate_platform(:ios).dependencies.should == dependencies
      @spec.activate_platform(:osx).dependencies.should == dependencies
    end
  end

  describe "when platform specific values are given" do
    before do
      @spec = Pod::Spec.new do |s|
        s.ios.source_files   = 'file1'
        s.osx.source_files   = 'file1', 'file2'

        s.ios.resource       = 'file1'
        s.osx.resources      = 'file1', 'file2'

        s.ios.xcconfig       = { 'OTHER_LDFLAGS' => '-lObjC' }
        s.osx.xcconfig       = { 'OTHER_LDFLAGS' => '-lObjC -all_load' }

        s.ios.framework      = 'QuartzCore'
        s.osx.frameworks     = 'QuartzCore', 'CoreData'

        s.ios.library        = 'z'
        s.osx.libraries      = 'z', 'xml'

        s.ios.compiler_flags = '-Wdeprecated-implementations'
        s.osx.compiler_flags = '-Wfloat-equal'

        s.requires_arc   = true # does not take platform options, just here to check it's added to compiler_flags

        s.ios.dependency 'JSONKit'
        s.osx.dependency 'SSZipArchive'

        s.ios.deployment_target = '4.0'
      end
    end

    it "returns a different list of source files for each platform" do
      @spec.activate_platform(:ios).source_files.should == %w{ file1 }
      @spec.activate_platform(:osx).source_files.should == %w{ file1 file2 }
    end

    it "returns a different list of resources for each platform" do
      @spec.activate_platform(:ios).resources.should == %w{ file1 }
      @spec.activate_platform(:osx).resources.should == %w{ file1 file2 }
    end

    it "returns a different list of xcconfig build settings for each platform" do
      @spec.activate_platform(:ios).xcconfig.should == { 'OTHER_LDFLAGS' => '-lObjC -lz -framework QuartzCore' }
      @spec.activate_platform(:osx).xcconfig.should == { 'OTHER_LDFLAGS' => '-lObjC -all_load -lz -lxml -framework QuartzCore -framework CoreData' }
    end

    it "returns the list of the supported platfroms and deployment targets" do
     @spec.available_platforms.count.should == 2
     @spec.available_platforms.should.include? Pod::Platform.new(:osx)
     @spec.available_platforms.should.include? Pod::Platform.new(:ios, '4.0')
    end

    it "returns the same list of compiler flags for each platform" do
      @spec.activate_platform(:ios).compiler_flags.should == ' -fobjc-arc -Wdeprecated-implementations'
      @spec.activate_platform(:osx).compiler_flags.should == ' -fobjc-arc -Wfloat-equal'
    end

    it "returns the same list of dependencies for each platform" do
      @spec.activate_platform(:ios).dependencies.should == [Pod::Dependency.new('JSONKit')]
      @spec.activate_platform(:osx).dependencies.should == [Pod::Dependency.new('SSZipArchive')]
    end
  end
end
