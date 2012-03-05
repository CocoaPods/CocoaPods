require File.expand_path('../../spec_helper', __FILE__)

TMP_POD_ROOT = ROOT + "tmp" + "podroot"

describe Pod::Installer::TargetInstaller do

  before do 
    @target_definition = stub('target', :lib_name => "FooLib")

    platform = Pod::Platform.new(:ios)
    @podfile = stub('podfile', :platform => platform, :generate_bridge_support? => false)

    @project = Pod::Project.for_platform(platform)
    @project.main_group.groups.new('name' => 'Targets Support Files')

    @installer = Pod::Installer::TargetInstaller.new(@podfile, @project, @target_definition)
    
    @sandbox = Pod::Sandbox.new(TMP_POD_ROOT)
    @specification = fixture_spec('banana-lib/BananaLib.podspec')
    @pods = [Pod::LocalPod.new(@specification, @sandbox)]
  end
  
  def do_install!
    @installer.install!(@pods, @sandbox)
  end
  
  it 'adds a new static library target to the project' do
    do_install!
    @project.targets.count.should == 1
    @project.targets.first.name.should == "FooLib"
  end
  
  it 'adds each pod to the static library target' do
    @pods[0].expects(:add_to_target).with(instance_of(Xcodeproj::Project::Object::PBXNativeTarget))
    do_install!
  end
  
  it 'tells each pod to link its headers' do
    @pods[0].expects(:link_headers)
    do_install!
  end
  
  it 'adds the sandbox header search paths to the xcconfig, with quotes' do
    do_install!
    @installer.xcconfig.to_hash['HEADER_SEARCH_PATHS'].should.include("\"#{@sandbox.header_search_paths.join(" ")}\"")
  end
  
  it 'adds the -fobjc-arc to OTHER_LDFLAGS if any pods require arc (to support non-ARC projects on iOS 4.0)' do
    @specification.stubs(:requires_arc).returns(true)
    do_install!
    @installer.xcconfig.to_hash['OTHER_LDFLAGS'].split(" ").should.include("-fobjc-arc")
  end
end
