require File.expand_path('../../spec_helper', __FILE__)

describe 'Xcodeproj::Project' do
  before do
    @project = Xcodeproj::Project.new
  end

  def find_object(conditions)
    @project.objects_hash.select do |_, object|
      object.objectsForKeys(conditions.keys, notFoundMarker:Object.new) == conditions.values
    end.first
  end

  it "adds a group to the `Pods' group" do
    group = @project.add_pod_group('JSONKit')
    @project.pods.childReferences.should.include group.uuid
    find_object({
      'isa' => 'PBXGroup',
      'name' => 'JSONKit',
      'sourceTree' => '<group>',
      'children' => []
    }).should.not == nil
  end

  it "creates a copy build header phase which will copy headers to a specified path" do
    @project.targets.new
    phase = @project.targets.first.copy_files_build_phases.new_pod_dir("SomePod", "Path/To/Source")
    find_object({
      'isa' => 'PBXCopyFilesBuildPhase',
      'dstPath' => 'Pods/Path/To/Source',
      'name' => 'Copy SomePod Public Headers'
    }).should.not == nil
    @project.targets.first.buildPhases.should.include phase
  end
end
