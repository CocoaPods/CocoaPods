require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Podfile" do
  it "loads from a file" do
    podfile = Pod::Podfile.from_file(fixture('Podfile'))
    podfile.defined_in_file.should == fixture('Podfile')
  end

  it "assigns the platform attribute" do
    podfile = Pod::Podfile.new { platform :ios }
    podfile.platform.should == :ios
  end

  it "adds dependencies" do
    podfile = Pod::Podfile.new { dependency 'ASIHTTPRequest'; dependency 'SSZipArchive', '>= 0.1' }
    podfile.dependencies.size.should == 2
    podfile.dependency_by_top_level_spec_name('ASIHTTPRequest').should == Pod::Dependency.new('ASIHTTPRequest')
    podfile.dependency_by_top_level_spec_name('SSZipArchive').should == Pod::Dependency.new('SSZipArchive', '>= 0.1')
  end

  it "adds a dependency on a Pod repo outside of a spec repo (the repo is expected to contain a podspec)" do
    podfile = Pod::Podfile.new do
      dependency 'SomeExternalPod', :git => 'GIT-URL', :commit => '1234'
    end
    dep = podfile.dependency_by_top_level_spec_name('SomeExternalPod')
    dep.external_source.params.should == { :git => 'GIT-URL', :commit => '1234' }
  end

  it "adds a dependency on a library outside of a spec repo (the repo does not need to contain a podspec)" do
    podfile = Pod::Podfile.new do
      dependency 'SomeExternalPod', :podspec => 'http://gist/SomeExternalPod.podspec'
    end
    dep = podfile.dependency_by_top_level_spec_name('SomeExternalPod')
    dep.external_source.params.should == { :podspec => 'http://gist/SomeExternalPod.podspec' }
  end

  it "adds a dependency on a library by specifying the podspec inline" do
    podfile = Pod::Podfile.new do
      dependency do |s|
        s.name = 'SomeExternalPod'
      end
    end
    dep = podfile.dependency_by_top_level_spec_name('SomeExternalPod')
    dep.specification.name.should == 'SomeExternalPod'
  end

  it "specifies that BridgeSupport metadata should be generated" do
    Pod::Podfile.new {}.should.not.generate_bridge_support
    Pod::Podfile.new { generate_bridge_support! }.should.generate_bridge_support
  end
  
  it 'specifies that ARC compatibility flag should be generated' do
    Pod::Podfile.new { set_arc_compatibility_flag! }.should.set_arc_compatibility_flag
  end

  it "stores a block that will be called with the Installer instance once installation is finished (but the project is not written to disk yet)" do
    yielded = nil
    Pod::Podfile.new do
      post_install do |installer|
        yielded = installer
      end
    end.post_install!(:an_installer)
    yielded.should == :an_installer
  end

  describe "concerning targets (dependency groups)" do
    it "returns wether or not a target has any dependencies" do
      Pod::Podfile.new do
      end.target_definitions[:default].should.be.empty
      Pod::Podfile.new do
        dependency 'JSONKit'
      end.target_definitions[:default].should.not.be.empty
    end

    before do
      @podfile = Pod::Podfile.new do
        target :debug do
          dependency 'SSZipArchive'
        end

        target :test, :exclusive => true do
          dependency 'JSONKit'
          target :subtarget do
            dependency 'Reachability'
          end
        end

        dependency 'ASIHTTPRequest'
      end
    end

    it "returns all dependencies of all targets combined, which is used during resolving to enusre compatible dependencies" do
      @podfile.dependencies.map(&:name).sort.should == %w{ ASIHTTPRequest JSONKit Reachability SSZipArchive }
    end

    it "adds dependencies outside of any explicit target block to the default target" do
      target = @podfile.target_definitions[:default]
      target.lib_name.should == 'Pods'
      target.dependencies.should == [Pod::Dependency.new('ASIHTTPRequest')]
    end

    it "adds dependencies of the outer target to non-exclusive targets" do
      target = @podfile.target_definitions[:debug]
      target.lib_name.should == 'Pods-debug'
      target.dependencies.sort_by(&:name).should == [
        Pod::Dependency.new('ASIHTTPRequest'),
        Pod::Dependency.new('SSZipArchive')
      ]
    end

    it "does not add dependencies of the outer target to exclusive targets" do
      target = @podfile.target_definitions[:test]
      target.lib_name.should == 'Pods-test'
      target.dependencies.should == [Pod::Dependency.new('JSONKit')]
    end

    it "adds dependencies of the outer target to nested targets" do
      target = @podfile.target_definitions[:subtarget]
      target.lib_name.should == 'Pods-test-subtarget'
      target.dependencies.should == [Pod::Dependency.new('Reachability'), Pod::Dependency.new('JSONKit')]
    end
  end

  describe "concerning validations" do
    it "raises if no platform is specified" do
      exception = lambda {
        Pod::Podfile.new {}.validate!
      }.should.raise Pod::Informative
      exception.message.should.include "platform"
    end

    it "raises if an invalid platform is specified" do
      exception = lambda {
        Pod::Podfile.new { platform :windows }.validate!
      }.should.raise Pod::Informative
      exception.message.should.include "platform"
    end

    it "raises if no dependencies were specified" do
      exception = lambda {
        Pod::Podfile.new {}.validate!
      }.should.raise Pod::Informative
      exception.message.should.include "dependencies"
    end
  end
end
