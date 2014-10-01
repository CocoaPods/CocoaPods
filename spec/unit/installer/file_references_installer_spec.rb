require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::FileReferencesInstaller do

    before do
      @file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
      @pod_target = PodTarget.new([], nil, config.sandbox)
      @pod_target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
      @pod_target.file_accessors = [@file_accessor]
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

      it 'links the build headers' do
        @installer.install!
        headers_root = @pod_target.build_headers.root
        public_header =  headers_root + 'BananaLib/Banana.h'
        private_header = headers_root + 'BananaLib/BananaPrivate.h'
        public_header.should.exist
        private_header.should.exist
      end

      it 'links the public headers' do
        @installer.install!
        headers_root = config.sandbox.public_headers.root
        public_header =  headers_root + 'BananaLib/Banana.h'
        private_header = headers_root + 'BananaLib/BananaPrivate.h'
        public_header.should.exist
        private_header.should.not.exist
      end

    end

    #-------------------------------------------------------------------------#

    describe 'Private Helpers' do

      describe '#file_accessors' do
        it 'returns the file accessors' do
          pod_target_1 = PodTarget.new([], nil, config.sandbox)
          pod_target_1.file_accessors = [fixture_file_accessor('banana-lib/BananaLib.podspec')]
          pod_target_2 = PodTarget.new([], nil, config.sandbox)
          pod_target_2.file_accessors = [fixture_file_accessor('banana-lib/BananaLib.podspec')]
          installer = Installer::FileReferencesInstaller.new(config.sandbox, [pod_target_1, pod_target_2], @project)
          roots = installer.send(:file_accessors).map { |fa| fa.path_list.root }
          roots.should == [fixture('banana-lib'), fixture('banana-lib')]
        end

        it 'handles libraries empty libraries without file accessors' do
          pod_target_1 = PodTarget.new([], nil, config.sandbox)
          pod_target_1.file_accessors = []
          installer = Installer::FileReferencesInstaller.new(config.sandbox, [pod_target_1], @project)
          roots = installer.send(:file_accessors).should == []
        end
      end

      describe '#header_mappings' do
        it 'returns the header mappings' do
          headers_sandbox = Pathname.new('BananaLib')
          headers = [Pathname.new('BananaLib/Banana.h')]
          mappings = @installer.send(:header_mappings, headers_sandbox, @file_accessor, headers)
          mappings.should == {
            headers_sandbox => [Pathname.new('BananaLib/Banana.h')],
          }
        end

        it 'takes into account the header dir specified in the spec' do
          headers_sandbox = Pathname.new('BananaLib')
          headers = [Pathname.new('BananaLib/Banana.h')]
          @file_accessor.spec_consumer.stubs(:header_dir).returns('Sub_dir')
          mappings = @installer.send(:header_mappings, headers_sandbox, @file_accessor, headers)
          mappings.should == {
            (headers_sandbox + 'Sub_dir') => [Pathname.new('BananaLib/Banana.h')],
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

    end

    #-------------------------------------------------------------------------#

  end
end
