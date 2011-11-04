require File.expand_path('../../../spec_helper', __FILE__)

describe "Pod::Xcode::Project" do
  extend SpecHelper::TemporaryDirectory

  before do
    @template = Pod::ProjectTemplate.new(:ios)
    @project = Pod::Xcode::Project.new(@template.xcodeproj_path)
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
    template_file = (@template.xcodeproj_path + '/project.pbxproj').to_s
    @project.to_hash.should == NSDictionary.dictionaryWithContentsOfFile(template_file)
  end

  before do
    @target = @project.targets.new_static_library('Pods')
  end

  it "returns the objects hash" do
    @project.objects_hash.should == @project.to_hash['objects']
  end

  describe "PBXObject" do
    before do
      @object = Pod::Xcode::Project::PBXObject.new(@project, nil, 'name' => 'AnObject')
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

    it "adds the object to the objects hash" do
      @project.objects_hash[@object.uuid].should == @object.attributes
    end
  end

  describe "a PBXFileReference" do
    before do
      @file = @project.files.new('path' => 'some/file.m')
    end

    it "is automatically added to the main group" do
      @project.main_group.children.should.include @file
    end

    it "is removed from the original group when added to another group" do
      @project.pods.children << @file
      @project.pods.children.should.include @file
      @project.main_group.children.should.not.include @file
    end
  end

  describe "a new PBXBuildPhase" do
    before do
      @phase = @project.objects.add(Pod::Xcode::Project::PBXBuildPhase)
    end

    it "has an empty list of files" do
      @phase.files.to_a.should == []
    end

    it "always returns the same buildActionMask (no idea what it is)" do
      @phase.buildActionMask.should == "2147483647"
    end

    it "always returns zero for runOnlyForDeploymentPostprocessing (no idea what it is)" do
      @phase.runOnlyForDeploymentPostprocessing.should == "0"
    end
  end

  describe "a new PBXCopyFilesBuildPhase" do
    before do
      @phase = @project.objects.add(Pod::Xcode::Project::PBXCopyFilesBuildPhase, 'dstPath' => 'some/path')
    end

    it "is a PBXBuildPhase" do
      @phase.should.be.kind_of Pod::Xcode::Project::PBXBuildPhase
    end

    it "returns the dstPath" do
      @phase.dstPath.should == 'some/path'
    end

    it "returns the dstSubfolderSpec (no idea what it is yet, but it's not always the same)" do
      @phase.dstSubfolderSpec.should == "16"
    end
  end

  describe "a new PBXSourcesBuildPhase" do
    before do
      @phase = @project.objects.add(Pod::Xcode::Project::PBXSourcesBuildPhase)
    end

    it "is a PBXBuildPhase" do
      @phase.should.be.kind_of Pod::Xcode::Project::PBXBuildPhase
    end
  end

  describe "a new PBXFrameworksBuildPhase" do
    before do
      @phase = @project.objects.add(Pod::Xcode::Project::PBXFrameworksBuildPhase)
    end

    it "is a PBXBuildPhase" do
      @phase.should.be.kind_of Pod::Xcode::Project::PBXBuildPhase
    end
  end

  describe "a new XCBuildConfiguration" do
    before do
      @configuration = @project.objects.add(Pod::Xcode::Project::XCBuildConfiguration)
    end

    it "returns the xcconfig that this configuration is based on (baseConfigurationReference)" do
      xcconfig = @project.objects.new
      @configuration.baseConfiguration = xcconfig
      @configuration.baseConfigurationReference.should == xcconfig.uuid
    end
  end

  describe "a new XCConfigurationList" do
    before do
      @list = @project.objects.add(Pod::Xcode::Project::XCConfigurationList)
    end

    it "returns the configurations" do
      configuration = @project.objects.add(Pod::Xcode::Project::XCBuildConfiguration)
      @list.buildConfigurations.to_a.should == []
      @list.buildConfigurations = [configuration]
      @list.buildConfigurationReferences.should == [configuration.uuid]
    end
  end

  describe "a new PBXNativeTarget" do
    it "returns the product name, which is the name of the binary (minus prefix/suffix)" do
      @target.name.should == "Pods"
      @target.productName.should == "Pods"
    end

    it "returns the product" do
      product = @target.product
      product.uuid.should == @target.productReference
      product.should.be.instance_of Pod::Xcode::Project::PBXFileReference
      product.path.should == "libPods.a"
      product.name.should == "libPods.a"
      product.sourceTree.should == "BUILT_PRODUCTS_DIR"
      product.explicitFileType.should == "archive.ar"
      product.includeInIndex.should == "0"
    end

    it "returns that product type is a static library" do
      @target.productType.should == "com.apple.product-type.library.static"
    end

    it "returns the buildConfigurationList" do
      list = @target.buildConfigurationList
      list.should.be.instance_of Pod::Xcode::Project::XCConfigurationList
      list.buildConfigurations.each do |configuration|
        configuration.buildSettings.should == {
          'DSTROOT'                      => '/tmp/Pods.dst',
          'GCC_PRECOMPILE_PREFIX_HEADER' => 'YES',
          # TODO do we need a default?
          #'GCC_PREFIX_HEADER'            => 'Pods-Prefix.pch',
          'OTHER_LDFLAGS'                => '',
          'GCC_VERSION'                  => 'com.apple.compilers.llvm.clang.1_0',
          'PRODUCT_NAME'                 => '$(TARGET_NAME)',
          'SKIP_INSTALL'                 => 'YES',
        }
      end
    end

    it "returns an empty list of dependencies and buildRules (not sure yet which classes those are yet)" do
      @target.dependencies.to_a.should == []
      @target.buildRules.to_a.should == []
    end

    describe "concerning its build phases" do
      extend SpecHelper::TemporaryDirectory

      it "returns an empty sources build phase" do
        phase = @target.buildPhases.select_by_class(Pod::Xcode::Project::PBXSourcesBuildPhase).first
        phase.files.to_a.should == []
      end

      it "returns a libraries/frameworks build phase, which by default only contains `Foundation.framework'" do
        phase = @target.buildPhases.select_by_class(Pod::Xcode::Project::PBXFrameworksBuildPhase).first
        phase.files.map { |buildFile| buildFile.file.name }.should == ['Foundation.framework']
      end

      it "returns an empty 'copy headers' phase" do
        phase = @target.buildPhases.select_by_class(Pod::Xcode::Project::PBXCopyFilesBuildPhase).first
        phase.dstPath.should == "$(PUBLIC_HEADERS_FOLDER_PATH)"
        phase.files.to_a.should == []
      end
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
    build_file = file.buildFiles.new
    build_file.file = file
    build_file.fileRef.should == file.uuid
    build_file.isa.should == 'PBXBuildFile'
    @project.objects_hash[build_file.uuid].should == build_file.attributes
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

  it "adds an `m' or `c' file to the `sources build' phase list" do
    %w{ m mm c cpp }.each do |ext|
      path = Pathname.new("path/to/file.#{ext}")
      file = @target.add_source_file(path)
      # ensure that it was added to all objects
      file = @project.objects[file.uuid]

      phase = @target.buildPhases.find { |phase| phase.is_a?(Pod::Xcode::Project::PBXSourcesBuildPhase) }
      phase.files.map { |buildFile| buildFile.file }.should.include file

      phase = @target.buildPhases.find { |phase| phase.is_a?(Pod::Xcode::Project::PBXCopyFilesBuildPhase) }
      phase.files.map { |buildFile| buildFile.file }.should.not.include file
    end
  end

  it "adds custom compiler flags to the PBXBuildFile object if specified" do
    build_file_uuids = []
    %w{ m mm c cpp }.each do |ext|
      path = Pathname.new("path/to/file.#{ext}")
      file = @project.targets.first.add_source_file(path, nil, '-fno-obj-arc')
      find_object({
        'isa' => 'PBXBuildFile',
        'fileRef' => file.uuid,
        'settings' => {'COMPILER_FLAGS' => '-fno-obj-arc' }
      }).should.not == nil
    end
  end

  it "creates a copy build header phase which will copy headers to a specified path" do
    phase = @project.targets.first.copy_files_build_phases.new_pod_dir("SomePod", "Path/To/Source")
    find_object({
      'isa' => 'PBXCopyFilesBuildPhase',
      'dstPath' => '$(PUBLIC_HEADERS_FOLDER_PATH)/Path/To/Source',
      'name' => 'Copy SomePod Public Headers'
    }).should.not == nil
    @project.targets.first.buildPhases.should.include phase
  end

  # TODO add test for the optional copy_header_phase
  #it "adds a `h' file as a build file and adds it to the `headers build' phase list" do
  it "adds a `h' file as a build file and adds it to the `copy header files' build phase list" do
    path = Pathname.new("path/to/file.h")
    file = @target.add_source_file(path)
    # ensure that it was added to all objects
    file = @project.objects[file.uuid]

    phase = @target.buildPhases.find { |phase| phase.is_a?(Pod::Xcode::Project::PBXSourcesBuildPhase) }
    phase.files.map { |buildFile| buildFile.file }.should.not.include file

    phase = @target.buildPhases.find { |phase| phase.is_a?(Pod::Xcode::Project::PBXCopyFilesBuildPhase) }
    phase.files.map { |buildFile| buildFile.file }.should.include file
  end

  it "saves the template with the adjusted project" do
    @template.copy_to(temporary_directory)
    @project.save_as(temporary_directory + 'Pods.xcodeproj')
    project_file = (temporary_directory + 'Pods.xcodeproj/project.pbxproj')
    NSDictionary.dictionaryWithContentsOfFile(project_file.to_s).should == @project.to_hash
  end

  it "returns all source files" do
    group = @project.groups.new('name' => 'SomeGroup')
    files = [Pathname.new('/some/file.h'), Pathname.new('/some/file.m')]
    files.each { |file| group << @target.add_source_file(file) }
    group.source_files.map(&:pathname).sort.should == files.sort
  end
end
