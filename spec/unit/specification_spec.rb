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

  it "takes a list of paths to preserve" do
    @spec.preserve_paths = 'script.sh'
    @spec.activate_platform(:ios).preserve_paths.should == %w{ script.sh }
  end

  it "takes any object for source_files as long as it responds to #glob (we provide this for Rake::FileList)" do
    @spec.source_files = Pod::FileList['*'].exclude('Rakefile')
    @spec.activate_platform(:ios)
    list = ROOT + @spec.source_files.first
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

  it "can be activated for a supported platorm" do
    @spec.platform = :ios
    lambda {@spec.activate_platform(:ios)}.should.not.raise Pod::Informative
  end

  it "raised if attempted to be activated for an unsupported platform" do
    @spec.platform = :osx, '10.7'
    lambda {@spec.activate_platform(:ios)}.should.raise Pod::Informative
    lambda {@spec.activate_platform(:ios, '10.6')}.should.raise Pod::Informative
  end

  it "raises if not activated for a platform before accessing a multiplatform value" do
    @spec.platform = :ios
    lambda {@spec.source_files}.should.raise Pod::Informative
  end

  it "returns self on activation for method chainablity" do
    @spec.platform = :ios
    @spec.activate_platform(:ios).should == @spec
  end
end

describe "A Pod::Specification, hierarchy" do
  before do
    @spec = Pod::Spec.new do |s|
      s.name      = 'MainSpec'
      s.version   = '0.999'
      s.dependency  'awesome_lib'
      s.subspec 'SubSpec.0' do |fss|
        fss.platform  = :ios
        fss.subspec 'SubSpec.0.0' do |sss|
        end
      end
      s.subspec 'SubSpec.1'
    end
    @subspec = @spec.subspecs.first
    @spec.activate_platform(:ios)
  end

  it "automatically includes all the compatible subspecs as a dependencis if not preference is given" do
    @spec.dependencies.map { |s| s.name }.should == %w[ awesome_lib MainSpec/SubSpec.0 MainSpec/SubSpec.1 ]
    @spec.activate_platform(:osx).dependencies.map { |s| s.name }.should == %w[ awesome_lib MainSpec/SubSpec.1 ]
  end

  it "uses the spec version for the dependencies" do
    @spec.dependencies.
      select { |d| d.name =~ /MainSpec/ }.
      all?   { |d| d.requirement === Pod::Version.new('0.999') }.
      should.be.true
  end

  it "respecs the preferred dependency for subspecs, if specified" do
    @spec.preferred_dependency = 'SubSpec.0'
    @spec.dependencies.map { |s| s.name }.should == %w[ awesome_lib MainSpec/SubSpec.0 ]
  end

  it "raises if it has dependecy on a self or on an upstream subspec" do
    lambda { @subspec.dependency('MainSpec/SubSpec.0') }.should.raise Pod::Informative
    lambda { @subspec.dependency('MainSpec') }.should.raise Pod::Informative
  end

  it "inherits external dependecies from the parent" do
    @subspec.dependencies.map { |s| s.name }.should == %w[ awesome_lib MainSpec/SubSpec.0/SubSpec.0.0 ]
  end

  it "it accepts a dependency on a subspec that is in the same level of the hierarchy" do
    @subspec.dependency('MainSpec/SubSpec.1')
    @subspec.dependencies.map { |s| s.name }.should == %w[ MainSpec/SubSpec.1 awesome_lib MainSpec/SubSpec.0/SubSpec.0.0 ]
  end
end

