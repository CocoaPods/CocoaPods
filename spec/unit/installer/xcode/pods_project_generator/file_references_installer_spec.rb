require File.expand_path('../../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        describe FileReferencesInstaller do
          before do
            @pod_target = fixture_pod_target('banana-lib/BananaLib.podspec')
            @file_accessor = @pod_target.file_accessors.first
            @project = Project.new(config.sandbox.project_path)
            @project.add_pod_group('BananaLib', fixture('banana-lib'))
            @installer = FileReferencesInstaller.new(config.sandbox, [@pod_target], @project)
          end

          #-------------------------------------------------------------------------#

          describe 'Installation With Flat Resources Glob' do
            it 'adds the files references of the source files the Pods project' do
              @file_accessor.path_list.read_file_system
              @file_accessor.path_list.expects(:read_file_system)
              @installer.install!
            end

            it 'adds the files references of the source files the Pods project' do
              @installer.install!
              file_ref = @installer.pods_project['Pods/BananaLib/Banana.m']
              file_ref.should.be.not.nil
              file_ref.path.should == 'Classes/Banana.m'
            end

            it 'adds the file references of the frameworks of the project' do
              @installer.install!
              file_ref = @installer.pods_project['Pods/BananaLib/Frameworks/BananaFramework.framework']
              file_ref.should.be.not.nil
              file_ref.path.should == 'BananaFramework.framework'
            end

            it 'adds the file references of the libraries of the project' do
              @installer.install!
              file_ref = @installer.pods_project['Pods/BananaLib/Frameworks/libBananaStaticLib.a']
              file_ref.should.be.not.nil
              file_ref.path.should == 'libBananaStaticLib.a'
            end

            it 'adds files references for the resources of the Pods project' do
              @installer.install!
              file_ref = @installer.pods_project['Pods/BananaLib/Resources/logo-sidebar.png']
              file_ref.should.be.not.nil
              file_ref.path.should == 'Resources/logo-sidebar.png'
            end

            it "adds file references for localization directories if glob doesn't include contained files" do
              @installer.install!
              file_ref = @installer.pods_project['Pods/BananaLib/Resources/en.lproj']
              file_ref.should.be.not.nil
              file_ref.path.should == 'Resources/en.lproj'
            end

            it 'adds file references for files within CoreData directories' do
              @installer.install!
              model_ref = @installer.pods_project['Pods/BananaLib/Resources/Sample.xcdatamodeld']
              model_ref.should.be.not.nil
              model_ref.path.should == 'Resources/Sample.xcdatamodeld'

              # Files within the .xcdatamodeld directory are added automatically by adding the .xcdatamodeld directory.
              file_ref = @installer.pods_project['Pods/BananaLib/Resources/Sample.xcdatamodeld/Sample.xcdatamodel']
              file_ref.should.be.not.nil
              file_ref.path.should == 'Sample.xcdatamodel'
              file_ref.source_tree.should == '<group>'
            end

            it 'links the headers required for building the pod target' do
              @installer.install!
              headers_root = @pod_target.build_headers.root
              public_headers = [headers_root + 'BananaLib/Banana.h', headers_root + 'BananaLib/MoreBanana.h']
              private_header = headers_root + 'BananaLib/BananaPrivate.h'
              framework_header = headers_root + 'BananaLib/BananaFramework/BananaFramework.h'
              public_headers.each { |public_header| public_header.should.exist }
              private_header.should.exist
              framework_header.should.not.exist
            end

            it 'links the public headers meant for the user' do
              @installer.install!
              headers_root = config.sandbox.public_headers.root
              public_headers = [headers_root + 'BananaLib/Banana.h', headers_root + 'BananaLib/MoreBanana.h']
              private_header = headers_root + 'BananaLib/BananaPrivate.h'
              framework_header = headers_root + 'BananaLib/BananaFramework/BananaFramework.h'
              framework_subdir_header = headers_root + 'BananaLib/BananaFramework/SubDir/SubBananaFramework.h'
              public_headers.each { |public_header| public_header.should.exist }
              private_header.should.not.exist
              framework_header.should.not.exist
              framework_subdir_header.should.not.exist
            end

            it 'links the public headers meant for the user for a vendored framework' do
              pod_target_one = fixture_pod_target('banana-lib/BananaLib.podspec', BuildType.dynamic_framework)
              pod_target_two = fixture_pod_target('monkey/monkey.podspec', BuildType.dynamic_framework)
              project = Project.new(config.sandbox.project_path)
              project.add_pod_group('BananaLib', fixture('banana-lib'))
              project.add_pod_group('monkey', fixture('monkey'))
              installer = FileReferencesInstaller.new(config.sandbox, [pod_target_one, pod_target_two], project)
              installer.install!
              headers_root = config.sandbox.public_headers.root
              banana_headers = [headers_root + 'BananaLib/Banana.h', headers_root + 'BananaLib/MoreBanana.h']
              banana_headers.each { |banana_header| banana_header.should.not.exist }
              monkey_header = headers_root + 'monkey/monkey.h'
              monkey_header.should.exist # since it lives outside of the vendored framework
            end

            it 'does not link public headers from vendored framework, when frameworks required' do
              @pod_target.stubs(:build_type).returns(BuildType.dynamic_framework)
              @installer.install!
              headers_root = config.sandbox.public_headers.root
              framework_header = headers_root + 'BananaLib/BananaFramework/BananaFramework.h'
              framework_header.should.not.exist
            end

            it 'does not symlink headers that belong to test specs' do
              coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
              coconut_test_spec = coconut_spec.test_specs.first
              coconut_pod_target = fixture_pod_target_with_specs([coconut_spec, coconut_test_spec], BuildType.static_library)
              public_headers_root = config.sandbox.public_headers.root
              private_headers_root = coconut_pod_target.build_headers.root
              project = Project.new(config.sandbox.project_path)
              project.add_pod_group('CoconutLib', fixture('coconut-lib'))
              installer = FileReferencesInstaller.new(config.sandbox, [coconut_pod_target], project)
              installer.install!
              (public_headers_root + 'CoconutLib/Coconut.h').should.exist
              (public_headers_root + 'CoconutLib/CoconutTestHeader.h').should.not.exist
              (private_headers_root + 'CoconutLib/Coconut.h').should.exist
              (private_headers_root + 'CoconutLib/CoconutTestHeader.h').should.not.exist
            end
          end

          #-------------------------------------------------------------------------#

          describe 'Installation With Recursive Resources Glob' do
            before do
              spec = fixture_spec('banana-lib/BananaLib.podspec')
              spec.resources = 'Resources/**/*'
              @pod_target = fixture_pod_target(spec)
              @file_accessor = @pod_target.file_accessors.first
              @project = Project.new(config.sandbox.project_path)
              @project.add_pod_group('BananaLib', fixture('banana-lib'))
              @installer = FileReferencesInstaller.new(config.sandbox, [@pod_target], @project)
            end

            it "doesn't add file references for localization directories themselves" \
              'if glob includes contained files' do
              @installer.install!
              file_ref = @installer.pods_project['Pods/BananaLib/Resources/en.lproj']
              file_ref.should.be.nil
            end

            it 'creates file system reference variant groups for nested localized resource directories' do
              @installer.install!
              ref = @installer.pods_project['Pods/BananaLib/Resources/nested']
              ref.should.be.not.nil
              ref.is_a?(Xcodeproj::Project::Object::PBXVariantGroup).should.be.true
            end

            it "doesn't add file references for nested localized resources" do
              @installer.install!
              file_ref = @installer.pods_project['Pods/BananaLib/Resources/en.lproj/nested/logo-nested.png']
              file_ref.should.be.nil
            end

            it "doesn't add file references for files within Asset Catalogs" do
              @installer.install!
              resources_group_ref = @installer.pods_project['Pods/BananaLib/Resources']
              catalog_path = 'Resources/Images.xcassets'

              # The asset catalog should be a "PBXFileReference" and therefore doesn't have children.
              resources_group_ref.files.any? { |ref| ref.path == catalog_path }.should.be.true

              # The asset catalog should not also be a "PBXGroup".
              resources_group_ref.groups.any? { |ref| ref.path == catalog_path }.should.be.false

              # None of the children of the catalog directory should be present directly.
              resources_group_ref.files.any? { |ref| ref.path.start_with?(catalog_path + '/') }.should.be.false
            end

            it "doesn't add file references for files within CoreData migration mappings" do
              @installer.install!
              resources_group_ref = @installer.pods_project['Pods/BananaLib/Resources']
              mapping_path = 'Resources/Migration.xcmappingmodel'

              # The mapping model should be a "PBXFileReference" and therefore doesn't have children.
              resources_group_ref.files.any? { |ref| ref.path == mapping_path }.should.be.true

              # The mapping model should not also be a "PBXGroup".
              resources_group_ref.groups.any? { |ref| ref.path == mapping_path }.should.be.false

              # None of the children of the mapping model directory should be present directly.
              resources_group_ref.files.any? { |ref| ref.path.start_with?(mapping_path + '/') }.should.be.false
            end
          end

          #-------------------------------------------------------------------------#

          describe 'Private Helpers' do
            describe '#file_accessors' do
              it 'returns the file accessors' do
                pod_target_1 = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios,
                                             [stub('Spec', :test_specification? => false, :library_specification? => true, :non_library_specification? => false, :app_specification? => false, :spec_type => :library)],
                                             [fixture_target_definition],
                                             [fixture_file_accessor('banana-lib/BananaLib.podspec')])
                pod_target_2 = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios,
                                             [stub('Spec', :test_specification? => false, :library_specification? => true, :non_library_specification? => false, :app_specification? => false, :spec_type => :library)],
                                             [fixture_target_definition],
                                             [fixture_file_accessor('banana-lib/BananaLib.podspec')])
                installer = FileReferencesInstaller.new(config.sandbox, [pod_target_1, pod_target_2], @project)
                roots = installer.send(:file_accessors).map { |fa| fa.path_list.root }
                roots.should == [fixture('banana-lib'), fixture('banana-lib')]
              end

              it 'handles pods without file accessors' do
                pod_target_1 = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios,
                                             [stub('Spec', :test_specification? => false, :library_specification? => true, :non_library_specification? => false, :app_specification? => false, :spec_type => :library)],
                                             [fixture_target_definition], [])
                installer = FileReferencesInstaller.new(config.sandbox, [pod_target_1], @project)
                installer.send(:file_accessors).should == []
              end
            end

            describe '#common_path' do
              it 'calculates the correct common path' do
                paths = [
                  '/Base/Sub/A/1.txt',
                  '/Base/Sub/A/2.txt',
                  '/Base/Sub/A/B/1.txt',
                  '/Base/Sub/A/B/2.txt',
                  '/Base/Sub/A/D/E/1.txt',
                ].map { |p| Pathname.new(p) }
                result = @installer.send(:common_path, paths)
                result.should == Pathname.new('/Base/Sub/A')
              end

              it 'compares path components instead of string prefixes' do
                paths = [
                  '/Base/Sub/A/1.txt',
                  '/Base/Sub/AA/2.txt',
                  '/Base/Sub/AAA/B/1.txt',
                  '/Base/Sub/AAAA/B/2.txt',
                  '/Base/Sub/AAAAA/D/E/1.txt',
                ].map { |p| Pathname.new(p) }
                result = @installer.send(:common_path, paths)
                result.should == Pathname.new('/Base/Sub')
              end

              it 'should not consider root \'/\' a common path' do
                paths = [
                  '/A/B/C',
                  '/D/E/F',
                  '/G/H/I',
                ].map { |p| Pathname.new(p) }
                result = @installer.send(:common_path, paths)
                result.should.be.nil
              end

              it 'raises when given a relative path' do
                paths = [
                  '/A/B/C',
                  '/D/E/F',
                  'bad/path',
                ].map { |p| Pathname.new(p) }
                should.raise ArgumentError do
                  @installer.send(:common_path, paths)
                end
              end

              it 'returns nil when given an empty path list' do
                paths = []
                result = @installer.send(:common_path, paths)
                result.should.be.nil
              end
            end
          end

          #-------------------------------------------------------------------------#

          describe 'Installation With Development Pods' do
            before do
              @project = Project.new(config.sandbox.project_path)
              @project.add_pod_group('BananaLib', fixture('banana-lib'), true)
            end

            it 'sets the path of the Pod group to the installation root' do
              @installer.install!
              group = @project.group_for_spec('BananaLib')
              group.path.should == '../../spec/fixtures/banana-lib'
            end
          end

          #-------------------------------------------------------------------------#

          it 'preserves all the paths of the Pod' do
            @installer = FileReferencesInstaller.new(config.sandbox, [@pod_target], @project, true)
            @installer.install!
            @project.group_for_spec('BananaLib').recursive_children.map(&:name).compact.should.not.include? 'Resources'
          end
        end
      end
    end
  end
end
