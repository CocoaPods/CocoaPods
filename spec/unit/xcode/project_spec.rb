require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Xcode::Project" do
  extend SpecHelper::TemporaryDirectory

  before do
    @project = Pod::Xcode::Project.static_library(:ios)
  end

  def find_objects(conditions)
    @project.objects_hash.select do |_, object|
      object.objectsForKeys(conditions.keys, notFoundMarker:Object.new) == conditions.values
    end
  end

  def find_object(conditions)
    find_objects(conditions).first
  end

  it "returns an instance initialized from the iOS static library template" do
    template_dir = Pod::Xcode::Project::TEMPLATES_DIR + 'cocoa-touch-static-library'
    template_file = (template_dir + 'Pods.xcodeproj/project.pbxproj').to_s
    @project.to_hash.should == NSDictionary.dictionaryWithContentsOfFile(template_file)
  end

  it "returns the objects hash" do
    @project.objects_hash.should == @project.to_hash['objects']
  end

  describe "PBXObject" do
    before do
      @object = Pod::Xcode::Project::PBXObject.new(@project.objects, nil, 'name' => 'AnObject')
    end

    it "merges the class name into the attributes" do
      @object.isa.should == 'PBXObject'
      @object.attributes['isa'].should == 'PBXObject'
    end

    it "takes a name" do
      @object.name.should == 'AnObject'
      @object.name = 'AnotherObject'
      @object.name.should == 'AnotherObject'
    end

    it "generates a uuid" do
      @object.uuid.should.be.instance_of String
      @object.uuid.size.should == 24
      @object.uuid.should == @object.uuid
    end
  end

  it "returns the objects as PBXObject instances" do
    @project.objects.each do |object|
      @project.objects_hash[object.uuid].should == object.attributes
    end
  end

  it "adds any type of new PBXObject to the objects hash" do
    object = @project.objects.add(Pod::Xcode::Project::PBXObject, 'name' => 'An Object')
    object.name.should == 'An Object'
    @project.objects_hash[object.uuid].should == object.attributes
  end

  it "adds a new PBXObject, of the configured type, to the objects hash" do
    group = @project.groups.new('name' => 'A new group')
    group.isa.should == 'PBXGroup'
    group.name.should == 'A new group'
    @project.objects_hash[group.uuid].should == group.attributes
  end

  it "adds a new PBXFileReference to the objects hash" do
    file = @project.files.new('path' => '/some/file.m')
    file.isa.should == 'PBXFileReference'
    file.name.should == 'file.m'
    file.path.should == '/some/file.m'
    file.sourceTree.should == 'SOURCE_ROOT'
    @project.objects_hash[file.uuid].should == file.attributes
  end

  it "adds a new PBXBuildFile to the objects hash when a new PBXFileReference is created" do
    file = @project.files.new('name' => '/some/source/file.h')
    build_file = file.build_file
    build_file.file = file
    build_file.fileRef.should == file.uuid
    build_file.isa.should == 'PBXBuildFile'
    @project.objects_hash[build_file.uuid].should == build_file.attributes
  end

  it "adds a group to the `Pods' group" do
    group = @project.add_pod_group('JSONKit')
    @project.pods.children.should.include group.uuid
    find_object({
      'isa' => 'PBXGroup',
      'name' => 'JSONKit',
      'sourceTree' => '<group>',
      'children' => []
    }).should.not == nil
  end

  it "adds an `m' or `c' file as a build file, adds it to the specified group, and adds it to the `sources build' phase list" do
    file_ref_uuids, build_file_uuids = [], []
    group = @project.add_pod_group('SomeGroup')

    %w{ m mm c cpp }.each do |ext|
      path = Pathname.new("path/to/file.#{ext}")
      file = group.add_source_file(path)

      @project.objects_hash[file.uuid].should == {
        'name'       => path.basename.to_s,
        'isa'        => 'PBXFileReference',
        'sourceTree' => 'SOURCE_ROOT',
        'path'       => path.to_s
      }
      file_ref_uuids << file.uuid

      build_file_uuid, _ = find_object({
        'isa' => 'PBXBuildFile',
        'fileRef' => file.uuid
      })
      build_file_uuids << build_file_uuid

      group.children.should == file_ref_uuids

      _, object = find_object('isa' => 'PBXSourcesBuildPhase')
      object['files'].should == build_file_uuids

      _, object = find_object('isa' => 'PBXHeadersBuildPhase')
      object['files'].should.not.include build_file_uuid
    end
  end

  it "adds custom compiler flags to the PBXBuildFile object if specified" do
    build_file_uuids = []
    %w{ m mm c cpp }.each do |ext|
      path = Pathname.new("path/to/file.#{ext}")
      file = @project.pods.add_source_file(path, nil, '-fno-obj-arc')
      find_object({
        'isa' => 'PBXBuildFile',
        'fileRef' => file.uuid,
        'settings' => {'COMPILER_FLAGS' => '-fno-obj-arc' }
      }).should.not == nil
    end
  end

  it "creates a copy build header phase which will copy headers to a specified path" do
    phase = @project.add_copy_header_build_phase("SomePod", "Path/To/Source")
    find_object({
      'isa' => 'PBXCopyFilesBuildPhase',
      'dstPath' => '$(PUBLIC_HEADERS_FOLDER_PATH)/Path/To/Source',
      'name' => 'Copy SomePod Public Headers'
    }).should.not == nil
    target = @project.targets.first
    target.attributes['buildPhases'].should.include phase.uuid
  end

  it "adds a `h' file as a build file and adds it to the `headers build' phase list" do
    group = @project.groups.new('name' => 'SomeGroup')
    path = Pathname.new("path/to/file.h")
    file = group.add_source_file(path)
    @project.objects_hash[file.uuid].should == {
      'name'       => path.basename.to_s,
      'isa'        => 'PBXFileReference',
      'sourceTree' => 'SOURCE_ROOT',
      'path'       => path.to_s
    }
    build_file_uuid, _ = find_object({
      'isa' => 'PBXBuildFile',
      'fileRef' => file.uuid
    })

    #_, object = find_object('isa' => 'PBXHeadersBuildPhase')
    _, object = find_object('isa' => 'PBXCopyFilesBuildPhase')
    object['files'].should == [build_file_uuid]

    _, object = find_object('isa' => 'PBXSourcesBuildPhase')
    object['files'].should.not.include build_file_uuid
  end

  it "saves the template with the adjusted project" do
    @project.create_in(temporary_directory)
    (temporary_directory + 'Pods-Prefix.pch').should.exist
    (temporary_directory + 'Pods.xcconfig').should.exist
    project_file = (temporary_directory + 'Pods.xcodeproj/project.pbxproj')
    NSDictionary.dictionaryWithContentsOfFile(project_file.to_s).should == @project.to_hash
  end

  it "returns all source files" do
    group = @project.groups.new('name' => 'SomeGroup')
    files = [Pathname.new('/some/file.h'), Pathname.new('/some/file.m')]
    files.each { |file| group.add_source_file(file) }
    group.source_files.map(&:pathname).sort.should == files.sort
  end
end
