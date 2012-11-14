require File.expand_path('../../../spec_helper', __FILE__)

describe TargetInstaller = Pod::Installer::TargetInstaller do

  describe "In general" do
    before do
      @podfile = Pod::Podfile.new do
        platform :ios
      end
      @target_definition = @podfile.target_definitions[:default]
      @project = Pod::Project.new(config.sandbox)
      @specification = fixture_spec('banana-lib/BananaLib.podspec')
      @pods = [Pod::LocalPod.new(@specification, config.sandbox, Pod::Platform.ios)]
      @installer = TargetInstaller.new(@project, @target_definition, @pods,)
    end

    it "returns the project" do
      @installer.project.should == @project
    end

    it "returns the target_definition" do
      @installer.target_definition.should == @target_definition
    end

    it "returns the pods of the target definition" do
      @installer.pods.should == @pods
    end
  end

  describe "Installation" do
    extend SpecHelper::TemporaryDirectory

    before do
      @podfile = Pod::Podfile.new do
        platform :ios
        xcodeproj 'dummy'
      end
      @target_definition = @podfile.target_definitions[:default]
      @project = Pod::Project.new(config.sandbox)
      specification = fixture_spec('banana-lib/BananaLib.podspec')
      @pod          = Pod::LocalPod.new(specification, config.sandbox, @target_definition.platform)
      @installer = TargetInstaller.new(@project, @target_definition, [@pod])

      specification.prefix_header_contents = '#import "BlocksKit.h"'
      @pod.stubs(:root).returns(Pathname.new(fixture('banana-lib')))
    end

    def do_install!
      # Prevent raise for missing dummy project.
      Pathname.any_instance.stubs(:exist?).returns(true)
      @pod.add_file_references_to_project(@project)
      @installer.install
    end

    it 'adds a new static library target to the project' do
      do_install!
      @project.targets.count.should == 1
      @project.targets.first.name.should == @target_definition.label
    end

    it 'adds the source files of each pod to the target of the Pod library' do
      do_install!
      names = @installer.target.source_build_phase.files.map { |bf| bf.file_ref.name }
      names.should == [ "Banana.m" ]
    end

    it "adds file references for the support files of the target" do
      do_install!
      group = @project.support_files_group['Pods']
      group.children.map(&:display_name).sort.should == [
        "Pods-prefix.pch", "Pods-resources.sh", "Pods.xcconfig"
      ]
    end

    #--------------------------------------#

    it "adds the user's build configurations to the target" do
      @project.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }
      do_install!
      @project.targets.first.build_configurations.map(&:name).sort.should == %w{ AppStore Debug Release Test }
    end

    it 'adds the sandbox header search paths to the xcconfig, with quotes' do
      do_install!
      @installer.library.xcconfig.to_hash['PODS_BUILD_HEADERS_SEARCH_PATHS'].should.include("\"#{config.sandbox.build_headers.search_paths.join('" "')}\"")
    end

    it 'does not add the -fobjc-arc to OTHER_LDFLAGS by default as Xcode 4.3.2 does not support it' do
      do_install!
      @installer.library.xcconfig.to_hash['OTHER_LDFLAGS'].split(" ").should.not.include("-fobjc-arc")
    end

    it 'adds the -fobjc-arc to OTHER_LDFLAGS if any pods require arc (to support non-ARC projects on iOS 4.0)' do
      Pod::Podfile.any_instance.stubs(:set_arc_compatibility_flag? => true)
      @pod.top_specification.stubs(:requires_arc).returns(true)
      do_install!
      @installer.library.xcconfig.to_hash['OTHER_LDFLAGS'].split(" ").should.include("-fobjc-arc")
    end

    it "does not enable the GCC_WARN_INHIBIT_ALL_WARNINGS flag by default" do
      do_install!
      @installer.target.build_configurations.each do |config|
        config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'].should == 'NO'
      end
    end

    it "enables the GCC_WARN_INHIBIT_ALL_WARNINGS flag" do
      @podfile.inhibit_all_warnings!
      do_install!
      @installer.target.build_configurations.each do |config|
        config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'].should == 'YES'
      end
    end

    it "creates and xcconfig file" do
      do_install!
      xcconfig = config.sandbox.root + 'Pods.xcconfig'
      xcconfig.read.should == <<-EOS.strip_heredoc.gsub(/\n$/, '')
        ALWAYS_SEARCH_USER_PATHS = YES
        OTHER_LDFLAGS = -ObjC -framework SystemConfiguration
        HEADER_SEARCH_PATHS = ${PODS_HEADERS_SEARCH_PATHS}
        PODS_ROOT = ${SRCROOT}/Pods
        PODS_BUILD_HEADERS_SEARCH_PATHS = "${PODS_ROOT}/BuildHeaders"
        PODS_PUBLIC_HEADERS_SEARCH_PATHS = "${PODS_ROOT}/Headers"
        PODS_HEADERS_SEARCH_PATHS = ${PODS_PUBLIC_HEADERS_SEARCH_PATHS}
      EOS
    end

    it "creates a prefix header, including the contents of the specification's prefix header" do
      @pod.top_specification.prefix_header_contents = '#import "BlocksKit.h"'
      do_install!
      prefix_header = config.sandbox.root + 'Pods-prefix.pch'
      prefix_header.read.should == <<-EOS.strip_heredoc
      #ifdef __OBJC__
      #import <UIKit/UIKit.h>
      #endif

      #import "BlocksKit.h"
      EOS
    end

    it "creates a bridge support file" do
      Pod::Podfile.any_instance.stubs(:generate_bridge_support? => true)
      Pod::Generator::BridgeSupport.any_instance.expects(:save_as).once
      do_install!
    end

    it "creates a create copy resources script" do
      do_install!
      script = config.sandbox.root + 'Pods-resources.sh'
      script.read.should.include?('logo-sidebar.png')
    end
  end
end
