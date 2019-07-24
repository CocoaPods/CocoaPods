require File.expand_path('../../spec_helper', __FILE__)

require 'cocoapods/installer/project_cache/target_metadata'
require 'cocoapods/native_target_extension'
module Pod
  describe Project do
    before do
      @project = Project.new('Project.xcodeproj')
      @project.stubs(:reference_for_path).returns(Xcodeproj::Project::PBXFileReference.new(@project, 'uuid'))
      @metadata = Pod::Installer::ProjectCache::TargetMetadata.new('Bubba', 'aaa', 'Bubba.xcodeproj')
      @native_target = @project.new_target(:static_lbirary, 'MyParentTarget', :ios)
    end

    it 'adds a cached dependency correctly' do
      Project.add_cached_dependency(config.sandbox, @native_target, @metadata)
      @native_target.dependencies.count.should.be.equal 1
      @native_target.dependencies.first.name.should.equal 'Bubba'
    end
  end
end
