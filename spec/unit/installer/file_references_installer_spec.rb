require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::FileReferencesInstaller do
    before do
      @pod_target = fixture_pod_target('banana-lib/BananaLib.podspec')
      @file_accessor = @pod_target.file_accessors.first
      @project = Project.new(config.sandbox.project_path)
      @project.add_pod_group('BananaLib', fixture('banana-lib'))
      @installer = Installer::FileReferencesInstaller.new(config.sandbox, [@pod_target], @project)
    end

    #-------------------------------------------------------------------------#

    describe 'Installation' do
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
        file_ref = @installer.pods_project['Pods/BananaLib/Frameworks/Bananalib.framework']
        file_ref.should.be.not.nil
        file_ref.path.should == 'Bananalib.framework'
      end

      it 'adds the file references of the libraries of the project' do
        @installer.install!
        file_ref = @installer.pods_project['Pods/BananaLib/Frameworks/libBananalib.a']
        file_ref.should.be.not.nil
        file_ref.path.should == 'libBananalib.a'
      end

      it 'adds the files references of the resources the Pods project' do
        @installer.install!
        file_ref = @installer.pods_project['Pods/BananaLib/Resources/logo-sidebar.png']
        file_ref.should.be.not.nil
        file_ref.path.should == 'Resources/logo-sidebar.png'
      end

      it 'links the headers required for building the pod target' do
        @installer.install!
        headers_root = @pod_target.build_headers.root
        public_headers = [headers_root + 'BananaLib/Banana.h', headers_root + 'BananaLib/MoreBanana.h']
        private_header = headers_root + 'BananaLib/BananaPrivate.h'
        framework_header = headers_root + 'BananaLib/Bananalib/Bananalib.h'
        public_headers.each { |public_header| public_header.should.exist }
        private_header.should.exist
        framework_header.should.not.exist
      end

      it 'links the public headers meant for the user' do
        @installer.install!
        headers_root = config.sandbox.public_headers.root
        public_headers = [headers_root + 'BananaLib/Banana.h', headers_root + 'BananaLib/MoreBanana.h']
        private_header = headers_root + 'BananaLib/BananaPrivate.h'
        framework_header = headers_root + 'BananaLib/Bananalib/Bananalib.h'
        framework_subdir_header = headers_root + 'BananaLib/Bananalib/SubDir/SubBananalib.h'
        public_headers.each { |public_header| public_header.should.exist }
        private_header.should.not.exist
        framework_header.should.exist
        framework_subdir_header.should.exist
      end

      it 'links the public headers meant for the user, but only for Pods that are not built' do
        Target.any_instance.stubs(:requires_frameworks?).returns(true)
        pod_target_one = fixture_pod_target('banana-lib/BananaLib.podspec')
        pod_target_two = fixture_pod_target('monkey/monkey.podspec')
        project = Project.new(config.sandbox.project_path)
        project.add_pod_group('BananaLib', fixture('banana-lib'))
        project.add_pod_group('monkey', fixture('monkey'))
        installer = Installer::FileReferencesInstaller.new(config.sandbox, [pod_target_one, pod_target_two], project)
        installer.install!
        headers_root = config.sandbox.public_headers.root
        banana_headers = [headers_root + 'BananaLib/Banana.h', headers_root + 'BananaLib/MoreBanana.h']
        banana_headers.each { |banana_header| banana_header.should.not.exist }
        monkey_header = headers_root + 'monkey/monkey.h'
        monkey_header.should.exist
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Private Helpers' do
      describe '#file_accessors' do
        it 'returns the file accessors' do
          pod_target_1 = PodTarget.new([stub('Spec')], [stub('TargetDefinition')], config.sandbox)
          pod_target_1.file_accessors = [fixture_file_accessor('banana-lib/BananaLib.podspec')]
          pod_target_2 = PodTarget.new([stub('Spec')], [stub('TargetDefinition')], config.sandbox)
          pod_target_2.file_accessors = [fixture_file_accessor('banana-lib/BananaLib.podspec')]
          installer = Installer::FileReferencesInstaller.new(config.sandbox, [pod_target_1, pod_target_2], @project)
          roots = installer.send(:file_accessors).map { |fa| fa.path_list.root }
          roots.should == [fixture('banana-lib'), fixture('banana-lib')]
        end

        it 'handles pods without file accessors' do
          pod_target_1 = PodTarget.new([stub('Spec')], [stub('TargetDefinition')], config.sandbox)
          pod_target_1.file_accessors = []
          installer = Installer::FileReferencesInstaller.new(config.sandbox, [pod_target_1], @project)
          installer.send(:file_accessors).should == []
        end
      end

      describe '#header_mappings' do
        it 'returns the header mappings' do
          headers_sandbox = Pathname.new('BananaLib')
          headers = [Pathname.new('BananaLib/Banana.h')]
          mappings = @installer.send(:header_mappings, headers_sandbox, @file_accessor, headers)
          mappings.should == {
            headers_sandbox => headers,
          }
        end

        it 'takes into account the header dir specified in the spec' do
          headers_sandbox = Pathname.new('BananaLib')
          headers = [Pathname.new('BananaLib/Banana.h')]
          @file_accessor.spec_consumer.stubs(:header_dir).returns('Sub_dir')
          mappings = @installer.send(:header_mappings, headers_sandbox, @file_accessor, headers)
          mappings.should == {
            (headers_sandbox + 'Sub_dir') => headers,
          }
        end

        it 'takes into account the header mappings dir specified in the spec' do
          headers_sandbox = Pathname.new('BananaLib')
          header_1 = @file_accessor.root + 'BananaLib/sub_dir/dir_1/banana_1.h'
          header_2 = @file_accessor.root + 'BananaLib/sub_dir/dir_2/banana_2.h'
          headers = [header_1, header_2]
          @file_accessor.spec_consumer.stubs(:header_mappings_dir).returns('BananaLib/sub_dir')
          mappings = @installer.send(:header_mappings, headers_sandbox, @file_accessor, headers)
          mappings.should == {
            (headers_sandbox + 'dir_1') => [header_1],
            (headers_sandbox + 'dir_2') => [header_2],
          }
        end
      end

      describe '#vendored_frameworks_header_mappings' do
        it 'returns the vendored frameworks header mappings' do
          headers_sandbox = Pathname.new('BananaLib')
          header = @file_accessor.root + 'Bananalib.framework/Versions/A/Headers/Bananalib.h'
          header_subdir = @file_accessor.root + 'Bananalib.framework/Versions/A/Headers/SubDir/SubBananalib.h'
          mappings = @installer.send(:vendored_frameworks_header_mappings, headers_sandbox, @file_accessor)
          mappings.should == {
            (headers_sandbox + 'Bananalib') => [header],
            (headers_sandbox + 'Bananalib/SubDir') => [header_subdir],
          }
        end
      end
    end

    #-------------------------------------------------------------------------#
  end
end
