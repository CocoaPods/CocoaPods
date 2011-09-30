require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Xcode::Project" do
  extend SpecHelper::TemporaryDirectory

  before do
    @project = Pod::Xcode::Project.ios_static_library
  end

  it "returns an instance initialized from the iOS static library template" do
    template_dir = Pod::Xcode::Project::TEMPLATES_DIR + 'cocoa-touch-static-library'
    template_file = (template_dir + 'Pods.xcodeproj/project.pbxproj').to_s
    @project.to_hash.should == NSDictionary.dictionaryWithContentsOfFile(template_file)
  end

  it "adds a group to the `Pods' group" do
    @project.add_group('JSONKit')
    @project.find_object({
      'isa' => 'PBXGroup',
      'name' => 'JSONKit',
      'sourceTree' => '<group>',
      'children' => []
    }).should.not == nil
  end

  it "adds an `m' or `c' file as a build file, adds it to the specified group, and adds it to the `sources build' phase list" do
    file_ref_uuids, build_file_uuids = [], []
    group_uuid = @project.add_group('SomeGroup')
    group = @project.to_hash['objects'][group_uuid]

    %w{ m mm c cpp }.each do |ext|
      path = Pathname.new("path/to/file.#{ext}")
      file_ref_uuid = @project.add_source_file(path, 'SomeGroup')
      @project.to_hash['objects'][file_ref_uuid].should == {
        'name'       => path.basename.to_s,
        'isa'        => 'PBXFileReference',
        'sourceTree' => 'SOURCE_ROOT',
        'path'       => path.to_s
      }
      file_ref_uuids << file_ref_uuid

      build_file_uuid, _ = @project.find_object({
        'isa' => 'PBXBuildFile',
        'fileRef' => file_ref_uuid
      })
      build_file_uuids << build_file_uuid

      group['children'].should == file_ref_uuids

      _, object = @project.find_object('isa' => 'PBXSourcesBuildPhase')
      object['files'].should == build_file_uuids

      _, object = @project.find_object('isa' => 'PBXHeadersBuildPhase')
      object['files'].should.not.include build_file_uuid
    end
  end

  it "adds custom compiler flags to the PBXBuildFile object if specified" do
    build_file_uuids = []
    %w{ m mm c cpp }.each do |ext|
      path = Pathname.new("path/to/file.#{ext}")
      file_ref_uuid = @project.add_source_file(path, 'Pods', nil, '-fno-obj-arc')
      @project.find_object({
        'isa' => 'PBXBuildFile',
        'fileRef' => file_ref_uuid,
        'settings' => {'COMPILER_FLAGS' => '-fno-obj-arc' }
      }).should.not == nil
    end
  end

  it "creates a copy build header phase which will copy headers to a specified path" do
    phase_uuid = @project.add_copy_header_build_phase("SomePod", "Path/To/Source")
    @project.find_object({
      'isa' => 'PBXCopyFilesBuildPhase',
      'dstPath' => '$(PUBLIC_HEADERS_FOLDER_PATH)/Path/To/Source',
      'name' => 'Copy SomePod Public Headers'
    }).should.not == nil

    _, target = @project.objects_by_isa('PBXNativeTarget').first
    target['buildPhases'].should.include phase_uuid
  end

  it "adds a `h' file as a build file and adds it to the `headers build' phase list" do
    @project.add_group('SomeGroup')
    path = Pathname.new("path/to/file.h")
    file_ref_uuid = @project.add_source_file(path, 'SomeGroup')
    @project.to_hash['objects'][file_ref_uuid].should == {
      'name'       => path.basename.to_s,
      'isa'        => 'PBXFileReference',
      'sourceTree' => 'SOURCE_ROOT',
      'path'       => path.to_s
    }
    build_file_uuid, _ = @project.find_object({
      'isa' => 'PBXBuildFile',
      'fileRef' => file_ref_uuid
    })

    #_, object = @project.find_object('isa' => 'PBXHeadersBuildPhase')
    _, object = @project.find_object('isa' => 'PBXCopyFilesBuildPhase')
    object['files'].should == [build_file_uuid]

    _, object = @project.find_object('isa' => 'PBXSourcesBuildPhase')
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
    @project.add_group('SomeGroup')
    files = [Pathname.new('/some/file.h'), Pathname.new('/some/file.m')]
    files.each { |file| @project.add_source_file(file, 'SomeGroup') }
    @project.source_files['SomeGroup'].sort.should == files.sort
  end
end
