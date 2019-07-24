require File.expand_path('../../spec_helper', __FILE__)
require 'cocoapods/installer/project_cache/target_metadata.rb'

module Pod
  # Expose to unit test file
  class Project
    public :group_for_path_in_group
  end

  describe Project do
    before do
      @project = Project.new(config.sandbox.project_path)
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      it 'creates the support files group on initialization' do
        @project.support_files_group.name.should == 'Targets Support Files'
      end

      it 'creates the Pods group on initialization' do
        @project.pods.name.should == 'Pods'
      end

      it 'creates the development Pods group on initialization' do
        @project.development_pods.name.should == 'Development Pods'
      end

      def settings_for_root_configs(key)
        @project.root_object.build_configuration_list.build_configurations.map do |config|
          config.build_settings[key]
        end
      end

      it 'assigns a SYMROOT to each root build configuration' do
        @project.symroot = 'some/build/path'
        settings_for_root_configs('SYMROOT').uniq.should == ['some/build/path']
      end

      it 'sets a default SYMROOT for legacy Xcode build setups' do
        settings_for_root_configs('SYMROOT').uniq.should == [Project::LEGACY_BUILD_ROOT]
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Pod Groups' do
      describe '#add_pod_group' do
        before do
          @path = config.sandbox.pod_dir('BananaLib')
        end

        it 'adds the group for a Pod' do
          group = @project.add_pod_group('BananaLib', @path)
          group.parent.should == @project.pods
          group.name.should == 'BananaLib'
        end

        it 'adds the group for a development Pod' do
          config.sandbox.pod_dir('BananaLib')
          group = @project.add_pod_group('BananaLib', @path, true)
          group.parent.should == @project.development_pods
          group.name.should == 'BananaLib'
        end

        it 'configures the path of a new Pod group' do
          config.sandbox.pod_dir('BananaLib')
          group = @project.add_pod_group('BananaLib', @path)
          group.source_tree.should == '<group>'
          group.path.should == 'BananaLib'
          Pathname.new(group.path).should.be.relative
        end

        it 'configures the path of a new Pod group as absolute if requested' do
          config.sandbox.pod_dir('BananaLib')
          group = @project.add_pod_group('BananaLib', @path, false, true)
          group.source_tree.should == '<absolute>'
          group.path.should == @path.to_s
          Pathname.new(group.path).should.be.absolute
        end
      end

      describe '#add_pod_subproject' do
        it 'adds subprojects to the Development and Pods groups for Pods.xcodeproj' do
          subproject1_path = config.sandbox.pod_target_project_path('SubprojA')
          subproject2_path = config.sandbox.pod_target_project_path('SubprojB')
          subproject1_path.mkpath
          subproject2_path.mkpath
          subproject1 = Project.new(subproject1_path)
          subproject2 = Project.new(subproject2_path)
          ref_a = @project.add_pod_subproject(subproject1)
          ref_b = @project.add_pod_subproject(subproject2, true)

          @project.main_group['Pods'].children.should.equal([ref_a])
          @project.main_group['Development Pods'].children.should.equal([ref_b])
          @project.main_group['Dependencies'].children.count.should.equal(0)
        end

        it 'adds subprojects to the Dependencies group if #pod_target_subproject is true' do
          @project = Project.new(config.sandbox.project_path, false, Xcodeproj::Constants::DEFAULT_OBJECT_VERSION, :pod_target_subproject => true)
          subproject1_path = config.sandbox.pod_target_project_path('SubprojA')
          subproject2_path = config.sandbox.pod_target_project_path('SubprojB')
          subproject1_path.mkpath
          subproject2_path.mkpath
          subproject1 = Project.new(subproject1_path)
          subproject2 = Project.new(subproject2_path)
          ref_a = @project.add_pod_subproject(subproject1)
          ref_b = @project.add_pod_subproject(subproject2, true)

          @project.main_group['Dependencies'].children.should.equal([ref_a, ref_b])
          @project.main_group['Development Pods'].children.count.should.equal(0)
          @project.main_group['Pods'].children.count.should.equal(0)
        end
      end

      describe '#add_cached_pod_subproject' do
        it 'adds cached subproject references' do
          subproject_path = config.sandbox.pod_target_project_path('SubprojA')
          subproject_path.mkpath
          metadata = Installer::ProjectCache::TargetMetadata.new('LabelA', '0000', subproject_path)
          ref = @project.add_cached_pod_subproject(config.sandbox, metadata)
          @project.main_group['Pods'].children.should.equal([ref])
        end
      end

      #----------------------------------------#

      describe '#pod_groups' do
        before do
          @project.add_pod_group('BananaLib', config.sandbox.pod_dir('BananaLib'))
          @project.add_pod_group('OrangeLib', config.sandbox.pod_dir('OrangeLib'), true)
        end

        it 'returns the pod groups' do
          @project.pod_groups.map(&:name).sort.should == %w(BananaLib OrangeLib)
        end

        it "doesn't alters the original groups" do
          @project.pods.children.map(&:name).sort.should == ['BananaLib']
          @project.development_pods.children.map(&:name).sort.should == ['OrangeLib']
        end
      end

      #----------------------------------------#

      it 'returns the group of a Pod with a given name' do
        @project.add_pod_group('BananaLib', config.sandbox.pod_dir('BananaLib'))
        @project.pod_group('BananaLib').name.should == 'BananaLib'
      end

      #----------------------------------------#

      describe '#group_for_spec' do
        before do
          @project.add_pod_group('BananaLib', config.sandbox.pod_dir('BananaLib'))
        end

        it 'returns the group for the spec with the given name' do
          group = @project.group_for_spec('BananaLib/Tree')
          group.hierarchy_path.should == '/Pods/BananaLib/Tree'
        end

        it "doesn't duplicate the groups" do
          group_1 = @project.group_for_spec('BananaLib/Tree')
          group_2 = @project.group_for_spec('BananaLib/Tree')
          group_1.uuid.should == group_2.uuid
        end

        it 'returns the subgroup with the given key' do
          group = @project.group_for_spec('BananaLib/Tree', :resources)
          group.hierarchy_path.should == '/Pods/BananaLib/Tree/Resources'
        end

        it "doesn't duplicates subgroups" do
          group_1 = @project.group_for_spec('BananaLib/Tree', :resources)
          group_2 = @project.group_for_spec('BananaLib/Tree', :resources)
          group_1.uuid.should == group_2.uuid
        end

        it 'raises if the subgroup key is unrecognized' do
          should.raise ArgumentError do
            @project.group_for_spec('BananaLib/Tree', :bananaland)
          end.message.should.match /Unrecognized.*key/
        end
      end

      #----------------------------------------#

      describe '#pod_support_files_group' do
        before do
          @project.add_pod_group('BananaLib', @path, false, true)
        end

        it 'creates a support file group relative to the project' do
          group = @project.pod_support_files_group('BananaLib', 'path')
          group.path.should == 'path'
        end

        it "doesn't duplicate the groups" do
          group_1 = @project.pod_support_files_group('BananaLib', 'path')
          group_2 = @project.pod_support_files_group('BananaLib', 'path')
          group_1.uuid.should == group_2.uuid
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'File references' do
      describe '#reference_for_path' do
        before do
          @project.add_pod_group('BananaLib', config.sandbox.pod_dir('BananaLib'), false)
          @file = config.sandbox.pod_dir('BananaLib') + 'file.m'
          @pod_dir = config.sandbox.pod_dir('BananaLib')
          @nested_file = config.sandbox.pod_dir('BananaLib') + 'Dir/SubDir/nested_file.m'
          @localized_file = config.sandbox.pod_dir('BananaLib') + 'Dir/SubDir/de.lproj/Foo.strings'
          @group = @project.group_for_spec('BananaLib')
        end

        it 'adds a file references to the given file' do
          Pathname.any_instance.stubs(:realpath).returns(@file)
          ref = @project.add_file_reference(@file, @group)
          ref.hierarchy_path.should == '/Pods/BananaLib/file.m'
        end

        it 'adds subgroups for a file reference if requested' do
          Pathname.any_instance.stubs(:realpath).returns(@nested_file)
          ref = @project.add_file_reference(@nested_file, @group, true)
          ref.hierarchy_path.should == '/Pods/BananaLib/Dir/SubDir/nested_file.m'
        end

        it 'does not add subgroups for a file reference if not requested' do
          Pathname.any_instance.stubs(:realpath).returns(@nested_file)
          ref = @project.add_file_reference(@nested_file, @group)
          ref.hierarchy_path.should == '/Pods/BananaLib/nested_file.m'
        end

        it 'does not add subgroups for a file reference if requested not to' do
          Pathname.any_instance.stubs(:realpath).returns(@nested_file)
          ref = @project.add_file_reference(@nested_file, @group, false)
          ref.hierarchy_path.should == '/Pods/BananaLib/nested_file.m'
        end

        it 'adds subgroups relative to shared base if requested' do
          base_path = @pod_dir + 'Dir'
          Pathname.any_instance.stubs(:realdirpath).returns(@pod_dir + 'Dir')
          Pathname.any_instance.stubs(:realpath).returns(@nested_file)
          ref = @project.add_file_reference(@nested_file, @group, true, base_path)
          ref.hierarchy_path.should == '/Pods/BananaLib/SubDir/nested_file.m'
          ref.parent.path.should == 'Dir/SubDir'
        end

        it "it doesn't duplicate file references for a single path" do
          Pathname.any_instance.stubs(:realpath).returns(@file)
          ref_1 = @project.add_file_reference(@file, @group)
          ref_2 = @project.add_file_reference(@file, @group)
          ref_1.uuid.should == ref_2.uuid
          @group.children.count.should == 1
        end

        it 'creates variant group for localized file' do
          Pathname.any_instance.stubs(:realpath).returns(@localized_file)
          ref = @project.add_file_reference(@localized_file, @group)
          ref.hierarchy_path.should == '/Pods/BananaLib/Foo.strings/Foo.strings'
          ref.parent.class.should == Xcodeproj::Project::Object::PBXVariantGroup
        end

        it 'creates variant group for localized file in subgroup' do
          Pathname.any_instance.stubs(:realpath).returns(@localized_file)
          ref = @project.add_file_reference(@localized_file, @group, true)
          ref.hierarchy_path.should == '/Pods/BananaLib/Dir/SubDir/Foo.strings/Foo.strings'
          ref.parent.class.should == Xcodeproj::Project::Object::PBXVariantGroup
        end

        it 'raises if the given path is not absolute' do
          should.raise ArgumentError do
            @project.add_file_reference('relative/path/to/file.m', @group)
          end.message.should.match /Paths must be absolute/
        end

        it 'uses realpath for resolving symlinks' do
          file = Pathname.new(Dir.tmpdir) + 'file.m'
          FileUtils.rm_f(file)
          File.open(file, 'w') { |f| f.write('') }
          sym_file = Pathname.new(Dir.tmpdir) + 'symlinked_file.m'
          FileUtils.rm_f(sym_file)
          File.symlink(file, sym_file)

          ref = @project.add_file_reference(sym_file, @group)
          ref.hierarchy_path.should == '/Pods/BananaLib/file.m'
        end

        it 'sets syntax to ruby when requested' do
          Pathname.any_instance.stubs(:realpath).returns(@file)
          ref = @project.add_file_reference(@file, @group)
          @project.mark_ruby_file_ref(ref)
          ref.xc_language_specification_identifier.should == 'xcode.lang.ruby'
          ref.explicit_file_type.should == 'text.script.ruby'
          ref.last_known_file_type.should == 'text'
          ref.tab_width.should == '2'
          ref.indent_width.should == '2'
        end
      end

      #----------------------------------------#

      describe '#group_for_path_in_group' do
        before do
          @project.add_pod_group('BananaLib', config.sandbox.pod_dir('BananaLib'), false)
          poddir = config.sandbox.pod_dir('BananaLib')
          subdir = poddir + 'Dir/SubDir/'
          @file = poddir + 'file.m'
          @nested_file = subdir + 'nested_file.h'
          @nested_file2 = subdir + 'nested_file.m'
          @localized_base_foo = subdir + 'Base.lproj/Foo.storyboard'
          @localized_de_foo = subdir + 'de.lproj/Foo.strings'
          @localized_de_foo_jpg = subdir + 'de.lproj/Foo.jpg'
          @localized_de_bar = subdir + 'de.lproj/Bar.strings'
          @localized_different_foo = poddir + 'Base.lproj/Foo.jpg'
          @group = @project.group_for_spec('BananaLib')
        end

        it 'returns parent group when file is in main group directory' do
          group = @project.group_for_path_in_group(@file, @group, true)
          group.uuid.should == @group.uuid
        end

        it 'returns parent group when not localized or reflecting structure' do
          group = @project.group_for_path_in_group(@nested_file, @group, false)
          group.uuid.should == @group.uuid
        end

        it 'adds subgroups if reflecting file system structure' do
          group = @project.group_for_path_in_group(@nested_file, @group, true)
          group.hierarchy_path.should == '/Pods/BananaLib/Dir/SubDir'
        end

        it "doesn't duplicate groups for a single directory path" do
          group_1 = @project.group_for_path_in_group(@nested_file, @group, true)
          group_2 = @project.group_for_path_in_group(@nested_file2, @group, true)
          group_1.uuid.should == group_2.uuid
        end

        it 'creates variant group for localized file' do
          group = @project.group_for_path_in_group(@localized_base_foo, @group, false)
          group.hierarchy_path.should == '/Pods/BananaLib/Foo.storyboard'
          group.class.should == Xcodeproj::Project::Object::PBXVariantGroup
        end

        it 'creates variant group for localized file when adding subgroups' do
          group = @project.group_for_path_in_group(@localized_base_foo, @group, true)
          group.hierarchy_path.should == '/Pods/BananaLib/Dir/SubDir/Foo.storyboard'
          group.class.should == Xcodeproj::Project::Object::PBXVariantGroup
        end

        it 'sets variant group path to the folder that contains .lproj bundles' do
          group = @project.group_for_path_in_group(@localized_base_foo, @group, false)
          group.real_path.should == config.sandbox.pod_dir('BananaLib') + 'Dir/SubDir'
        end

        it "doesn't duplicate variant groups for interface and strings files with " \
           'same name and directory' do
          Pathname.any_instance.stubs(:exist?).returns(false).then.returns(true)

          group_1 = @project.group_for_path_in_group(@localized_base_foo, @group, false)
          group_2 = @project.group_for_path_in_group(@localized_de_foo, @group, false)

          group_1.uuid.should == group_2.uuid
          @group.children.count.should == 1
        end

        it 'creates own variant groups for localized non-interface files with same name' do
          # An image and a strings file should not be combined.
          group_1 = @project.group_for_path_in_group(@localized_de_foo, @group, false)
          group_2 = @project.group_for_path_in_group(@localized_de_foo_jpg, @group, false)

          group_1.uuid.should != group_2.uuid
          @group.children.count.should == 2
        end

        it 'makes separate variant groups for different names' do
          group_1 = @project.group_for_path_in_group(@localized_base_foo, @group, false)
          group_2 = @project.group_for_path_in_group(@localized_de_bar, @group, false)
          group_1.uuid.should != group_2.uuid
          @group.children.count.should == 2
        end

        it 'makes separate variant groups for different directory levels' do
          group_1 = @project.group_for_path_in_group(@localized_base_foo, @group, false)
          group_2 = @project.group_for_path_in_group(@localized_different_foo, @group, false)
          group_1.uuid.should != group_2.uuid
          @group.children.count.should == 2
        end

        it 'raises if the given path is not absolute' do
          should.raise ArgumentError do
            @project.add_file_reference('relative/path/to/file.m', @group, true)
          end.message.should.match /Paths must be absolute/
          should.raise ArgumentError do
            @project.add_file_reference('relative/path/to/file.m', @group, false)
          end.message.should.match /Paths must be absolute/
        end
      end

      #----------------------------------------#

      describe '#reference_for_path' do
        before do
          @project.add_pod_group('BananaLib', config.sandbox.pod_dir('BananaLib'), false)
          @file = config.sandbox.pod_dir('BananaLib') + 'file.m'
          @group = @project.group_for_spec('BananaLib')
          @file.stubs(:realpath).returns(@file)
          @project.add_file_reference(@file, @group)
        end

        it 'returns the reference for the given path' do
          ref = @project.reference_for_path(@file)
          ref.hierarchy_path.should == '/Pods/BananaLib/file.m'
        end

        it 'returns nil if no reference for the given path is available' do
          another_file = config.sandbox.pod_dir('BananaLib') + 'another_file.m'
          another_file.stubs(:realpath).returns(another_file)
          ref = @project.reference_for_path(another_file)
          ref.should.be.nil
        end

        it 'raises if the given path is not absolute' do
          should.raise ArgumentError do
            @project.reference_for_path('relative/path/to/file.m')
          end.message.should.match /Paths must be absolute/
        end
      end

      #----------------------------------------#

      it 'adds the Podfile configured as a Ruby file' do
        @project.add_podfile(config.sandbox.root + '../Podfile')
        f = @project['Podfile']
        f.source_tree.should == 'SOURCE_ROOT'
        f.xc_language_specification_identifier.should == 'xcode.lang.ruby'
        f.explicit_file_type.should == 'text.script.ruby'
        f.path.should == '../Podfile'
      end

      #----------------------------------------#

      describe '#add_build_configuration' do
        it 'adds a preprocessor definition for build configurations' do
          configuration = @project.add_build_configuration('Release', :release)
          settings = configuration.build_settings
          settings['GCC_PREPROCESSOR_DEFINITIONS'].should == ['POD_CONFIGURATION_RELEASE=1', '$(inherited)']
        end

        it "doesn't create invalid preprocessor definitions for configurations" do
          configuration = @project.add_build_configuration('1 Release-Foo.bar', :release)
          settings = configuration.build_settings
          settings['GCC_PREPROCESSOR_DEFINITIONS'].should.include('POD_CONFIGURATION_1_RELEASE_FOO_BAR=1')
        end

        it "doesn't duplicate values" do
          original = @project.build_configuration_list['Debug']
          original_settings = original.build_settings
          original_settings['GCC_PREPROCESSOR_DEFINITIONS'].should ==
            ['POD_CONFIGURATION_DEBUG=1', 'DEBUG=1', '$(inherited)']

          configuration = @project.add_build_configuration('Debug', :debug)
          settings = configuration.build_settings
          settings['GCC_PREPROCESSOR_DEFINITIONS'].should ==
            ['POD_CONFIGURATION_DEBUG=1', 'DEBUG=1', '$(inherited)']

          configuration = @project.add_build_configuration('Debug-Based', :debug)
          settings = configuration.build_settings
          settings['GCC_PREPROCESSOR_DEFINITIONS'].should ==
            ['POD_CONFIGURATION_DEBUG_BASED=1', 'DEBUG=1', '$(inherited)']
        end

        it 'normalizes the name of the configuration' do
          configuration = @project.add_build_configuration(
            'My Awesome Configuration', :release)
          settings = configuration.build_settings
          settings['GCC_PREPROCESSOR_DEFINITIONS'].should ==
            ['POD_CONFIGURATION_MY_AWESOME_CONFIGURATION=1', '$(inherited)']
        end

        it 'transforms camel-cased configuration names to snake case' do
          configuration = @project.add_build_configuration(
            'MyAwesomeConfiguration', :release)
          settings = configuration.build_settings
          settings['GCC_PREPROCESSOR_DEFINITIONS'].should ==
            ['POD_CONFIGURATION_MY_AWESOME_CONFIGURATION=1', '$(inherited)']
        end

        it 'adds DEBUG for configurations based upon :debug' do
          configuration = @project.add_build_configuration(
            'Config', :debug)
          settings = configuration.build_settings
          settings['GCC_PREPROCESSOR_DEFINITIONS'].should ==
            ['POD_CONFIGURATION_CONFIG=1', 'DEBUG=1', '$(inherited)']
        end
      end
    end

    #-------------------------------------------------------------------------#
  end
end
