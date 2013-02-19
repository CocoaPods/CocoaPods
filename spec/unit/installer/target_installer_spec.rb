require File.expand_path('../../../spec_helper', __FILE__)

TMP_POD_ROOT = ROOT + "tmp" + "podroot" unless defined? TMP_POD_ROOT

describe Pod::Installer::TargetInstaller do
  extend SpecHelper::TemporaryDirectory

  before do
    @podfile = Pod::Podfile.new do
      platform :ios
      xcodeproj 'dummy'
    end
    @target_definition = @podfile.target_definitions[:default]

    @project = Pod::Project.new
    @project.new_group('Targets Support Files')

    @installer = Pod::Installer::TargetInstaller.new(@podfile, @project, @target_definition)

    @sandbox = Pod::Sandbox.new(TMP_POD_ROOT)
    FileUtils.cp_r(fixture('banana-lib'), TMP_POD_ROOT + 'BananaLib')
    @specification = fixture_spec('banana-lib/BananaLib.podspec')
    @pods = [Pod::LocalPod.new(@specification, @sandbox, Pod::Platform.ios)]
  end

  def do_install!
    @pods.each { |pod| pod.add_file_references_to_project(@project) }
    @installer.install!(@pods, @sandbox)
  end

  it 'adds a new static library target to the project' do
    do_install!
    @project.targets.count.should == 1
    @project.targets.first.name.should == @target_definition.label
  end

  it "adds the user's build configurations to the target" do
    @project.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'AppStore' => :release, 'Test' => :debug }
    do_install!
    @project.targets.first.build_configurations.map(&:name).sort.should == %w{ AppStore Debug Release Test }
  end

  it 'adds each pod to the static library target' do
    @pods[0].expects(:add_build_files_to_target)
    do_install!
  end

  # TODO: move to project
  # it 'tells each pod to link its headers' do
  #   @pods[0].expects(:link_headers)
  #   do_install!
  # end

  it 'adds the sandbox header search paths to the xcconfig, with quotes' do
    do_install!
    @installer.xcconfig.to_hash['PODS_BUILD_HEADERS_SEARCH_PATHS'].should.include("\"#{@sandbox.build_headers.search_paths.join('" "')}\"")
  end

  it 'does not add the -fobjc-arc to OTHER_LDFLAGS by default as Xcode 4.3.2 does not support it' do
    do_install!
    @installer.xcconfig.to_hash['OTHER_LDFLAGS'].split(" ").should.not.include("-fobjc-arc")
  end

  it 'adds the -fobjc-arc to OTHER_LDFLAGS if any pods require arc (to support non-ARC projects on iOS 4.0)' do
    @podfile.stubs(:set_arc_compatibility_flag? => true)
    @specification.stubs(:requires_arc).returns(true)
    do_install!
    @installer.xcconfig.to_hash['OTHER_LDFLAGS'].split(" ").should.include("-fobjc-arc")
  end

  it "adds the -DNS_BLOCK_ASSERTIONS=1 to OTHER_CFLAGS if set_dns_block_assertions_flag is set" do
    @podfile.stubs(:set_dns_block_assertions_flag? => true)
    do_install!
    @installer.xcconfig.to_hash['OTHER_CFLAGS'].split(" ").should.include("-DNS_BLOCK_ASSERTIONS=1")
    @installer.xcconfig.to_hash['OTHER_CPLUSPLUSFLAGS'].split(" ").should.include("-DNS_BLOCK_ASSERTIONS=1")
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

  it "creates a prefix header, including the contents of the specification's prefix header file" do
    do_install!
    prefix_header = @sandbox.root + 'Pods.pch'
    @installer.save_prefix_header_as(prefix_header, @pods)
    prefix_header.read.should == <<-EOS
#ifdef __OBJC__
#import <UIKit/UIKit.h>
#endif

#import <BananaTree/BananaTree.h>
EOS
  end

  it "creates a prefix header, including the contents of the specification's prefix header" do
    do_install!
    prefix_header = @sandbox.root + 'Pods.pch'
    @specification.prefix_header_contents = '#import "BlocksKit.h"'
    @installer.save_prefix_header_as(prefix_header, @pods)
    prefix_header.read.should == <<-EOS
#ifdef __OBJC__
#import <UIKit/UIKit.h>
#endif

#import "BlocksKit.h"
EOS
  end
end