describe "A Pod::Specification subspec" do
  before do
    @spec = Pod::Spec.new do |s|
      s.name         = 'MainSpec'
      s.version      = '1.2.3'
      s.license      = 'MIT'
      s.author       = 'Joe the Plumber'
      s.source       = { :git => '/some/url' }
      s.requires_arc = true
      s.source_files = 'spec.m'
      s.resource     = 'resource'
      s.platform     = :ios
      s.library      = 'xml'
      s.framework    = 'CoreData'

      s.subspec 'FirstSubSpec' do |fss|
        fss.ios.source_files  = 'subspec_ios.m'
        fss.osx.source_files  = 'subspec_osx.m'
        fss.framework         = 'CoreGraphics'
        fss.library           = 'z'

        fss.subspec 'SecondSubSpec' do |sss|
          sss.source_files = 'subsubspec.m'
        end
      end
    end
    @subspec = @spec.subspecs.first
    @subsubspec = @subspec.subspecs.first
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

  it "automatically forwards top level attributes to the top level parent" do
    @spec.activate_platform(:ios)
    [:version, :license, :authors, :requires_arc].each do |attr|
      @spec.subspecs.first.send(attr).should == @spec.send(attr)
      @spec.subspecs.first.subspecs.first.send(attr).should == @spec.send(attr)
    end
  end

  it "resolves correctly chained attributes" do
    @spec.activate_platform(:ios)
    @spec.source_files.map { |f| f.to_s }.should == %w[ spec.m  ]
    @subspec.source_files.map { |f| f.to_s }.should == %w[ spec.m  subspec_ios.m ]
    @subsubspec.source_files.map { |f| f.to_s }.should == %w[ spec.m  subspec_ios.m subsubspec.m ]

    @subsubspec.resources.should == %w[ resource ]
  end

  it "returns empty arrays for chained attributes with no value in the chain" do
    @spec = Pod::Spec.new do |s|
      s.name         = 'MainSpec'
      s.platform     = :ios
      s.subspec 'FirstSubSpec' do |fss|
        fss.subspec 'SecondSubSpec' do |sss|
          sss.source_files = 'subsubspec.m'
        end
      end
    end

    @spec.activate_platform(:ios).source_files.should == []
    @spec.subspecs.first.source_files.should == []
    @spec.subspecs.first.subspecs.first.source_files.should == %w[ subsubspec.m ]
  end

  it "does not cache platform attributes and can activate another platform" do
    @spec.platform = nil
    @spec.activate_platform(:ios)
    @subsubspec.source_files.map { |f| f.to_s }.should == %w[ spec.m  subspec_ios.m subsubspec.m ]
    @spec.activate_platform(:osx)
    @subsubspec.source_files.map { |f| f.to_s }.should == %w[ spec.m  subspec_osx.m subsubspec.m ]
  end

  it "resolves correctly the available platforms" do
    @spec.platform = nil
    @subspec.platform = :ios, '4.0'
    @spec.available_platforms.map{ |p| p.to_sym }.should == [ :osx, :ios ]
    @subspec.available_platforms.first.to_sym.should == :ios
    @subsubspec.available_platforms.first.to_sym.should == :ios

    @subsubspec.platform = :ios, '5.0'
    @subspec.available_platforms.first.deployment_target.to_s.should == '4.0'
    @subsubspec.available_platforms.first.deployment_target.to_s.should == '5.0'
  end

  it "resolves reports correctly the supported platforms" do
    @spec.platform = nil
    @subspec.platform = :ios, '4.0'
    @subsubspec.platform = :ios, '5.0'
    @spec.supports_platform?(:ios).should.be.true
    @spec.supports_platform?(:osx).should.be.true
    @subspec.supports_platform?(:ios).should.be.true
    @subspec.supports_platform?(:osx).should.be.false
    @subspec.supports_platform?(:ios, '4.0').should.be.true
    @subspec.supports_platform?(:ios, '5.0').should.be.true
    @subsubspec.supports_platform?(:ios).should.be.true
    @subsubspec.supports_platform?(:osx).should.be.false
    @subsubspec.supports_platform?(:ios, '4.0').should.be.false
    @subsubspec.supports_platform?(:ios, '5.0').should.be.true
    @subsubspec.supports_platform?(Pod::Platform.new(:ios, '4.0')).should.be.false
    @subsubspec.supports_platform?(Pod::Platform.new(:ios, '5.0')).should.be.true
  end

  it "raises a top level attribute is assigned to a spec with a parent" do
    lambda { @subspec.version = '0.0.1' }.should.raise Pod::Informative
  end

  it "returns subspecs by name" do
    @spec.subspec_by_name(nil).should == @spec
    @spec.subspec_by_name('MainSpec').should == @spec
    @spec.subspec_by_name('MainSpec/FirstSubSpec').should == @subspec
    @spec.subspec_by_name('MainSpec/FirstSubSpec/SecondSubSpec').should == @subsubspec
  end

  it "has the same active platform accross the chain attributes" do
    @spec.activate_platform(:ios)
    @subspec.active_platform.should == :ios
    @subsubspec.active_platform.should == :ios

    @spec.platform = nil
    @subsubspec.activate_platform(:osx)
    @subspec.active_platform.should == :osx
    @spec.active_platform.should == :osx
  end

  it "resolves the libraries correctly" do
    @spec.activate_platform(:ios)
    @spec.libraries.should       == %w[ xml ]
    @subspec.libraries.should    == %w[ xml z ]
    @subsubspec.libraries.should == %w[ xml z ]
  end

  it "resolves the frameworks correctly" do
    @spec.activate_platform(:ios)
    @spec.frameworks.should       == %w[ CoreData ]
    @subspec.frameworks.should    == %w[ CoreData CoreGraphics ]
    @subsubspec.frameworks.should == %w[ CoreData CoreGraphics ]
  end

  it "resolves the xcconfig" do
    @spec.activate_platform(:ios)
    @spec.xcconfig = { 'OTHER_LDFLAGS' => "-Wl,-no_compact_unwind" }

    @spec.xcconfig.should       == {"OTHER_LDFLAGS"=>"-Wl,-no_compact_unwind -lxml -framework CoreData"}
    @subspec.xcconfig.should    == {"OTHER_LDFLAGS"=>"-Wl,-no_compact_unwind -lxml -lz -framework CoreData -framework CoreGraphics"}
    @subsubspec.xcconfig.should == {"OTHER_LDFLAGS"=>"-Wl,-no_compact_unwind -lxml -lz -framework CoreData -framework CoreGraphics"}

    @subsubspec.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

    @spec.xcconfig.should       == {"OTHER_LDFLAGS"=>"-Wl,-no_compact_unwind -lxml -framework CoreData"}
    @subsubspec.xcconfig.should == {"OTHER_LDFLAGS"=>"-Wl,-no_compact_unwind -lxml -lz -framework CoreData -framework CoreGraphics", "HEADER_SEARCH_PATHS"=>"$(SDKROOT)/usr/include/libxml2"}
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
